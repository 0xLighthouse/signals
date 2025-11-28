#!/usr/bin/env bash
# Thin wrapper around Tectonic to build LaTeX docs with sensible defaults.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

CACHE_DIR="${TECTONIC_CACHE_DIR:-.cache/tectonic}"
OUT_DIR="${OUT_DIR:-published}"
MAIN="${LATEX_MAIN:-main.tex}"

usage() {
  cat <<'EOF'
Usage: build.sh [--main FILE] [--out DIR] [--cache DIR]
Defaults: --main main.tex --out published --cache .cache/tectonic
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
