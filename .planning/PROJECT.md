# Signals

## What This Is

A monorepo containing TypeScript/Solidity applications and a Python simulations sub-project (`apps/simulations`). The simulations use cadCAD for agent-based modeling with pandas, numpy, matplotlib, and seaborn for data analysis and visualization.

## Core Value

Reliable simulations infrastructure — dependencies install cleanly, tests pass, and simulations run reproducibly.

## Requirements

### Validated

- ✓ pyproject.toml uses PEP 621 format with hatchling backend — v1.0
- ✓ uv.lock replaces poetry.lock with 36-package resolution — v1.0
- ✓ Dev deps (ruff, pytest, pytest-cov) separated from runtime deps — v1.0
- ✓ `uv sync --dev` installs all packages successfully — v1.0

### Active

(None — start next milestone to define new requirements)

### Out of Scope

- Dependency version upgrades — migration-only scope in v1.0
- CI/CD pipeline updates — handle separately if needed
- Monorepo structure changes — only Python sub-project affected

## Context

Shipped v1.0 (Poetry to uv migration) on 2026-02-27.
Tech stack: Python 3.12, uv, hatchling, cadCAD, pandas, numpy, matplotlib, seaborn.
The project uses a `src/` layout with separate subdirectories (cadcad, supply, visualization, statistical_analysis) rather than a single package.
Note: Phase 2 verification was skipped — tests/simulations/ruff should be manually verified.

## Constraints

- **Python version**: >=3.12
- **Build backend**: hatchling with src layout packages config
- **Scope**: `apps/simulations` only within the monorepo

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Use hatchling as build backend | Modern default, minimal config, uv preferred | ✓ Good |
| Separate dev dependencies | ruff, pytest, pytest-cov belong in dev deps, not runtime | ✓ Good |
| Keep current dep versions | Migration-only scope, minimize risk | ✓ Good |
| hatchling build targets for src/ layout | Project uses subdirectories, not a single package | ✓ Good |
| Install uv + Python 3.12 via uv bootstrap | Host had only Python 3.10, no uv | ✓ Good |

---
*Last updated: 2026-02-27 after v1.0 milestone*
