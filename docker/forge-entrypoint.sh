#!/usr/bin/env bash
set -euo pipefail

# Make sure bind-mounted state files exist as files (not auto-created dirs).
for f in config.json ui-config.json styles.csv; do
  if [ ! -e "/app/$f" ]; then
    echo "{}" > "/app/$f.tmp" 2>/dev/null || true
    mv "/app/$f.tmp" "/app/$f" 2>/dev/null || true
  fi
done

mkdir -p /app/outputs /app/embeddings /app/extensions /app/cache/huggingface

exec "$@"
