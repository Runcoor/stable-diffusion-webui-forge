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

RUN python -c "import sys; sys.argv = ['launch.py', '--skip-torch-cuda-test', '--skip-google-blockly']; \
from modules import launch_utils; launch_utils.prepare_environment()" || true

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
