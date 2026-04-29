FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    TORCH_INDEX_URL=https://download.pytorch.org/whl/cu121 \
    HF_HOME=/app/cache/huggingface \
    TRANSFORMERS_CACHE=/app/cache/huggingface

RUN apt-get update && apt-get install -y --no-install-recommends \
        software-properties-common \
    && add-apt-repository -y ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y --no-install-recommends \
        python3.10 python3.10-venv python3.10-dev python3-pip \
        git wget curl ca-certificates tini \
        libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 \
        build-essential \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/python3.10 /usr/local/bin/python \
    && ln -sf /usr/bin/python3.10 /usr/local/bin/python3 \
    && python -m pip install --upgrade pip wheel setuptools

WORKDIR /app

COPY requirements_versions.txt /app/requirements_versions.txt
RUN python -m pip install torch==2.3.1 torchvision==0.18.1 --extra-index-url ${TORCH_INDEX_URL} \
 && python -m pip install -r /app/requirements_versions.txt \
 && python -m pip install xformers==0.0.27

COPY . /app

# Clone the external repos that Forge expects under repositories/. Pinned to
# the same commits prepare_environment() resolves at runtime, so we get the
# vetted versions without having to invoke the launch-time bootstrap (which
# also does network-heavy pip installs and tries to validate CUDA).
RUN set -e \
 && mkdir -p /app/repositories \
 && git -C /app/repositories clone https://github.com/AUTOMATIC1111/stable-diffusion-webui-assets.git stable-diffusion-webui-assets \
 && git -C /app/repositories/stable-diffusion-webui-assets checkout 6f7db241d2f8ba7457bac5ca9753331f0c266917 \
 && git -C /app/repositories clone https://github.com/lllyasviel/huggingface_guess.git huggingface_guess \
 && git -C /app/repositories/huggingface_guess checkout 84826248b49bb7ca754c73293299c4d4e23a548d \
 && git -C /app/repositories clone https://github.com/salesforce/BLIP.git BLIP \
 && git -C /app/repositories/BLIP checkout 48211a1594f1321b00f14c9f7a5b4813144b2fb9

COPY docker/forge-entrypoint.sh /usr/local/bin/forge-entrypoint.sh
RUN chmod +x /usr/local/bin/forge-entrypoint.sh

EXPOSE 7860

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/forge-entrypoint.sh"]
CMD ["python", "launch.py", \
     "--listen", "--port", "7860", \
     "--api", \
     "--skip-torch-cuda-test", \
     "--skip-prepare-environment", \
     "--xformers", \
     "--cuda-malloc", \
     "--pin-shared-memory"]
