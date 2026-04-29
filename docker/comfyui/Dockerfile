FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    TORCH_INDEX_URL=https://download.pytorch.org/whl/cu121 \
    HF_HOME=/data/x/models/.cache/huggingface

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

# Clone ComfyUI. Tracking master because the project is active and stable;
# rebuild the image to pick up updates.
#
# GITHUB_PROXY is an optional build-time prefix (e.g. https://ghproxy.com/)
# for users behind a slow / blocked GitHub. Combined with --depth 1 and a
# retry loop, this turns a flaky 150MB clone into a 30MB one with three
# attempts before giving up.
ARG GITHUB_PROXY=
RUN for attempt in 1 2 3; do \
      echo ">>> clone attempt $attempt"; \
      rm -rf /comfyui && \
      git clone --depth 1 "${GITHUB_PROXY}https://github.com/comfyanonymous/ComfyUI.git" /comfyui && break; \
      sleep 10; \
    done && [ -d /comfyui/.git ]

WORKDIR /comfyui

RUN python -m pip install torch==2.3.1 torchvision==0.18.1 --extra-index-url ${TORCH_INDEX_URL} \
 && python -m pip install -r requirements.txt \
 && python -m pip install xformers==0.0.27

COPY extra_model_paths.yaml /comfyui/extra_model_paths.yaml
COPY comfyui-entrypoint.sh /usr/local/bin/comfyui-entrypoint.sh
RUN chmod +x /usr/local/bin/comfyui-entrypoint.sh

EXPOSE 8188

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/comfyui-entrypoint.sh"]
CMD ["python", "main.py", "--listen", "0.0.0.0", "--port", "8188"]
