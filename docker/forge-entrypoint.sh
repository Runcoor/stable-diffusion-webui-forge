#!/usr/bin/env bash
set -euo pipefail

# State dir is bind-mounted at /app/forge-state. Make sure each file Forge
# expects exists with valid initial content — a fresh host dir starts empty,
# and Forge crashes both on missing files and on empty/invalid JSON files.
mkdir -p /app/forge-state

# JSON files: must contain at least "{}" or json.load() blows up.
for f in config.json ui-config.json; do
  path="/app/forge-state/$f"
  if [ -d "$path" ]; then
    rmdir "$path" 2>/dev/null || true
  fi
  if [ ! -s "$path" ]; then
    echo '{}' > "$path"
  fi
done

# CSV file: empty is fine, just needs to exist as a file.
csv="/app/forge-state/styles.csv"
if [ -d "$csv" ]; then
  rmdir "$csv" 2>/dev/null || true
fi
[ -e "$csv" ] || : > "$csv"

# Forge writes a tmp copy when it auto-recovers from a corrupt config; the
# directory must exist or it explodes on the recovery path itself.
mkdir -p /app/tmp /app/outputs /app/embeddings /app/extensions /app/cache/huggingface

exec "$@"
