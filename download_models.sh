#!/usr/bin/env bash
# Downloads all models needed by the workflows in this repo.
# Run after setup.sh. ~38GB total (MiniMax H3 ~30GB + Wan 2.2 TI2V-5B ~9GB) —
# takes a while. Only need MiniMax H3's models if you specifically need audio;
# Wan 2.2 TI2V-5B is faster and sufficient for video-only use (see CLAUDE.md).
set -e
COMFYUI_DIR="${COMFYUI_DIR:-$HOME/ComfyUI}"
cd "$COMFYUI_DIR"

echo "=== Wan 2.2 TI2V-5B: diffusion model Q5_K_M (3.81GB) — the fast, no-audio option ==="
wget -c -q --show-progress -O "models/unet/Wan2.2-TI2V-5B-Q5_K_M.gguf" \
  "https://huggingface.co/QuantStack/Wan2.2-TI2V-5B-GGUF/resolve/main/Wan2.2-TI2V-5B-Q5_K_M.gguf"

echo "=== Wan 2.2 TI2V-5B: text encoder Q4_K_M (3.66GB) ==="
wget -c -q --show-progress -O "models/text_encoders/umt5-xxl-encoder-Q4_K_M.gguf" \
  "https://huggingface.co/city96/umt5-xxl-encoder-gguf/resolve/main/umt5-xxl-encoder-Q4_K_M.gguf"

echo "=== Wan 2.2 TI2V-5B: VAE (1.41GB) ==="
wget -c -q --show-progress -O "models/vae/wan2.2_vae.safetensors" \
  "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan2.2_vae.safetensors"

echo "=== MiniMax H3 (audio+video) — only needed if audio matters, see CLAUDE.md ==="
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
