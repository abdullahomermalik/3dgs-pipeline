#!/bin/bash
# download.sh — pull a video from Google Drive and save it with a custom name.
#
# Usage:
#   bash download.sh <google-drive-url> <name>
#
# Example:
#   bash download.sh "https://drive.google.com/file/d/abc.../view" video1
#
# Result:
#   Video saved to /workspace/videos/<name>.mp4

set -e
set -u

# --- Argument check ---
if [ "$#" -ne 2 ]; then
    echo "Usage: bash download.sh <google-drive-url> <name>"
    echo "Example: bash download.sh \"https://drive.google.com/file/d/abc.../view\" video1"
    exit 1
fi

URL="$1"
NAME="$2"

# Reject names with slashes or whitespace — keeps things sane on disk
if [[ "$NAME" =~ [[:space:]/] ]]; then
    echo "ERROR: Name cannot contain spaces or slashes."
    echo "Got: '$NAME'"
    exit 1
fi

# --- Activate the conda env (where gdown lives) ---
if [ ! -f "/opt/conda/etc/profile.d/conda.sh" ]; then
    echo "ERROR: Conda not found. Did you run setup.sh first?"
    exit 1
fi

source /opt/conda/etc/profile.d/conda.sh
conda activate nerfstudio

# Make sure gdown is available (defensive — should already be installed by setup.sh)
if ! command -v gdown &> /dev/null; then
    echo "gdown not found — installing it now."
    pip install gdown
fi

# Make sure the videos folder exists
mkdir -p /workspace/videos

OUTPUT="/workspace/videos/${NAME}.mp4"

# Warn if we're about to overwrite an existing video with the same name
if [ -f "$OUTPUT" ]; then
    echo "WARNING: $OUTPUT already exists and will be overwritten."
fi

echo "=========================================="
echo "  Downloading from Google Drive"
echo "=========================================="
echo "  URL:  $URL"
echo "  Name: $NAME"
echo "  Path: $OUTPUT"
echo ""

# gdown v6+ no longer needs --fuzzy; it handles URLs directly
gdown "$URL" -O "$OUTPUT"

# --- Verify the download actually produced something ---
if [ -f "$OUTPUT" ] && [ -s "$OUTPUT" ]; then
    SIZE=$(du -h "$OUTPUT" | cut -f1)
    echo ""
    echo "=========================================="
    echo "  Download complete"
    echo "=========================================="
    echo "  File: $OUTPUT"
    echo "  Size: $SIZE"
    echo ""
    echo "Next step:"
    echo "  bash run_splat.sh $NAME"
    echo ""
else
    echo ""
    echo "ERROR: Download failed or file is empty."
    echo "Things to check:"
    echo "  - Is the Drive file shared as 'Anyone with the link'?"
    echo "  - Is the URL correct?"
    echo "  - Try: pip install --upgrade gdown   (in case Google changed their page)"
    # Clean up empty file if one was created
    if [ -f "$OUTPUT" ] && [ ! -s "$OUTPUT" ]; then
        rm "$OUTPUT"
    fi
    exit 1
fi
