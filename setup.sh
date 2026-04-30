#!/bin/bash
# setup.sh — one-time setup for the 3DGS pipeline.
#
# Run this ONCE per fresh RunPod pod, after launching with the template:
#   runpod/pytorch:2.1.0-py3.10-cuda11.8.0-devel-ubuntu22.04
#
# Usage:
#   wget https://raw.githubusercontent.com/abdullahomermalik/3dgs-pipeline/main/setup.sh
#   bash setup.sh

set -e
set -u

echo "=========================================="
echo "  3DGS Pipeline — One-time Setup"
echo "=========================================="

# --- Step 1: System packages (colmap + ffmpeg + build tools) ---
echo ""
echo "[1/6] Installing system packages..."
apt-get update -qq
apt-get install -y --no-install-recommends \
    colmap \
    ffmpeg \
    git \
    wget \
    build-essential \
    libgl1 \
    libglib2.0-0
rm -rf /var/lib/apt/lists/*

# --- Step 2: Miniconda ---
echo ""
echo "[2/6] Installing miniconda..."
if [ ! -d "/opt/conda" ]; then
    wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh
    bash /tmp/miniconda.sh -b -p /opt/conda
    rm /tmp/miniconda.sh
else
    echo "Miniconda already installed at /opt/conda — skipping."
fi

# Add conda to PATH for this shell session
export PATH="/opt/conda/bin:$PATH"

# Persist the PATH change for future SSH sessions
if ! grep -q "/opt/conda/bin" ~/.bashrc; then
    echo 'export PATH="/opt/conda/bin:$PATH"' >> ~/.bashrc
fi

# --- Step 3: Create the conda env ---
echo ""
echo "[3/6] Creating nerfstudio conda env..."
if ! conda env list | grep -q "^nerfstudio "; then
    conda create -n nerfstudio python=3.10 -c conda-forge --override-channels -y
else
    echo "Env 'nerfstudio' already exists — skipping."
fi

# Activate the env for the remainder of this script
source /opt/conda/etc/profile.d/conda.sh
conda activate nerfstudio

# --- Step 4: Install torch matching nerfstudio's documented requirements ---
echo ""
echo "[4/6] Installing torch 2.1.2 + cu118..."
pip install torch==2.1.2+cu118 torchvision==0.16.2+cu118 \
    --index-url https://download.pytorch.org/whl/cu118

# --- Step 5: Install tinycudann (compiles CUDA from source — slow, ~10-15 min) ---
echo ""
echo "[5/6] Installing tinycudann (this is the slow step, ~10-15 min)..."
pip install ninja
pip install git+https://github.com/NVlabs/tiny-cuda-nn/#subdirectory=bindings/torch

# --- Step 6: Install nerfstudio ---
echo ""
echo "[6/6] Installing nerfstudio..."
pip install nerfstudio

# Set up workspace structure
mkdir -p /workspace/exports

echo ""
echo "=========================================="
echo "  Setup complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Upload your video to /workspace/input.mp4"
echo "  2. Pull run_splat.sh:"
echo "     wget https://raw.githubusercontent.com/abdullahomermalik/3dgs-pipeline/main/run_splat.sh"
echo "  3. Run it:"
echo "     bash run_splat.sh"
echo ""
