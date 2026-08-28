# minimax-h3-comfyui-lowvram

Reproducible setup for running [MiniMax H3](https://www.minimax.io/blog/minimax-h3)
(text/image-to-video with native audio) locally in ComfyUI on a GPU that
officially has no business running it: a GTX 1080 (Pascal, 8GB VRAM, no
tensor cores), 15.6GB system RAM.

This repo is **not** a ComfyUI install — it's the notes, scripts, and
workflow files needed to rebuild one from scratch after a format/reinstall.
Models (~30GB) are downloaded separately, not stored here.

## Quick start (fresh machine)

```bash
git clone <this-repo-url>
cd minimax-h3-comfyui-lowvram
./setup.sh                 # clones ComfyUI, builds the venv, installs everything
./download_models.sh       # ~30GB, all four model files + the Turbo LoRA
cd ~/ComfyUI && venv/bin/python main.py --enable-manager
# open http://127.0.0.1:8188 (not "localhost" — see CLAUDE.md)
```

Then in ComfyUI, open the `minimax_h3_fl2v_gguf_turbo` workflow (Workflows
sidebar) and hit Run. Start with the default 2-second/low-resolution settings
before pushing further — see CLAUDE.md for why.

## What's in here

| File | What |
|---|---|
| `CLAUDE.md` | Everything non-obvious learned getting this working — read this first if something breaks. Auto-loaded by Claude Code when working in this repo or the ComfyUI directory. |
| `setup.sh` | Clones ComfyUI, creates the venv, installs the *correct* torch build, custom nodes, and xformers |
| `download_models.sh` | Downloads the GGUF diffusion model, text encoder, VAEs, and Turbo LoRA |
| `workflows/minimax_h3_fl2v_gguf.json` | Baseline: 25 sampling steps, no LoRA. Proven working end-to-end (~72 min for a 2s clip). |
| `workflows/minimax_h3_fl2v_gguf_turbo.json` | Same, with the Turbo LoRA + 8 steps. **Use this one** — ~28 min for the same clip. |
| `cleanup.sh` | Safely remove the ComfyUI install if an experiment goes wrong (dry-run by default) |

## Why this needed its own repo

This hardware combination (Pascal GPU + tight RAM) isn't officially supported
by MiniMax H3 — nothing about this setup is the "just install and run" path.
Getting here involved: a PyTorch CUDA-build trap that silently breaks all GPU
compute on Pascal, hunting down community GGUF quantizations sized for 8GB
VRAM, fixing wrong model references in the reference workflow, muting
Ampere-only optimization nodes, and finding a LoRA that cuts generation time
by 2.5x. All of that is undone by a fresh OS install — this repo means it
doesn't have to be re-discovered.

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
