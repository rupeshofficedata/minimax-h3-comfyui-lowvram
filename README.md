# minimax-h3-comfyui-lowvram

Reproducible setup for running local text/image-to-video generation in
ComfyUI on a GPU that officially has no business running any of this: a
GTX 1080 (Pascal, 8GB VRAM, no tensor cores), 15.6GB system RAM. Covers two
models:

- **[Wan 2.2 TI2V-5B](https://huggingface.co/QuantStack/Wan2.2-TI2V-5B-GGUF)** — video only, no audio. **~10 min for a short clip. Use this by default.**
- **[MiniMax H3](https://www.minimax.io/blog/minimax-h3)** — video **with native joint audio**, much larger (26-33B params vs 5B), 21-72 min for a short clip on this hardware. Use only when audio is required.

This repo is **not** a ComfyUI install — it's the notes, scripts, and
workflow files needed to rebuild one from scratch after a format/reinstall.
Models are downloaded separately, not stored here (~9GB for Wan 2.2 alone,
~38GB if you also want MiniMax H3).

## Quick start (fresh machine)

```bash
git clone <this-repo-url>
cd minimax-h3-comfyui-lowvram
./setup.sh                 # clones ComfyUI, builds the venv, installs everything
./download_models.sh       # ~9-38GB depending on which model(s) you want
cd ~/ComfyUI && venv/bin/python main.py --enable-manager
# open http://127.0.0.1:8188 (not "localhost" — see CLAUDE.md)
```

Then in ComfyUI, open the `wan22_ti2v_5b_gguf` workflow (Workflows sidebar,
fastest, no audio) or `minimax_h3_fl2v_gguf_turbo` (audio, slower) and hit
Run. Start with the default low-resolution/short-duration settings before
pushing further — see CLAUDE.md for why.

## What's in here

| File | What |
|---|---|
| `CLAUDE.md` | Everything non-obvious learned getting this working — read this first if something breaks. Auto-loaded by Claude Code when working in this repo or the ComfyUI directory. |
| `setup.sh` | Clones ComfyUI, creates the venv, installs the *correct* torch build, custom nodes, and xformers |
| `download_models.sh` | Downloads all GGUF model files for both Wan 2.2 TI2V-5B and MiniMax H3 |
| `workflows/wan22_ti2v_5b_gguf.json` | **Fastest, no audio.** ~10 min for a 512x512/1s clip. |
| `workflows/minimax_h3_fl2v_gguf_turbo.json` | Audio+video, Turbo LoRA + 8 steps. ~28 min for a 2s clip. |
| `workflows/minimax_h3_fl2v_gguf.json` | Audio+video baseline, 25 steps, no LoRA. ~72 min for a 2s clip — only for reference, prefer the turbo version. |
| `cleanup.sh` | Safely remove the ComfyUI install if an experiment goes wrong (dry-run by default) |

## Why this needed its own repo

This hardware combination (Pascal GPU + tight RAM) isn't officially supported
by either model — nothing about this setup is the "just install and run"
path. Getting here involved: a PyTorch CUDA-build trap that silently breaks
all GPU compute on Pascal, hunting down community GGUF quantizations sized
for 8GB VRAM, fixing wrong model references in reference workflows, muting
Ampere-only optimization nodes, finding a LoRA that cuts MiniMax H3's
generation time by 2.5x, and — the biggest win — discovering that a smaller
model (Wan 2.2 TI2V-5B) that fits entirely in VRAM beats every attempt to
speed up a larger one that doesn't. All of that is undone by a fresh OS
install — this repo means it doesn't have to be re-discovered.

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
