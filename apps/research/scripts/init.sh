#!/usr/bin/env bash
# Install a lightweight Tectonic toolchain for basic LaTeX docs (figures, footnotes).
set -euo pipefail

log() {
  printf ">>> %s\n" "$*"
}

add_tex_paths_macos() {
  export PATH="/Library/TeX/texbin:$HOME/Library/TinyTeX/bin/universal-darwin:$PATH"
}

install_linux() {
  if ! command -v apt-get >/dev/null 2>&1; then
    log "apt-get not found; install Tectonic manually for your distro: https://tectonic-typesetting.github.io"
    exit 1
  fi

  log "Installing Tectonic + latexmk via apt-get (sudo required)…"
  sudo apt-get update
  sudo apt-get install -y tectonic latexmk
}

install_macos() {
  if ! command -v brew >/dev/null 2>&1; then
    log "Homebrew is required on macOS. Install it from https://brew.sh and re-run."
    exit 1
  fi

  if ! brew list tectonic >/dev/null 2>&1; then
    log "Installing Tectonic…"
    brew install tectonic
  else
    log "Tectonic already installed."
  fi

  add_tex_paths_macos
}

main() {
  case "$(uname -s)" in
    Linux) install_linux ;;
    Darwin) install_macos ;;
    *)
      log "Unsupported OS: $(uname -s). Install Tectonic manually, then re-run."
      exit 1
      ;;
  esac

  # Ensure local cache and output dirs exist (no sudo needed).
  mkdir -p "$(dirname "${TECTONIC_CACHE_DIR:-.cache/tectonic}")" "${TECTONIC_CACHE_DIR:-.cache/tectonic}" "${OUT_DIR:-published}"

  log "Tectonic ready. Build with: ./scripts/build.sh --main main.tex"
}

main "$@"
