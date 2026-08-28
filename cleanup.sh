#!/usr/bin/env bash
#
# Cleanup script for a MiniMax H3 / ComfyUI local install attempt.
# Safe by default: dry-run unless you pass --force, and never touches
# anything outside the ComfyUI directory it's told about.
#
# Usage:
#   ./comfyui-h3-cleanup.sh                 # dry run, shows what would be removed
#   ./comfyui-h3-cleanup.sh --force         # actually deletes (asks for typed confirmation)
#   ./comfyui-h3-cleanup.sh --force --yes   # deletes without the confirmation prompt
#   ./comfyui-h3-cleanup.sh --keep-outputs  # before deleting, move models/output/* to ~/comfyui-h3-outputs-rescued
#   COMFYUI_DIR=/other/path ./comfyui-h3-cleanup.sh --force
#
set -euo pipefail

COMFYUI_DIR="${COMFYUI_DIR:-$HOME/ComfyUI}"
RESCUE_DIR="$HOME/comfyui-h3-outputs-rescued"

FORCE=0
SKIP_CONFIRM=0
KEEP_OUTPUTS=0

for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    --yes) SKIP_CONFIRM=1 ;;
    --keep-outputs) KEEP_OUTPUTS=1 ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

if [ ! -e "$COMFYUI_DIR" ]; then
  echo "Nothing to clean up: $COMFYUI_DIR does not exist."
  exit 0
fi

if [ ! -d "$COMFYUI_DIR" ]; then
  echo "Refusing to proceed: $COMFYUI_DIR exists but is not a directory." >&2
  exit 1
fi

# Sanity check: only proceed if this actually looks like a ComfyUI checkout,
# so a wrong COMFYUI_DIR value can't nuke an unrelated folder.
if [ ! -f "$COMFYUI_DIR/main.py" ] || [ ! -d "$COMFYUI_DIR/models" ]; then
  echo "Refusing to proceed: $COMFYUI_DIR doesn't look like a ComfyUI install" >&2
  echo "(expected to find main.py and a models/ subdirectory there)." >&2
  exit 1
fi

SIZE=$(du -sh "$COMFYUI_DIR" 2>/dev/null | cut -f1)
echo "Target: $COMFYUI_DIR"
echo "Size:   $SIZE"
echo
echo "Contents breakdown:"
du -sh "$COMFYUI_DIR"/*/ 2>/dev/null | sort -rh || true
echo

if [ "$KEEP_OUTPUTS" -eq 1 ] && [ -d "$COMFYUI_DIR/output" ] && [ -n "$(ls -A "$COMFYUI_DIR/output" 2>/dev/null)" ]; then
  echo "Rescuing generated files from $COMFYUI_DIR/output -> $RESCUE_DIR"
  mkdir -p "$RESCUE_DIR"
  cp -r "$COMFYUI_DIR/output/." "$RESCUE_DIR/"
  echo "Rescued $(du -sh "$RESCUE_DIR" | cut -f1) of outputs."
  echo
fi

if [ "$FORCE" -ne 1 ]; then
  echo "Dry run only — nothing deleted. Re-run with --force to actually remove $COMFYUI_DIR"
  exit 0
fi

if [ "$SKIP_CONFIRM" -ne 1 ]; then
  read -r -p "Type DELETE to permanently remove $COMFYUI_DIR ($SIZE): " confirm
  if [ "$confirm" != "DELETE" ]; then
    echo "Aborted — no changes made."
    exit 1
  fi
fi

rm -rf -- "$COMFYUI_DIR"
echo "Removed $COMFYUI_DIR ($SIZE freed)."

if [ "$KEEP_OUTPUTS" -eq 1 ] && [ -d "$RESCUE_DIR" ]; then
  echo "Your rescued outputs are still at: $RESCUE_DIR"
fi

echo
echo "Note: this does NOT touch ~/.cache/huggingface (shared cache, may hold other" \
     "models too) or any Python venv you created outside $COMFYUI_DIR. If you used" \
     "a venv INSIDE $COMFYUI_DIR (recommended), it's already gone with the rm above."
