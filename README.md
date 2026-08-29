# minimax-h3-comfyui-lowvram

Reproducible setup for running local text/image-to-video generation in
ComfyUI on a GPU that officially has no business running any of this: a
GTX 1080 (Pascal, 8GB VRAM, no tensor cores), 15.6GB system RAM. Covers three
model families, real-content tested against each other:

- **[MiniMax H3](https://www.minimax.io/blog/minimax-h3) (Turbo LoRA) — recommended default.** Video **with native joint audio**, native first+last-frame conditioning (genuinely loop-capable), by far the best prompt-following of the three in testing (user's own verdict: "80% perfect" on a detailed compound prompt). Slow: ~40 min for a real 3s/16:9 clip.
- **[Wan 2.2 TI2V-5B](https://huggingface.co/QuantStack/Wan2.2-TI2V-5B-GGUF) (Turbo checkpoint)** — much faster (~9 min) but **confirmed unreliable**: ignores the input image entirely in image-to-video testing, even after matching the checkpoint author's own recommended settings. Video only, no audio.
- **[LTX-Video 2B distilled](https://huggingface.co/city96/LTX-Video-0.9.6-distilled-gguf)** — fastest by far (~2 min) and does follow the input image, but only managed ~30% adherence to a detailed multi-instruction prompt — a 2B model's capacity ceiling, not a config bug. Good for simple prompts only. Video only, no audio.

This repo is **not** a ComfyUI install — it's the notes, scripts, and
workflow files needed to rebuild one from scratch after a format/reinstall.
Models are downloaded separately, not stored here (~52GB for all three
model families).

## Quick start (fresh machine)

```bash
git clone <this-repo-url>
cd minimax-h3-comfyui-lowvram
./setup.sh                 # clones ComfyUI, builds the venv, installs everything
./download_models.sh       # ~52GB for all three model families
cd ~/ComfyUI && venv/bin/python main.py --enable-manager
# open http://127.0.0.1:8188 (not "localhost" — see CLAUDE.md)
```

Then in ComfyUI, open the `minimax_h3_fl2v_gguf_turbo` workflow (Workflows
sidebar — best quality, has audio) and hit Run. All workflows come
pre-loaded with a standard test image+prompt
(`test_assets/test_reference_room.png`) — swap the `LoadImage` node and
prompt text for your own content. See CLAUDE.md's "Standard test input"
section for the current best-known prompt wording and its revision history.

## What's in here

| File | What |
|---|---|
| `CLAUDE.md` | Everything non-obvious learned getting this working — read this first if something breaks. Auto-loaded by Claude Code when working in this repo or the ComfyUI directory. |
| `setup.sh` | Clones ComfyUI, creates the venv, installs the *correct* torch build, custom nodes, and xformers |
| `download_models.sh` | Downloads all GGUF model files for MiniMax H3, Wan 2.2 TI2V-5B, and LTX-Video |
| `workflows/minimax_h3_fl2v_gguf_turbo.json` | **Best quality, use this.** Audio+video, Turbo LoRA + 8 steps, native loop conditioning. ~40 min for a real 3s/16:9 clip. |
| `workflows/minimax_h3_fl2v_gguf.json` | Same model, baseline 25 steps, no LoRA. Much slower, quality reference only. |
| `workflows/wan22_ti2v_5b_turbo_gguf.json` | Fast (~9 min) but ignores the input image in testing — see CLAUDE.md before trusting this one. |
| `workflows/wan22_ti2v_5b_gguf.json` | Same model, base (non-turbo) checkpoint — not yet re-tested with real content. |
| `workflows/ltxv_distilled_gguf_i2v.json` | Fastest (~2 min), ~30% prompt adherence on compound prompts — fine for simple prompts only. |
| `test_assets/test_reference_room.png` | Standard test image (loft office, forest view, fireplace) used as the default input across all workflows |
| `cleanup.sh` | Safely remove the ComfyUI install if an experiment goes wrong (dry-run by default) |

## Why this needed its own repo

This hardware combination (Pascal GPU + tight RAM) isn't officially supported
by any of these models — nothing about this setup is the "just install and
run" path. Getting here involved: a PyTorch CUDA-build trap that silently
breaks all GPU compute on Pascal, hunting down community GGUF quantizations
sized for 8GB VRAM, fixing wrong model references and node-wiring bugs in
reference workflows (caught by `comfy-mcp`'s `validate_workflow` before
wasting GPU time), muting Ampere-only optimization nodes, finding a LoRA
that cuts MiniMax H3's generation time by 2.5x, and — the most
counterintuitive finding — that raw speed and actual prompt-following
capacity trade off hard at this model scale: the fastest models we tried
were also the least trustworthy for anything beyond simple prompts. All of
that is undone by a fresh OS install — this repo means it doesn't have to be
re-discovered.

## Optional: comfy-mcp

For controlling ComfyUI via Claude Code directly (validate/run/monitor
workflows through an API instead of clicking through the browser):

```bash
pip install comfy-mcp "comfy-cli>=1.14.0"   # or into a dedicated venv
claude mcp add comfy-mcp -s user -e COMFY_BIN=<path-to-comfy-cli-binary> -- comfy-mcp
```

**Must use `-s user` scope** — project/local scope only loads when Claude
Code's cwd exactly matches where it was registered from. See CLAUDE.md for
the full gotcha and usage pattern.
