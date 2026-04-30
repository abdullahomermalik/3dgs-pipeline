# Start from the same RunPod template the client would otherwise use.
FROM runpod/pytorch:2.1.0-py3.10-cuda11.8.0-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    colmap \
    ffmpeg \
    git \
    wget \
    build-essential \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh \
    && bash /tmp/miniconda.sh -b -p /opt/conda \
    && rm /tmp/miniconda.sh

ENV PATH=/opt/conda/bin:$PATH

RUN conda create -n nerfstudio python=3.10 -c conda-forge --override-channels -y

SHELL ["conda", "run", "-n", "nerfstudio", "/bin/bash", "-c"]

RUN pip install torch==2.1.2+cu118 torchvision==0.16.2+cu118 \
    --extra-index-url https://download.pytorch.org/whl/cu118

RUN pip install ninja \
    && pip install git+https://github.com/NVlabs/tiny-cuda-nn/#subdirectory=bindings/torch

RUN pip install nerfstudio

RUN mkdir -p /workspace/exports

COPY run_splat.sh /workspace/run_splat.sh
RUN chmod +x /workspace/run_splat.sh

WORKDIR /workspace
CMD ["conda", "run", "--no-capture-output", "-n", "nerfstudio", "/bin/bash"]
