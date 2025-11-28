# Signals Research Docs

Thin LaTeX scaffold using Tectonic with two entry points:

- `main.tex`: richer draft (abstract + sections).
- `onepager.tex`: short overview/handout.

## Usage

```bash
pnpm run --filter signals-research setup   # install tectonic
pnpm run --filter signals-research build   # builds main.tex
pnpm run --filter signals-research build:onepager
pnpm run --filter signals-research watch   # live rebuild main.tex on change
pnpm run --filter signals-research watch:onepager
pnpm run --filter signals-research clean   # remove build artefacts
```

Notes:

- macOS: the setup script installs Tectonic via Homebrew. If you install TinyTeX or other TeX distributions later, ensure their bin dirs (e.g., `/Library/TeX/texbin`) are on PATH if you need additional tools.

Outputs land in `apps/research/published` by default; override with `OUT_DIR=...` when running build/watch.

Manual usage:

```bash
./scripts/build.sh --main main.tex        # defaults: cache .cache/tectonic, out published
./scripts/build.sh --main onepager.tex --out published --cache .cache/tectonic
```

## Layout

- `main.tex`, `onepager.tex`: entry points.
- `tex/preamble.tex`: shared packages/macros.
- `tex/sections/`: content broken into smaller files.
- `figures/`: drop figures here and reference with `\includegraphics`.
- `references.bib`: shared bibliography.
