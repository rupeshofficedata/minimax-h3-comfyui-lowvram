# ComfyUI on this machine — working notes

Hard-won facts from getting MiniMax H3 running locally. Update this file whenever
something new and non-obvious is discovered — wrong assumption, new bottleneck,
a fix that worked, a model/workflow worth keeping. Keep entries short and dated.

## Hardware (fixed constraints, not going away)

- GPU: NVIDIA GTX 1080, 8GB VRAM, **Pascal** (compute capability 6.1) — no tensor
  cores, no fp8/nvfp4/int8_convrot hardware support. This GPU also drives the
  live desktop session (kwin/Wayland) — heavy VRAM/compute use can make the
  desktop sluggish.
- RAM: 15.6GB total. This is the *real* bottleneck, more than VRAM — see below.
- Disk: plenty free (400GB+), never been the constraint.

## The cu130 vs cu126 trap (critical, will silently break things)

PyTorch's default/latest CUDA build (`cu130`) **dropped kernel support for
Pascal entirely**. Symptom: `torch.cuda.is_available()` returns `True`, GPU
name detects fine, but any real op throws
`CUDA error: no kernel image is available for execution on the device`.

Fix: install torch explicitly from the cu126 index:
```
pip install torch==<version> torchvision torchaudio --index-url https://download.pytorch.org/whl/cu126
```
Confirmed working: `torch==2.13.0+cu126`. Verify with a real op, not just
`is_available()`:
```python
import torch; x = torch.randn(10,10,device='cuda'); (x@x).sum().item()
```
This also means ComfyUI's `comfy_kitchen` "cuda" backend (the fast
`int8_convrot`/nvfp4 path) reports `disabled: True` on this box — it requires
cu130. Not fixable here; the GGUF path below is the workaround.

## RAM is the actual ceiling, not VRAM

During a real MiniMax H3 run, available RAM dropped to **830MB** at the
tightest point (VAE/audio decode, right after sampling finishes) — that's the
real headroom, not the ~7-8GB free before a run starts. Implications:
- Don't bump resolution or duration casually — this is the wall that gets hit,
  not VRAM (VRAM stayed at a stable ~7GB/8GB throughout, never the failure
  point).
- Before a run: `mcp__comfy-mcp__system_stats` (or `curl -X POST
  http://127.0.0.1:8188/free -d '{"unload_models":true,"free_memory":true}'`)
  to free lingering VRAM/RAM from a previous run — ComfyUI doesn't always
  release it automatically once idle.
- A 32GB RAM upgrade would fix reliability (no more near-OOM during decode)
  and allow trying higher resolution/duration, but would **not** speed up
  sampling itself — that's GPU-compute-bound (confirmed: GPU sits at 100%
  utilization for the full sampling duration).

## MiniMax H3 setup that works on this hardware

Native/non-GGUF loaders need `int8_convrot`/nvfp4 — unusable here (see cu130
trap above). Use the **GGUF quantized path** instead:

- Diffusion model: `Abiray/MiniMax-H3-Pruned-GGUF` on HuggingFace — use the
  pruned variant (`MiniMax-H3-FL2VA-Pruned-Q3_K_M.gguf`, ~8.9GB), not the
  unpruned repo (`Abiray/MiniMax-H3-GGUF`, smallest quant there is 15.6GB).
  Loaded via `UnetLoaderGGUF` → `models/unet/` (or wherever the GGUF node
  registers, not the standard `diffusion_models` folder).
- Text encoder: `qwen3vl_32b_minimax_h3-Q4_K_M.gguf` from
  `Abiray/MiniMax-H3-GGUF` (~14.6GB), via `CLIPLoaderGGUF` →
  `models/text_encoders/`. Runs on CPU (too big for 8GB VRAM) — this is why
  there's a multi-minute CPU-bound phase at the start of every run before the
  GPU sampling phase begins (normal, not stuck).
- VAEs: `minimax_h3_video_vae_fp16.safetensors` (~5.2GB) +
  `minimax_h3_audio_vae_fp32.safetensors` (~0.6GB), same repo, → `models/vae/`.
