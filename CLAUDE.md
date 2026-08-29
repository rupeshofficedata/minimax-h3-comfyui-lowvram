# ComfyUI on this machine — working notes

Hard-won facts from getting MiniMax H3 running locally. Update this file whenever
something new and non-obvious is discovered — wrong assumption, new bottleneck,
a fix that worked, a model/workflow worth keeping. Keep entries short and dated.

## Read this first: model comparison verdict (2026-08-29, real-content tests)

Three model families tested on this hardware with the same real image+prompt
(see "Standard test input" below). **Speed and prompt-following/quality
fidelity are in tension** — pick based on what the task actually needs:

| Model | Total time | Image fidelity | Prompt-following | Audio |
|---|---|---|---|---|
| Wan 2.2 TI2V-5B **Turbo** | ~8-9 min | **Fails** — ignores the input image, generates unrelated content, even after matching the author's own `shift`/sampler config | N/A (image ignored) | No |
| LTX-Video 2B distilled | ~2 min | Good (once aspect ratio fixed) | ~30% — a 2B model can't hold this many compound instructions (5 animated elements + camera lock + loop). Wrong monitor content, no fire↔reflection reactivity, no real loop | No |
| MiniMax H3 Turbo | ~40 min | Good | **~80%** — user's own assessment, best so far. Structural first+last-frame conditioning made the loop far more plausible (though still not perfect) | **Yes**, native joint |
| Wan 2.2 TI2V-5B (base, non-turbo) | not yet real-content tested | — | — | No |

**Takeaway:** small/turbo models (Wan Turbo, LTX 2B) are dramatically faster
but the actual language/scene-understanding capacity isn't there for a
compound multi-instruction prompt like this one — that's a capacity
limitation, not a config bug (confirmed via targeted fixes: shift value,
sampler, aspect ratio, negative-prompt engineering all tried on the small
models with only partial improvement). **MiniMax H3 Turbo is the current
best choice when the prompt has this much compound detail.** Use a small
model instead only for simple single-instruction prompts, or when speed
matters more than fidelity.

