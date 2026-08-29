# ComfyUI on this machine — working notes

Hard-won facts from getting MiniMax H3 running locally. Update this file whenever
something new and non-obvious is discovered — wrong assumption, new bottleneck,
a fix that worked, a model/workflow worth keeping. Keep entries short and dated.

## Read this first: Wan 2.2 TI2V-5B >> MiniMax H3 for speed on this hardware

If audio isn't required, **use Wan 2.2 TI2V-5B instead of MiniMax H3.**
2026-08-29 test: 10m03s total (512x512, 1s, 20 steps, standard CFG) vs MiniMax
H3 Turbo's 21m33s for *sampling alone*. ~6.5x faster per step (24.6s vs
161s). Why: the whole 5B-param diffusion model fits in VRAM with **zero
offloading** (`loaded completely ... full load: True`) — no GPU↔RAM weight
shuffling per step, which is what actually made MiniMax H3 slow (see
"RAM is the actual ceiling" below — same root cause, opposite fix: instead of
tolerating the offload, use a model small enough to avoid it entirely).

Trade-off: Wan 2.2 TI2V-5B is video-only, no native audio (unlike MiniMax
H3's joint audio+video). Pick MiniMax H3 only when audio actually matters.

See "Wan 2.2 TI2V-5B setup" section below for exact files/workflow.

## Standard test input (use for every test from here on, per user 2026-08-29)

All three workflows are pre-loaded with this as their default input — don't
revert to `example.png`/placeholder prompts when testing changes:

- **Image:** `test_reference_room.png` (in `ComfyUI/input/` and this repo's
  `test_assets/`) — a cozy loft office: floor-to-ceiling windows onto a foggy
  forest, triple-monitor desk setup, a fire feature bottom-right, polished
  dark wood floor. Copied from
  `~/Pictures/Screenshots/Screenshot_20260823_131242.png`.
- **Prompt:** *"Animate this image into a seamless 3-second loop with a
  completely static camera angle (do not pan or zoom). Outside the large
  windows, the fog should drift slowly and naturally through the forest, and
  the evergreen trees should sway gently in a light breeze. Inside the room,
  the flames in the fire feature on the bottom right should flicker and move
  realistically. The computer monitors on the desk should show active,
  continuous work animations like scrolling text or data. Enhance the
  lighting and animate the reflections on the polished floor so they react
  dynamically and naturally to the flickering fire and screen light."*
- **Duration:** 3 seconds (73 frames @ 24fps). **Aspect:** 16:9 (matches the
  source image, ~1.78:1) instead of the earlier default square crop.

Set via `mcp__comfy-mcp__set_workflow_slot` (not hand-edited JSON) — use
`list_workflow_slots` first to get exact addresses if the workflows change
structure later; `133.prompt`/`149.image`/`150.image`/`135.value` for the
Turbo workflow, `105/104.prompt`/`121.image`/`125.image`/`105/111.value` for
the baseline (subgraph-interior addresses), `6.text`/`56.image`/`55.length`
for Wan 2.2 (flat, no subgraph).

**2026-08-29 result (Wan 2.2 TI2V-5B Turbo, see section below):** 8m41.8s
total for the full 3s/832x480 clip with this real prompt+image — first
result using actual content rather than a mismatched speed-test placeholder.
One VRAM warning during VAE decode at this resolution (`Ran out of memory
when regular VAE decoding, retrying with tiled VAE decoding`) — ComfyUI's
automatic fallback handled it, not a crash, but worth knowing this
resolution is near the VAE decode ceiling. Base (non-turbo) Wan 2.2 and both
MiniMax H3 variants not yet run with this exact input — only the Turbo GGUF
variant has a real-content result so far.

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

## xformers — installed, works, but measured: no speedup on this workload

`pip install xformers` (in `~/ComfyUI/venv`) installed cleanly against
`torch==2.13.0+cu126` — despite the PyPI wheel being tagged `py39-none`, it
works fine on this Python 3.14 venv (2026-08-28: `xformers==0.0.35`).
`xformers.ops.memory_efficient_attention` runs correctly on the GTX 1080
(Pascal officially supported down to sm60), and ComfyUI auto-detects it on
launch with no flag needed (log: `Using xformers attention`).

**A/B tested 2026-08-28, same Turbo LoRA workflow/settings (8 steps, 2s clip)
both times: no meaningful difference.**

| | No xformers | With xformers |
|---|---|---|
| Per-step | 157-163s | 161-166s |
| Sampling total | 21m27s | 21m33s |
| End-to-end total | 28m36s | 27m41s |

Difference is within run-to-run noise (~1-3%). Every step logs `loaded
partially; ~3.8GB usable, ~3.1GB loaded, ~5.6GB offloaded` — the per-step
cost here is dominated by shuffling offloaded weights between VRAM and RAM
each step, not attention compute. xformers optimizes attention; it doesn't
touch that offload/swap path, so it can't help on this workload. Conclusion:
harmless to leave installed, but **don't expect it to fix speed** — the
actual lever that worked is the Turbo LoRA (above), and any future win has to
attack the VRAM↔RAM offload cost, not compute.

## Wan 2.2 TI2V-5B setup — the fast option (no audio)

Official ComfyUI template `video_wan2_2_5B_ti2v` (fetch via
`mcp__comfy-mcp__fetch_template`) uses standard safetensors loaders that
don't fit our VRAM/RAM as cleanly as GGUF — converted it the same way as
MiniMax H3: swap `UNETLoader`→`UnetLoaderGGUF` and `CLIPLoader`→
`CLIPLoaderGGUF`, keep `VAELoader` as-is (VAE isn't the bottleneck, plain
safetensors is fine).

- Diffusion model: `QuantStack/Wan2.2-TI2V-5B-GGUF` on HuggingFace,
  `Wan2.2-TI2V-5B-Q5_K_M.gguf` (~3.81GB) → `models/unet/`.
- Text encoder: `city96/umt5-xxl-encoder-gguf` (same author as ComfyUI-GGUF),
  `umt5-xxl-encoder-Q4_K_M.gguf` (~3.66GB) → `models/text_encoders/`, load
  via `CLIPLoaderGGUF` with `type: "wan"`.
- VAE: `Comfy-Org/Wan_2.2_ComfyUI_Repackaged`,
  `split_files/vae/wan2.2_vae.safetensors` (~1.41GB) → `models/vae/`,
  standard `VAELoader` (not GGUF).
- No extra custom nodes needed beyond what MiniMax H3 already required
  (ComfyUI-GGUF covers both).
- Workflow: `wan22_ti2v_5b_gguf.json` (in `user/default/workflows/` and this
  repo's `workflows/`). `Wan22ImageToVideoLatent` node controls
  width/height/length(frames)/batch — now set to the standard test input
  (832x480, 73 frames = 3s). `KSampler` uses standard CFG=5 (2x forward
  pass/step).

### Turbo variant — tested, works, use this by default

`hum-ma/Wan2.2-TI2V-5B-Turbo-GGUF` on HuggingFace ships a **pre-merged**
Turbo checkpoint (not a separate LoRA to juggle) — just swap `unet_name`.
Used `Wan2_2-TI2V-5B-Turbo-Q5_K_M.gguf` (~3.6GB) → `models/unet/`. Recommended
settings from the repo's README: **4 steps, CFG=1**, sampler
euler/sa_solver/uni_pc, scheduler simple/normal/beta — kept `uni_pc`/`simple`
(already matched). Text encoder and VAE are shared with the base model, no
separate download.

Workflow: `wan22_ti2v_5b_turbo_gguf.json` — copy of the base Wan 2.2 workflow
with `unet_name`, `steps=4`, `cfg=1` changed via `set_workflow_slot`.

**2026-08-29 result, real content (standard test input, 3s/832x480):
8m41.8s total.** One automatic VAE-decode-to-tiled fallback triggered at this
resolution (see "Standard test input" above) — worth watching, not yet
compared against the base (non-turbo) model at these same settings to know
how much the Turbo checkpoint itself saves here (only compared apples-to-oranges
against the base model's earlier smaller/mismatched-content test).

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

- `wan22_ti2v_5b_turbo_gguf.json` — **fastest, use by default, no audio.**
  Wan 2.2 TI2V-5B Turbo checkpoint, 4 steps/CFG=1. 8m42s for a real 3s/832x480
  clip. See "Wan 2.2 TI2V-5B setup" → "Turbo variant" above.
- `wan22_ti2v_5b_gguf.json` — same model, base (non-turbo) checkpoint, 20
  steps/CFG=5. Slower, only useful as a quality comparison baseline against
  the Turbo variant. See "Wan 2.2 TI2V-5B setup" above.
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
