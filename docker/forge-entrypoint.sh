#!/usr/bin/env bash
set -euo pipefail

# State dir is bind-mounted at /app/forge-state. Ensure the file Forge expects
# inside it actually exist as files (a fresh host dir starts empty, and Forge
# crashes on the first read attempt otherwise).
mkdir -p /app/forge-state
for f in config.json ui-config.json styles.csv; do
  if [ -d "/app/forge-state/$f" ]; then
    rmdir "/app/forge-state/$f" 2>/dev/null || true
  fi
  if [ ! -e "/app/forge-state/$f" ]; then
    : > "/app/forge-state/$f"
  fi
done

mkdir -p /app/outputs /app/embeddings /app/extensions /app/cache/huggingface

exec "$@"
