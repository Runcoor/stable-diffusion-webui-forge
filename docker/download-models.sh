#!/usr/bin/env bash
# Download models listed in docker/models.txt into MODELS_DIR.
#
# Idempotent: existing files are skipped (use --force to re-download).
# Resumable: partial downloads continue from where they stopped.
# Verifies sha256 if a checksum is supplied in the list.
#
# Tokens (export before running):
#   HF_TOKEN        HuggingFace token, sent as Authorization: Bearer
#   CIVITAI_TOKEN   CivitAI token, appended as ?token=... query param
#
# Usage:
#   ./docker/download-models.sh
#   MODELS_DIR=/srv/models ./docker/download-models.sh --list custom.txt
#   HF_TOKEN=hf_xxx ./docker/download-models.sh --force

set -euo pipefail

MODELS_DIR="${MODELS_DIR:-/data/x/models}"
LIST_FILE="$(cd "$(dirname "$0")" && pwd)/models.txt"
FORCE=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [--list FILE] [--target DIR] [--force]
  --list FILE     Model list (default: $LIST_FILE)
  --target DIR    Models root (default: \$MODELS_DIR or /data/x/models)
  --force         Re-download files that already exist
  -h, --help      Show this message
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --list)    LIST_FILE="$2"; shift 2 ;;
    --target)  MODELS_DIR="$2"; shift 2 ;;
    --force)   FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)         echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

command -v wget >/dev/null 2>&1 || { echo "ERROR: wget is required" >&2; exit 1; }
[ -f "$LIST_FILE" ] || { echo "ERROR: list file not found: $LIST_FILE" >&2; exit 1; }

echo "Models root : $MODELS_DIR"
echo "Model list  : $LIST_FILE"
[ -n "${HF_TOKEN:-}" ]      && echo "HF_TOKEN    : (set, ${#HF_TOKEN} chars)"
[ -n "${CIVITAI_TOKEN:-}" ] && echo "CIVITAI_TOKEN: (set, ${#CIVITAI_TOKEN} chars)"
echo

total=$(grep -cvE '^\s*(#|$)' "$LIST_FILE" || true)
if [ "$total" -eq 0 ]; then
  echo "No entries enabled in $LIST_FILE — uncomment some lines and re-run."
  exit 0
fi

trim() { printf '%s' "$1" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'; }

i=0; ok=0; skipped=0; failed=0
while IFS='|' read -r raw_subdir raw_filename raw_url raw_sha256 || [ -n "${raw_subdir:-}" ]; do
  case "$(trim "${raw_subdir:-}")" in ''|\#*) continue ;; esac

  i=$((i+1))
  subdir=$(trim "$raw_subdir")
  filename=$(trim "${raw_filename:-}")
  url=$(trim "${raw_url:-}")
  sha256=$(trim "${raw_sha256:-}")

  if [ -z "$filename" ] || [ -z "$url" ]; then
    echo "[$i/$total] SKIP  malformed line (need subdir|filename|url)" >&2
    failed=$((failed+1))
    continue
  fi

  dest_dir="$MODELS_DIR/$subdir"
  dest="$dest_dir/$filename"

  printf '[%d/%d] %s/%s\n' "$i" "$total" "$subdir" "$filename"

  if [ -e "$dest" ] && [ "$FORCE" -eq 0 ]; then
    echo "       skip (already present — use --force to re-download)"
    skipped=$((skipped+1))
    continue
  fi

  mkdir -p "$dest_dir"

  fetch_url="$url"
  headers=()

  case "$url" in
    *huggingface.co*)
      if [ -n "${HF_TOKEN:-}" ]; then
        headers+=(--header="Authorization: Bearer $HF_TOKEN")
      fi
      ;;
    *civitai.com*)
      if [ -n "${CIVITAI_TOKEN:-}" ]; then
        sep='?'
        case "$url" in *\?*) sep='&' ;; esac
        fetch_url="${url}${sep}token=${CIVITAI_TOKEN}"
      fi
      ;;
  esac

  echo "       fetching $url"
  if wget -c --tries=3 --timeout=60 --progress=bar:force:noscroll \
          ${headers[@]+"${headers[@]}"} \
          -O "$dest.part" "$fetch_url"; then
    mv "$dest.part" "$dest"
    if [ -n "$sha256" ]; then
      actual=$(sha256sum "$dest" | awk '{print $1}')
      if [ "$actual" != "$sha256" ]; then
        echo "       ERROR sha256 mismatch (expected $sha256, got $actual)" >&2
        rm -f "$dest"
        failed=$((failed+1))
        continue
      fi
      echo "       OK (sha256 verified)"
    else
      echo "       OK"
    fi
    ok=$((ok+1))
  else
    echo "       ERROR download failed (HTTP error or auth required)" >&2
    rm -f "$dest.part"
    failed=$((failed+1))
  fi
done < "$LIST_FILE"

echo
echo "Summary: $ok downloaded, $skipped skipped, $failed failed (of $total)"
[ "$failed" -eq 0 ]
