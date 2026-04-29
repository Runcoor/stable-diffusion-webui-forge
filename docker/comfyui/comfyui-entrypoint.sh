#!/usr/bin/env bash
set -euo pipefail

# ComfyUI-Manager: the de-facto-standard "install custom nodes from the UI"
# extension. Bind-mounted custom_nodes/ starts empty on the host, so we clone
# Manager into it on first start. Subsequent restarts find it already there
# and skip.
if [ ! -d /comfyui/custom_nodes/ComfyUI-Manager ]; then
  echo ">>> First run: installing ComfyUI-Manager..."
  proxy="${GITHUB_PROXY:-}"
  for attempt in 1 2 3; do
    if git clone --depth 1 "${proxy}https://github.com/ltdrdata/ComfyUI-Manager.git" \
        /comfyui/custom_nodes/ComfyUI-Manager; then
      break
    fi
    rm -rf /comfyui/custom_nodes/ComfyUI-Manager
    echo ">>> attempt $attempt failed, retrying..."
    sleep 5
  done
fi

mkdir -p /comfyui/output /comfyui/user /comfyui/input /comfyui/temp

exec "$@"
