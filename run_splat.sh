#!/bin/bash
# run_splat.sh — process a video into a 3D Gaussian Splat .ply file.

set -e
set -u

INPUT_VIDEO="/workspace/input.mp4"
PROJECT_DIR="/workspace/project"
PROCESSED_DIR="${PROJECT_DIR}/processed"
EXPORT_DIR="/workspace/exports"
NUM_FRAMES=300
ITERATIONS=30000

if [ ! -f "$INPUT_VIDEO" ]; then
    echo "ERROR: No video found at $INPUT_VIDEO"
    echo "Upload your video to /workspace/input.mp4 and try again."
    exit 1
fi

if ! command -v ns-train &> /dev/null; then
    echo "ERROR: nerfstudio not found. Is the conda env activated?"
    exit 1
fi

if ! nvidia-smi &> /dev/null; then
    echo "ERROR: No GPU detected. This pipeline requires an NVIDIA GPU."
    exit 1
fi

mkdir -p "$PROJECT_DIR" "$EXPORT_DIR"

echo "[1/3] Processing video with COLMAP..."
ns-process-data video \
    --data "$INPUT_VIDEO" \
    --output-dir "$PROCESSED_DIR" \
    --num-frames-target "$NUM_FRAMES"

echo "[2/3] Training splatfacto for $ITERATIONS iterations..."
ns-train splatfacto \
    --data "$PROCESSED_DIR" \
    --max-num-iterations "$ITERATIONS" \
    --pipeline.model.num-downscales 0 \
    --viewer.quit-on-train-completion True

echo "[3/3] Exporting .ply..."
LATEST_CONFIG=$(find outputs -name "config.yml" -type f -printf '%T@ %p\n' \
    | sort -n | tail -1 | cut -d' ' -f2)

if [ -z "$LATEST_CONFIG" ]; then
    echo "ERROR: No trained config found. Training may have failed."
    exit 1
fi

ns-export gaussian-splat \
    --load-config "$LATEST_CONFIG" \
    --output-dir "$EXPORT_DIR"

echo ""
echo "DONE. .ply file is in $EXPORT_DIR"
ls -lh "$EXPORT_DIR"
