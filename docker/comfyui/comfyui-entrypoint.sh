#!/usr/bin/env bash
set -euo pipefail

# ComfyUI-Manager is baked into the image at /opt/comfyui-manager-baked.
# /comfyui/custom_nodes is bind-mounted from the host (so user-installed
# nodes survive recreates), which means it starts empty on first run and
# we have to seed Manager into it.
manager_dir=/comfyui/custom_nodes/ComfyUI-Manager
if [ ! -d "$manager_dir" ] && [ -d /opt/comfyui-manager-baked ]; then
  echo ">>> seeding ComfyUI-Manager from image"
  cp -a /opt/comfyui-manager-baked "$manager_dir"
fi

mkdir -p /comfyui/output /comfyui/user /comfyui/input /comfyui/temp

exec "$@"
