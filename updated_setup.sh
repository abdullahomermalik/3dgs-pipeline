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
# --- Step 1: Miniconda ---
echo ""
echo "[1/5] Installing miniconda..."
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
# Accept Anaconda Terms of Service (required for conda install commands)
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r
# --- Step 2: Create the conda env & activate it ---
echo ""
echo "[2/5] Creating nerfstudio conda env (conda-forge only)..."
if ! conda env list | grep -qE "^nerfstudio\s"; then
    conda create -n nerfstudio python=3.10 pip -c conda-forge --override-channels -y
else
    echo "Env 'nerfstudio' already exists — skipping."
fi
# Activate the env for the remainder of this script
source /opt/conda/etc/profile.d/conda.sh
conda activate nerfstudio
# Upgrade pip inside the new env
python -m pip install --upgrade pip
# --- Step 3: System packages (ffmpeg, build tools — NOT colmap, installed via conda below) ---
echo ""
echo "[3/5] Installing system packages..."
apt-get update -qq
apt-get install -y --no-install-recommends \
    ffmpeg \
    git \
    wget \
    build-essential \
    libgl1 \
    libglib2.0-0
rm -rf /var/lib/apt/lists/*
# Install COLMAP 3.9 from conda-forge — this build includes CUDA SIFT support
# and does NOT require an OpenGL/display context, so it works headless on RunPod.
# Pinned to 3.9 — stable, CUDA-enabled, headless-compatible.
# Flag rename from 3.8 is already handled by current nerfstudio internals.
echo "Installing COLMAP 3.9 from conda-forge (CUDA-enabled, headless-compatible)..."
conda install -c conda-forge colmap=3.9 -y
# Install faiss-gpu — required dependency for COLMAP to load correctly
echo "Installing faiss-gpu..."
conda install -c conda-forge faiss-gpu -y
# --- Step 4: Install PyTorch, CUDA toolkit, tinycudann ---
echo ""
echo "[4/5] Installing PyTorch, CUDA toolkit, and tinycudann..."
# PyTorch
pip install torch==2.1.2+cu118 torchvision==0.16.2+cu118 \
    --extra-index-url https://download.pytorch.org/whl/cu118
# Conda CUDA toolkit (required for building tinycudann)
conda install -c "nvidia/label/cuda-11.8.0" cuda-toolkit -y
# tinycudann
pip install ninja git+https://github.com/NVlabs/tiny-cuda-nn/#subdirectory=bindings/torch
# --- Step 5: Install nerfstudio ---
echo ""
echo "[5/5] Installing nerfstudio..."
pip install nerfstudio
pip install gdown   # for downloading videos from Google Drive
# Create workspace directories
mkdir -p /workspace/videos
mkdir -p /workspace/projects
mkdir -p /workspace/exports
echo ""
echo "=========================================="
echo "  Setup complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Download a video:"
echo "     bash download.sh \"<google-drive-url>\" <name>"
echo ""
echo "  2. Process it:"
echo "     bash run_splat.sh <name>"
echo ""
echo "  3. Find your .ply in /workspace/exports/<name>.ply"
echo ""
