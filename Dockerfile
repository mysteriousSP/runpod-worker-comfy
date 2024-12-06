# Stage 1: Base image with common dependencies
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04 AS base

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    PYTHONUNBUFFERED=1 \
    CMAKE_BUILD_PARALLEL_LEVEL=8 \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility

# Install Python, git, and other necessary tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.10 \
    python3-pip \
    git \
    wget \
    libgl1-mesa-glx \
    dos2unix \
    libglib2.0-0 \
    libsm6 \
    libxrender1 \
    libxext6 \
    fonts-dejavu-core \
    fonts-freefont-ttf \
    && ln -sf /usr/bin/python3.10 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Install comfyui and dependencies
RUN pip install --no-cache-dir comfy-cli runpod requests opencv-python-headless \
    && yes | comfy --workspace /comfyui install --cuda-version 11.8 --nvidia --version 0.2.7

# Set up comfyui configuration and scripts
WORKDIR /comfyui
COPY comfyui/ ./
COPY src/extra_model_paths.yaml ./
COPY src/start.sh src/restore_snapshot.sh src/rp_handler.py test_input.json /
COPY ./comfyui/snapshot/*snapshot*.json /

# Convert scripts to Unix line endings and make them executable
RUN dos2unix /start.sh /restore_snapshot.sh \
    && chmod +x /start.sh /restore_snapshot.sh

# Restore snapshot and set up models
RUN /restore_snapshot.sh \
    && mkdir -p /comfyui/models \
    && chmod -R 755 /comfyui/models

# Stage 2: Download models and custom nodes
FROM base AS downloader
WORKDIR /comfyui/custom_nodes
RUN git clone https://github.com/Suzie1/comfyui_Comfyroll_CustomNodes.git

WORKDIR /comfyui
RUN mkdir -p /comfyui/workflows
COPY ./comfyui/workflows/paderai_pixied_flux_hmonglora_schnell.json /comfyui/workflows/paderai_pixied_flux_hmonglora_schnell.json

# Stage 3: Final image
FROM base AS final
COPY --from=downloader /comfyui/custom_nodes /comfyui/custom_nodes
COPY --from=downloader /comfyui/workflows /comfyui/workflows

WORKDIR /
# Set the container's default command
CMD ["/start.sh"]
