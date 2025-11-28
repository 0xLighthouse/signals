#!/usr/bin/env bash
# Thin wrapper around Tectonic to build LaTeX docs with sensible defaults.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

CACHE_DIR="${TECTONIC_CACHE_DIR:-.cache/tectonic}"
OUT_DIR="${OUT_DIR:-published}"
MAIN="${LATEX_MAIN:-main.tex}"
OUTPUT_NAME=""

usage() {
  cat <<'EOF'
Usage: build.sh [--main FILE] [--out DIR] [--cache DIR] [--output FILE]
Defaults: --main main.tex --out published --cache .cache/tectonic
By default the output PDF name is derived from the main file (e.g. main.pdf); override with --output.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --main)
      MAIN="$2"; shift 2 ;;
    --out)
      OUT_DIR="$2"; shift 2 ;;
    --cache)
      CACHE_DIR="$2"; shift 2 ;;
    --output)
      OUTPUT_NAME="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage; exit 1 ;;
  esac
done

mkdir -p "$ROOT_DIR/$CACHE_DIR" "$ROOT_DIR/$OUT_DIR"

cd "$ROOT_DIR"
TECTONIC_CACHE_DIR="$ROOT_DIR/$CACHE_DIR" tectonic -X compile --outdir "$ROOT_DIR/$OUT_DIR" "$MAIN"

DEFAULT_OUTPUT="$(basename "${MAIN%.*}").pdf"
TARGET_NAME="${OUTPUT_NAME:-$DEFAULT_OUTPUT}"

if [[ "$TARGET_NAME" != "$DEFAULT_OUTPUT" ]]; then
  TARGET_DIR="$(dirname "$ROOT_DIR/$OUT_DIR/$TARGET_NAME")"
  mkdir -p "$TARGET_DIR"
  mv "$ROOT_DIR/$OUT_DIR/$DEFAULT_OUTPUT" "$ROOT_DIR/$OUT_DIR/$TARGET_NAME"
fi
