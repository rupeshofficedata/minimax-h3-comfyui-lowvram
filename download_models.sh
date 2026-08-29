#!/usr/bin/env bash
# Downloads all models needed by the workflows in this repo.
# Run after setup.sh. ~52GB total for everything — takes a while.
#
# Recommendation (2026-08-29, after real-content testing across all three
# model families — see CLAUDE.md "Read this first" for the full comparison):
# MiniMax H3 Turbo gave by far the best prompt-following/quality (user's own
# verdict: "80% perfect") and is the only one with a real audio+seamless-loop
# capable architecture. Wan 2.2 Turbo and LTX-Video are much faster but
# proved unreliable (Wan ignores the input image entirely) or too weak for
# compound prompts (LTX, ~30% adherence) — keep them only if you specifically
# need the speed and can live with simpler prompts / more manual QA.
set -e
COMFYUI_DIR="${COMFYUI_DIR:-$HOME/ComfyUI}"
cd "$COMFYUI_DIR"

echo "=== MiniMax H3 (recommended default — audio+video, best prompt-following) ==="

echo "--- audio VAE (0.6GB) ---"
wget -c -q --show-progress -O "models/vae/minimax_h3_audio_vae_fp32.safetensors" \
  "https://huggingface.co/Abiray/MiniMax-H3-GGUF/resolve/main/vae/minimax_h3_audio_vae_fp32.safetensors"

echo "--- video VAE (5.2GB) ---"
wget -c -q --show-progress -O "models/vae/minimax_h3_video_vae_fp16.safetensors" \
  "https://huggingface.co/Abiray/MiniMax-H3-GGUF/resolve/main/vae/minimax_h3_video_vae_fp16.safetensors"

echo "--- diffusion model, pruned Q3_K_M (8.9GB) ---"
wget -c -q --show-progress -O "models/unet/MiniMax-H3-FL2VA-Pruned-Q3_K_M.gguf" \
  "https://huggingface.co/Abiray/MiniMax-H3-Pruned-GGUF/resolve/main/MiniMax-H3-FL2VA-Pruned-Q3_K_M.gguf"

echo "--- text encoder, Q4_K_M (14.6GB) ---"
wget -c -q --show-progress -O "models/text_encoders/qwen3vl_32b_minimax_h3-Q4_K_M.gguf" \
  "https://huggingface.co/Abiray/MiniMax-H3-GGUF/resolve/main/text_encoders/qwen3vl_32b_minimax_h3-Q4_K_M.gguf"

echo "--- Turbo LoRA (0.6GB) — needed by minimax_h3_fl2v_gguf_turbo.json, the one to use ---"
wget -c -q --show-progress -O "models/loras/minimax_h3_turbo_4step_ckpt600_ema_V4.safetensors" \
  "https://huggingface.co/Abiray/MiniMax-H3-Turbo-Lora-Pruned-ComfyUI/resolve/main/minimax_h3_turbo_4step_ckpt600_ema_V4.safetensors"

echo "=== Wan 2.2 TI2V-5B (fast, video-only; Turbo variant unreliable for I2V — see CLAUDE.md) ==="

echo "--- diffusion model Q5_K_M (3.81GB) ---"
wget -c -q --show-progress -O "models/unet/Wan2.2-TI2V-5B-Q5_K_M.gguf" \
  "https://huggingface.co/QuantStack/Wan2.2-TI2V-5B-GGUF/resolve/main/Wan2.2-TI2V-5B-Q5_K_M.gguf"

echo "--- text encoder Q4_K_M (3.66GB) ---"
wget -c -q --show-progress -O "models/text_encoders/umt5-xxl-encoder-Q4_K_M.gguf" \
  "https://huggingface.co/city96/umt5-xxl-encoder-gguf/resolve/main/umt5-xxl-encoder-Q4_K_M.gguf"

echo "--- VAE (1.41GB) ---"
wget -c -q --show-progress -O "models/vae/wan2.2_vae.safetensors" \
  "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan2.2_vae.safetensors"

echo "--- Turbo checkpoint Q5_K_M (3.6GB) — fast but ignores the input image, see CLAUDE.md ---"
wget -c -q --show-progress -O "models/unet/Wan2_2-TI2V-5B-Turbo-Q5_K_M.gguf" \
  "https://huggingface.co/hum-ma/Wan2.2-TI2V-5B-Turbo-GGUF/resolve/main/Wan2_2-TI2V-5B-Turbo-Q5_K_M.gguf"

echo "=== LTX-Video 2B distilled (fastest, ~30% prompt adherence on compound prompts) ==="

echo "--- diffusion model Q5_K_M (1.48GB) ---"
wget -c -q --show-progress -O "models/unet/ltxv-2b-0.9.6-distilled-Q5_K_M.gguf" \
  "https://huggingface.co/city96/LTX-Video-0.9.6-distilled-gguf/resolve/main/ltxv-2b-0.9.6-distilled-04-25-Q5_K_M.gguf"

echo "--- text encoder Q4_K_M (2.90GB) ---"
wget -c -q --show-progress -O "models/text_encoders/t5-v1_1-xxl-encoder-Q4_K_M.gguf" \
  "https://huggingface.co/city96/t5-v1_1-xxl-encoder-gguf/resolve/main/t5-v1_1-xxl-encoder-Q4_K_M.gguf"

echo "--- VAE (2.49GB) ---"
wget -c -q --show-progress -O "models/vae/LTX-Video-0.9.6-VAE-BF16.safetensors" \
  "https://huggingface.co/city96/LTX-Video-0.9.6-distilled-gguf/resolve/main/LTX-Video-0.9.6-VAE-BF16.safetensors"

echo "=== ALL DOWNLOADS COMPLETE (~52GB) ==="
