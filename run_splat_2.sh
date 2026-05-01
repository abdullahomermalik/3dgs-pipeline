#!/bin/bash
# run_splat.sh — process a named video into a 3D Gaussian Splat .ply file.
#
# Usage:
#   bash run_splat.sh <name>
#
# Example:
#   bash run_splat.sh video1
#
# Expects video at /workspace/videos/<name>.mp4
# Produces .ply at /workspace/exports/<name>.ply

set -e
set -u

# Force Qt to run headless (no display on RunPod servers)
# Note: COLMAP GPU SIFT now uses CUDA directly (conda-forge build),
# so it does NOT need an OpenGL context — this flag only affects Qt UI.
export QT_QPA_PLATFORM=offscreen
export DISPLAY=""

# --- Argument check ---
if [ "$#" -ne 1 ]; then
    echo "Usage: bash run_splat.sh <name>"
    echo "Example: bash run_splat.sh video1"
    exit 1
fi

NAME="$1"

# Reject names with slashes or whitespace
if [[ "$NAME" =~ [[:space:]/] ]]; then
    echo "ERROR: Name cannot contain spaces or slashes."
    echo "Got: '$NAME'"
    exit 1
fi

# --- Activate the conda env automatically ---
if [ ! -f "/opt/conda/etc/profile.d/conda.sh" ]; then
    echo "ERROR: Conda not found. Did you run setup.sh first?"
    exit 1
fi

source /opt/conda/etc/profile.d/conda.sh
conda activate nerfstudio

# --- Configuration ---
INPUT_VIDEO="/workspace/videos/${NAME}.mp4"
PROJECT_DIR="/workspace/projects/${NAME}"
PROCESSED_DIR="${PROJECT_DIR}/processed"
TRAINING_DIR="${PROJECT_DIR}/training"
TEMP_EXPORT="${PROJECT_DIR}/export"
EXPORT_DIR="/workspace/exports"
NUM_FRAMES=300
ITERATIONS=30000

# --- Sanity checks ---
if [ ! -f "$INPUT_VIDEO" ]; then
    echo "ERROR: No video found at $INPUT_VIDEO"
    echo "Did you run 'bash download.sh <url> $NAME' first?"
    exit 1
fi

if ! command -v ns-train &> /dev/null; then
    echo "ERROR: nerfstudio not found. Did you run setup.sh first?"
    exit 1
fi

if ! nvidia-smi &> /dev/null; then
    echo "ERROR: No GPU detected. This pipeline requires an NVIDIA GPU."
    exit 1
fi

# --- Make sure all output directories exist ---
mkdir -p "$PROJECT_DIR"
mkdir -p "$EXPORT_DIR"

echo "=========================================="
echo "  Processing: $NAME"
echo "=========================================="
echo "  Input:  $INPUT_VIDEO"
echo "  Output: ${EXPORT_DIR}/${NAME}.ply"
echo ""

# --- Step 1: COLMAP processing (extract frames + camera poses) ---
# GPU SIFT is now enabled — the conda-forge COLMAP build uses CUDA directly
# and does not need an OpenGL context, so it works on headless RunPod servers.
echo "[1/3] Processing video with COLMAP (GPU SIFT)..."
ns-process-data video \
    --data "$INPUT_VIDEO" \
    --output-dir "$PROCESSED_DIR" \
    --num-frames-target "$NUM_FRAMES"

# --- Step 2: Train splatfacto ---
echo ""
echo "[2/3] Training splatfacto for $ITERATIONS iterations..."
ns-train splatfacto \
    --data "$PROCESSED_DIR" \
    --output-dir "$TRAINING_DIR" \
    --max-num-iterations "$ITERATIONS" \
    --pipeline.model.num-downscales 0 \
    --viewer.quit-on-train-completion True

# --- Step 3: Export the .ply ---
echo ""
echo "[3/3] Exporting .ply..."

# Find the latest config.yml that nerfstudio just wrote for THIS project's training
LATEST_CONFIG=$(find "$TRAINING_DIR" -name "config.yml" -type f -printf '%T@ %p\n' \
    | sort -n | tail -1 | cut -d' ' -f2)

if [ -z "$LATEST_CONFIG" ]; then
    echo "ERROR: No trained config found. Training may have failed."
    echo "Check $TRAINING_DIR for output."
    exit 1
fi

mkdir -p "$TEMP_EXPORT"

ns-export gaussian-splat \
    --load-config "$LATEST_CONFIG" \
    --output-dir "$TEMP_EXPORT"

# Find whatever .ply got produced (defensive — in case the filename differs across versions)
PRODUCED_PLY=$(find "$TEMP_EXPORT" -maxdepth 1 -name "*.ply" -type f | head -1)

if [ -z "$PRODUCED_PLY" ]; then
    echo "ERROR: Export step did not produce a .ply file."
    echo "Contents of $TEMP_EXPORT:"
    ls -la "$TEMP_EXPORT"
    exit 1
fi

# Move/rename the produced .ply to the named final location
FINAL_PLY="${EXPORT_DIR}/${NAME}.ply"
mv "$PRODUCED_PLY" "$FINAL_PLY"

echo ""
echo "=========================================="
echo "  DONE — ${NAME}.ply"
echo "=========================================="
ls -lh "$FINAL_PLY"
echo ""
echo "Download from: $FINAL_PLY"
echo ""
