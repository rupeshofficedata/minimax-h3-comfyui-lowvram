#!/usr/bin/env bash
# Downloads all models needed by both workflows in this repo.
# Run after setup.sh. ~30GB total — takes a while.
set -e
COMFYUI_DIR="${COMFYUI_DIR:-$HOME/ComfyUI}"
cd "$COMFYUI_DIR"

echo "=== baseline workflow's original source JSON (reference only; use workflows/ in this repo instead) ==="
wget -c -q --show-progress -O "/tmp/minimax_fl2v_gguf_workflow.json" \
  "https://huggingface.co/Abiray/MiniMax-H3-GGUF/resolve/main/minimax_fl2v_gguf_workflow.json" || true

echo "=== audio VAE (0.6GB) ==="
wget -c -q --show-progress -O "models/vae/minimax_h3_audio_vae_fp32.safetensors" \
  "https://huggingface.co/Abiray/MiniMax-H3-GGUF/resolve/main/vae/minimax_h3_audio_vae_fp32.safetensors"

echo "=== video VAE (5.2GB) ==="
wget -c -q --show-progress -O "models/vae/minimax_h3_video_vae_fp16.safetensors" \
  "https://huggingface.co/Abiray/MiniMax-H3-GGUF/resolve/main/vae/minimax_h3_video_vae_fp16.safetensors"

echo "=== diffusion model, pruned Q3_K_M (8.9GB) ==="
wget -c -q --show-progress -O "models/unet/MiniMax-H3-FL2VA-Pruned-Q3_K_M.gguf" \
  "https://huggingface.co/Abiray/MiniMax-H3-Pruned-GGUF/resolve/main/MiniMax-H3-FL2VA-Pruned-Q3_K_M.gguf"

echo "=== text encoder, Q4_K_M (14.6GB) ==="
wget -c -q --show-progress -O "models/text_encoders/qwen3vl_32b_minimax_h3-Q4_K_M.gguf" \
  "https://huggingface.co/Abiray/MiniMax-H3-GGUF/resolve/main/text_encoders/qwen3vl_32b_minimax_h3-Q4_K_M.gguf"

echo "=== Turbo LoRA (0.6GB) — needed by minimax_h3_fl2v_gguf_turbo.json ==="
wget -c -q --show-progress -O "models/loras/minimax_h3_turbo_4step_ckpt600_ema_V4.safetensors" \
  "https://huggingface.co/Abiray/MiniMax-H3-Turbo-Lora-Pruned-ComfyUI/resolve/main/minimax_h3_turbo_4step_ckpt600_ema_V4.safetensors"

echo "=== ALL DOWNLOADS COMPLETE (~30GB) ==="
