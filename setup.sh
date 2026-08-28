#!/usr/bin/env bash
# Reproduces the ComfyUI + MiniMax H3 install from scratch on this machine
# (GTX 1080 / Pascal, 8GB VRAM, 15.6GB RAM). Read CLAUDE.md for the *why*
# behind every step here — this script is the *how*.
#
# Usage: ./setup.sh [target_dir]   (default target_dir: ~/ComfyUI)
# After this: ./download_models.sh, then launch per README.md.
set -euo pipefail

COMFYUI_DIR="${1:-$HOME/ComfyUI}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -e "$COMFYUI_DIR" ]; then
  echo "Refusing to overwrite existing $COMFYUI_DIR — remove it first or pass a different target_dir." >&2
  exit 1
fi

echo "=== 1/6: clone ComfyUI ==="
git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git "$COMFYUI_DIR"
cd "$COMFYUI_DIR"

echo "=== 2/6: create venv ==="
python3 -m venv venv
venv/bin/pip install --upgrade pip -q

echo "=== 3/6: install torch — MUST be cu126, not the cu130 default (see CLAUDE.md: 'The cu130 vs cu126 trap') ==="
venv/bin/pip install --no-cache-dir torch==2.13.0 torchvision torchaudio --index-url https://download.pytorch.org/whl/cu126
venv/bin/python -c "
import torch
assert torch.cuda.is_available(), 'CUDA not available'
x = torch.randn(10, 10, device='cuda')
(x @ x).sum().item()
print('torch', torch.__version__, '- CUDA compute check OK on', torch.cuda.get_device_name(0))
"

echo "=== 4/6: install ComfyUI + Manager requirements ==="
venv/bin/pip install --no-cache-dir -r requirements.txt
venv/bin/pip install --no-cache-dir -r manager_requirements.txt

echo "=== 5/6: install custom nodes (GGUF loader, KJNodes for image resize) ==="
git clone https://github.com/city96/ComfyUI-GGUF.git custom_nodes/ComfyUI-GGUF
venv/bin/pip install --no-cache-dir -r custom_nodes/ComfyUI-GGUF/requirements.txt
# comfyui-kjnodes: installed via ComfyUI-Manager in the original setup (registry
# package, not a plain git clone) — the manager UI / mcp__comfy-mcp__install_node
# with name "comfyui-kjnodes" is the supported path. If doing this by hand:
git clone https://github.com/kijai/ComfyUI-KJNodes.git custom_nodes/comfyui-kjnodes
[ -f custom_nodes/comfyui-kjnodes/requirements.txt ] && venv/bin/pip install --no-cache-dir -r custom_nodes/comfyui-kjnodes/requirements.txt

echo "=== 6/6: xformers (confirmed working on Pascal despite py39 wheel tag) ==="
venv/bin/pip install --no-cache-dir xformers

echo "=== copy in the known-good workflows ==="
mkdir -p user/default/workflows
cp "$REPO_DIR"/workflows/*.json user/default/workflows/

echo
echo "Setup done. Next:"
echo "  1. COMFYUI_DIR=$COMFYUI_DIR $REPO_DIR/download_models.sh   (~30GB)"
echo "  2. cd $COMFYUI_DIR && venv/bin/python main.py --enable-manager"
echo "  3. Open http://127.0.0.1:8188 (NOT 'localhost' — see CLAUDE.md)"