- Custom node required: `city96/ComfyUI-GGUF` (has no LoRA loader of its own —
  use core ComfyUI's standard `LoraLoaderModelOnly` node on the GGUF-loaded
  MODEL, it works fine via ComfyUI-GGUF's patch-aware ops).

## Turbo LoRA — biggest speedup found, use by default

`Abiray/MiniMax-H3-Turbo-Lora-Pruned-ComfyUI` on HuggingFace
(`minimax_h3_turbo_4step_ckpt600_ema_V4.safetensors`, ~592MB, → `models/loras/`).
Cuts required sampling steps from 25 → 8 with `res_multistep` /
`simple` scheduler. **Measured on this hardware: 65m32s → 21m27s sampling,
72min → 28m36s total, for a 2s clip.** Settings that worked: LoRA strength
1.0, `MiniMaxH3SigmaShift` video=12/audio=6, steps=8, denoise=1.0.
Always try this LoRA before running the non-turbo path.

## xformers — installed, confirmed working, not yet speed-measured

`pip install xformers` (in `~/ComfyUI/venv`) installed cleanly against
`torch==2.13.0+cu126` — despite the PyPI wheel being tagged `py39-none`, it
works fine on this Python 3.14 venv (2026-08-28: `xformers==0.0.35`).
Verified `xformers.ops.memory_efficient_attention` runs correctly on the GTX
1080 (Pascal officially supported down to sm60). ComfyUI auto-detects it on
launch with no flag needed — log line changes from `Using pytorch attention`
to `Using xformers attention`. `--disable-xformers` would turn it back off if
it ever causes trouble.

**Not yet A/B tested for actual speed/VRAM impact on a real MiniMax H3 run**
— do that before assuming it helps in practice; update this section with
before/after numbers once measured (compare against the Turbo LoRA's 21m27s
sampling baseline, same 8-step/2s-clip settings, everything else equal).

## Known-bad node settings on this GPU

- `upscale_method: nvidia_rtx_vsr` (in `ImageResizeKJv2`/similar resize nodes)
  — needs actual RTX tensor cores, throws `ImportError: NVIDIA RTX Video
  Super Resolution is not available`. Use `lanczos` instead.
- Sage Attention / Sol-Attn nodes (`MiniMaxH3MemoryEfficientSageAttentionPatch`,
  `SolAttnPatch`, `PatchSageAttentionKJ`, `SpectrumApplyMiniMaxH3`) — Ampere+
  only. The official templates ship these muted (`mode: 4`) by default; leave
  them muted here.

## Server / access

- Launch: `cd ~/ComfyUI && venv/bin/python main.py --enable-manager`, listens
  on `127.0.0.1:8188` (IPv4 only — **`localhost` fails** on this machine
  because it resolves to `::1` first and nothing listens there; always use
  `127.0.0.1` explicitly, in the browser and in scripts).
- venv is at `~/ComfyUI/venv` (Python 3.14.7 — very new, watch for package
  compat issues; pip resolution against PyPI is fine, `torch` needs the cu126
  index override above).

## comfy-mcp (preferred over browser automation)

Installed at `~/.local/share/comfy-mcp-venv` (`pip install comfy-mcp
"comfy-cli>=1.14.0"`), registered with **`-s user` scope** — must be user-scoped,
not local/project-scoped, or it silently fails to load in sessions whose cwd
isn't the exact directory it was registered from (bit us once: registered from
`~/ComfyUI`, session running from `/`, tools never appeared despite `claude mcp
list` showing it connected).

Usage pattern for a real run:
1. `server_info` first, always.
2. `validate_workflow(path)` before running — catches bad model refs/node
   settings that would otherwise only surface as a failed run partway through.
3. `run_workflow(wait=False)` → poll `job(action="wait", timeout_seconds=590)`
   repeatedly (each call runs ~120s client-side then backgrounds itself — this
   is normal, not a hang; re-issue `wait` again after each backgrounding, or
   just `job(action="status")` to spot-check).
4. `fetch_outputs` once `job` status is `completed`.

`workspace.path` reported by `server_info` may not match the actual ComfyUI
install path (comfy-cli has its own notion of "workspace") — doesn't matter
for `validate_workflow`/`run_workflow`/`system_stats`/`job`, they talk to the
live server's HTTP API directly regardless.

## Workflow files (in `user/default/workflows/`)

- `minimax_h3_fl2v_gguf.json` — baseline, 25 steps, no LoRA, proven working
  end-to-end. Image-to-video (needs `first_frame`/`last_frame`; use
  `example.png` — already in `input/` — for both if you don't have real
  images).
- `minimax_h3_fl2v_gguf_turbo.json` — same but with the Turbo LoRA + 8 steps.
  **Prefer this one.** Built from ComfyOrg's official turbo template
  (`Abiray/MiniMax-H3-Turbo-Lora-Pruned-ComfyUI`), swapping its
  `VHS_VideoCombine` output (extra dependency, untested here) for the plain
  `CreateVideo`→`SaveVideo` pair the baseline workflow already used.

## Cleanup

`~/comfyui-h3-cleanup.sh` — dry-run by default, `--force` to actually delete,
`--keep-outputs` to rescue generated videos first. See the script's own
`--help`.