Also structurally relevant: a real "seamless loop" isn't just a prompt-following
ask — it needs a model whose *architecture* takes both a first AND last frame
(MiniMax H3's `MiniMaxH3ImageToVideo` does; Wan's `Wan22ImageToVideoLatent`
and LTX's `LTXVImgToVideo` only take one starting image). Set both
`first_frame`/`last_frame` to the same image on MiniMax H3 for loop attempts.

## Standard test input (use for every test from here on, per user 2026-08-29)

All workflows are pre-loaded with this as their default input — don't revert
to `example.png`/placeholder prompts when testing changes.

- **Image:** `test_reference_room.png` (in `ComfyUI/input/` and this repo's
  `test_assets/`) — a cozy loft office: floor-to-ceiling windows onto a foggy
  forest, triple-monitor desk setup, a fire feature bottom-right, polished
  dark wood floor, with a white audio-waveform visualizer bar burned into the
  bottom edge (source screenshot artifact — the prompt must explicitly ask
  for its removal). Copied from
  `~/Pictures/Screenshots/Screenshot_20260823_131242.png`.
- **Duration:** 3 seconds (73 frames @ 24fps). **Aspect:** 16:9 (matches the
  source image, ~1.78:1).
- **Prompt (v3, current, refined 2026-08-29 after two rounds of user feedback
  on v1/v2 outputs):**
  > Animate this image into a perfectly seamless 3-second loop: the very last
  > frame must match the very first frame exactly in every detail — fire
  > state, fog position, monitor content, and lighting — so the loop is
  > imperceptible when played back-to-back. Use a completely static camera
  > angle throughout (no pan, no zoom, no dolly, no tracking movement). All
  > motion should flow at a smooth, natural, real-time pace with no speed
  > ramping, stutter, or jerky cuts.
  >
  > Outside the large windows, fog drifts slowly and naturally through the
  > forest, and the evergreen trees sway gently in a light breeze. Inside the
  > room, the flames in the fire feature on the bottom right flicker and move
  > realistically and continuously. On the desk, the computer monitors show
  > an active, continuously changing screensaver-style animation — flowing
  > code, shifting light patterns, or particle motion — not a static frozen
  > screen. The reflections on the polished floor dynamically and naturally
  > react in real time to the flickering fire and the shifting monitor light.
  >
  > Apply a single, consistent enhanced lighting and color grade (LUT)
  > uniformly across the entire video, present and unchanged from the very
  > first frame through the very last — no gradual shift, fade-in, or drift
  > in color treatment over time.
  >
  > The white audio waveform / sound-visualization bar overlay at the bottom
  > edge of the source image must be completely absent from every frame,
  > including the very first frame — it must never appear anywhere in the
  > output video.
  >
  > **v3 not yet tested against any model — apply and re-test before trusting
  > it fixes the v2 issues (loop still imperfect, waveform bar present at
  > start, monitors static/wrong content, no LUT consistency mentioned in
  > v2).**

Set via `mcp__comfy-mcp__set_workflow_slot` (not hand-edited JSON) — use
`list_workflow_slots` first to get exact addresses if the workflows change
structure later. Current addresses: `133.prompt`/`149.image`/`150.image`/
`135.value` (MiniMax Turbo, subgraph), `105/104.prompt`/`121.image`/
`125.image`/`105/111.value` (MiniMax baseline, subgraph), `6.text`/
`56.image`/`55.length` (Wan 2.2, flat), `6.text`/`89.image`/`90.length` (LTX,
flat).

### Result log (chronological, real-content tests only)

- **Wan 2.2 Turbo, v1 prompt, shift=8/uni_pc:** 8m41.8s. Image ignored
  entirely — see "Wan 2.2 Turbo doesn't follow images" below.
- **Wan 2.2 Turbo, v1 prompt, shift=5/euler** (matching author's own config):
  8m34.9s. Still ignored the image. Confirms this isn't a shift/sampler
  config issue — moved on to other models per user direction.
- **LTX-Video 2B distilled, v1 prompt, 768x512 (wrong aspect):** 1m51.7s.
  Followed the image but visibly squeezed/stretched (aspect mismatch).
- **LTX-Video 2B distilled, v1 prompt, 832x480 (fixed aspect), strength=0.9:**
  2m09.9s. Correct aspect, ~30% prompt adherence, static-camera instruction
  violated (dolly motion appeared), monitor showed flame instead of
  text/data, floor reflections not reactive, no loop structure.
- **LTX-Video 2B distilled, v1 prompt + camera-motion terms in negative
  prompt, same settings:** 2m11s. Camera fix alone insufficient — same
  remaining issues. Concluded this is a 2B-model capacity limit, not
  further fixable by prompt tuning alone.
- **MiniMax H3 Turbo, v2 prompt (v1 + waveform-removal line), first=last=image,
  3s/16:9:** 40m44s (31m37s sampling — much slower here: 240s/step vs 161s/step
  at the earlier 2s/square test, because 3s/16:9 means more offloaded data per
  step, ~6.6GB vs ~5.8GB). **User verdict: "80% perfect."** Remaining issues:
  loop not fully seamless, motion pacing not fully natural/real-time, waveform
  bar still visible at the very start of the video (not just "somewhere"),
  monitors show static code/screensaver rather than continuous animation, no
  mention of color-grade consistency (LUT drift). → drove the v3 prompt above.

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

### Turbo variant — fast, but doesn't reliably follow the input image (2026-08-29)

`hum-ma/Wan2.2-TI2V-5B-Turbo-GGUF` on HuggingFace ships a **pre-merged**
Turbo checkpoint (not a separate LoRA to juggle) — just swap `unet_name`.
Used `Wan2_2-TI2V-5B-Turbo-Q5_K_M.gguf` (~3.6GB) → `models/unet/`. Recommended
settings from the repo's README: **4 steps, CFG=1**, sampler
euler/sa_solver/uni_pc, scheduler simple/normal/beta. Text encoder and VAE
are shared with the base model, no separate download.

Workflow: `wan22_ti2v_5b_turbo_gguf.json` — copy of the base Wan 2.2 workflow
with `unet_name`, `steps=4`, `cfg=1` changed via `set_workflow_slot`.

**Speed is excellent (8m41.8s for a real 3s/832x480 clip) but user confirmed
the output ignores the input image entirely** and generates unrelated
content. Root-caused to the wrong noise-schedule `shift` value (template
default 8 vs the checkpoint author's own demonstrated config of 5, plus
`euler` instead of `uni_pc`) — **tried the fix, re-tested, still ignored the
image** (8m34.9s). So this isn't a config bug on our end; treat this specific
Turbo checkpoint as unreliable for I2V on this pipeline until/unless a real
root cause is found. Base (non-turbo) Wan 2.2 hasn't been re-tested with the
current real content to know if the base checkpoint has the same problem or
if it's Turbo-specific.

One automatic VAE-decode-to-tiled fallback triggered at 832x480 resolution
(`Ran out of memory when regular VAE decoding, retrying with tiled VAE
decoding`) on both Wan Turbo runs — not a crash, but confirms this resolution
is near the VAE decode ceiling for this model on this hardware.

## LTX-Video 2B distilled setup — fastest option, weak on compound prompts

Even smaller than Wan: **2B params**, ~6.9GB total model footprint. Genuinely
fast (~2 min for a 3s/832x480 clip) but real-content testing (2026-08-29)
showed it can only handle ~30% of a compound multi-instruction prompt — see
"Read this first" comparison table above. Worth using for simple
single-instruction prompts where speed matters most; not for anything this
detailed.

- Diffusion model: `city96/LTX-Video-0.9.6-distilled-gguf` on HuggingFace,
  `ltxv-2b-0.9.6-distilled-04-25-Q5_K_M.gguf` (~1.48GB) → `models/unet/`.
- Text encoder: `city96/t5-v1_1-xxl-encoder-gguf`,
  `t5-v1_1-xxl-encoder-Q4_K_M.gguf` (~2.90GB) → `models/text_encoders/`, via
  `CLIPLoaderGGUF` with `type: "ltxv"`.
- VAE: same repo as the diffusion model,
  `LTX-Video-0.9.6-VAE-BF16.safetensors` (~2.49GB) → `models/vae/`, standard
  `VAELoader` (not GGUF).
- No extra custom nodes — `LTXVImgToVideo` is core ComfyUI (not the risky
  `LTXVImgToVideoInplaceKJ` DynamicCombo node from KJNodes, which needs
  correctly-wired dynamic per-image sockets and has no confirmed working
  example anywhere online — avoided it entirely).

### Building the I2V workflow — a wiring gotcha worth knowing

The model repo ships a reference **T2V** workflow
(`media/ltx-video-2b-v0.9.6-distilled_workflow.json` in the HF repo) built
around `EmptyLTXVLatentVideo` (no image input at all). Converting to I2V
means replacing that node with `LoadImage` → `LTXVImgToVideo` (takes
positive/negative conditioning + vae + image + width/height/length/
batch_size + `strength`, outputs new positive/negative/latent) — **and then
rewiring every downstream node that referenced the old node's output link,
not just adding the new links**. First attempt only updated the `links`
array and missed that `SamplerCustom`'s and `LTXVScheduler`'s own `inputs`
arrays still pointed at the old (now-deleted) link IDs —
`mcp__comfy-mcp__validate_workflow` caught it immediately
(`required_input_missing` on `SamplerCustom.latent_image`, plus
`node_not_reachable_from_output` warnings on the new nodes) before any GPU
time was wasted. Lesson: when splicing a node into an existing chain by
hand, always update both the `links` array **and** the receiving nodes'
`inputs[].link` fields, then validate before running.

Workflow: `ltxv_distilled_gguf_i2v.json`. Sampling/schedule settings kept
verbatim from the model author's own T2V reference workflow (`steps=8`,
`max_shift=2.05`, `base_shift=0.95`, `stretch=True`, `terminal=0.1`,
`KSamplerSelect: lcm`, `SamplerCustom cfg=1`) since those are LTX-specific
tuned values, not the `ModelSamplingSD3` shift used by Wan — different
model, different scheduler node (`LTXVScheduler`).

**Known issues found in testing (2026-08-29), unresolved:**
- Default `width`/`height` (768x512) didn't match the source image's aspect
  ratio (1823x1024, ~1.78:1) — `LTXVImgToVideo` stretches to fit exactly,
  doesn't crop, so mismatched aspect visibly squeezes/distorts the image.
  Fixed by setting `90.width=832`/`90.height=480` (~1.73:1, much closer).
- `90.strength` (image-conditioning strength) lowered from default 1.0 to
  0.9 to give the prompt more room to drive motion — modest effect, prompt
  adherence still weak overall; likely a model-capacity ceiling rather than
  something strength tuning alone fixes.
- Adding camera-motion terms to the negative prompt did not stop unwanted
  dolly/pan motion.

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

- `minimax_h3_fl2v_gguf_turbo.json` — **best quality/prompt-following so
  far, use for anything with compound/detailed prompts.** MiniMax H3 + Turbo
  LoRA, 8 steps. ~40min for a real 3s/16:9 clip with audio. Native
  first+last-frame conditioning — the only workflow here structurally suited
  to a real seamless loop. Built from ComfyOrg's official turbo template
  (`Abiray/MiniMax-H3-Turbo-Lora-Pruned-ComfyUI`), swapping its
  `VHS_VideoCombine` output (extra dependency, untested here) for the plain
  `CreateVideo`→`SaveVideo` pair the baseline workflow already used.
- `minimax_h3_fl2v_gguf.json` — same model, baseline 25 steps, no LoRA.
  Much slower (~72min for 2s), only useful as a quality reference against
  the Turbo variant.
- `wan22_ti2v_5b_turbo_gguf.json` — fast (~9min for 3s/16:9) but **confirmed
  unreliable for I2V** — ignores the input image entirely, even after fixing
  the noise-schedule shift value to match the checkpoint author's own config.
  See "Wan 2.2 TI2V-5B setup" → "Turbo variant" above before trusting this one.
- `wan22_ti2v_5b_gguf.json` — same model, base (non-turbo) checkpoint, 20
  steps/CFG=5. Not yet re-tested with real content to know if it has the same
  image-following problem as the Turbo variant.
- `ltxv_distilled_gguf_i2v.json` — fastest (~2min for 3s/16:9) but only
  ~30% prompt adherence on a compound prompt in testing — a 2B model's
  capacity ceiling, not a config issue. See "LTX-Video 2B distilled setup"
  above. Good for simple single-instruction prompts, not detailed ones.

## Cleanup

`~/comfyui-h3-cleanup.sh` — dry-run by default, `--force` to actually delete,
`--keep-outputs` to rescue generated videos first. See the script's own
`--help`.
