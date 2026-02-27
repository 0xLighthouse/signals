# Simulations: Poetry to uv Migration

## What This Is

Migration of the `apps/simulations` Python sub-project from Poetry to uv as the package manager and build system. This is a brownfield project within a larger pnpm monorepo — only the Python simulations app is affected. Includes cleanup of dependency categorization (dev vs runtime).

## Core Value

The simulations project uses uv for dependency management with a clean, modern pyproject.toml — no Poetry artifacts remain.

## Requirements

### Validated

<!-- Existing capabilities that must be preserved -->

- ✓ Python cadCAD simulations run correctly — existing
- ✓ All current dependencies resolve and install — existing
- ✓ Tests pass with pytest — existing
- ✓ Ruff linting works — existing

### Active

<!-- Current scope. Building toward these. -->

- [ ] pyproject.toml converted from Poetry format to uv/hatchling format
- [ ] poetry.lock replaced with uv.lock
- [ ] Dev dependencies (ruff, pytest, pytest-cov) separated from runtime dependencies
- [ ] Build backend changed from poetry-core to hatchling
- [ ] Python >=3.12 constraint preserved
- [ ] All existing simulations and tests work identically after migration

### Out of Scope

- Upgrading dependency versions — migration only, keep current versions
- Changing the monorepo structure or pnpm workspace config
- Adding new Python dependencies
- Modifying simulation code or tests
- CI/CD pipeline changes (handle separately if needed)

## Context

- `apps/simulations` is a Python sub-project inside a larger TypeScript/Solidity monorepo
- Current setup uses Poetry with `poetry-core` build backend
- Dependencies are flat (no dev/runtime separation): pandas, matplotlib, seaborn, numpy, fastparquet, tabulate, ruff, cadcad, pytest, pytest-cov
- Has a `poetry.lock` lockfile, `src/` directory for source, `tests/` for tests
- Ruff configured with 100-char line length in pyproject.toml

## Constraints

- **Python version**: >=3.12 — matches current Poetry constraint
- **Build backend**: hatchling — user preference for modern default
- **Scope**: Only `apps/simulations` — no changes to the rest of the monorepo
- **Behavioral parity**: All simulations and tests must work identically post-migration

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Use hatchling as build backend | Modern default, minimal config, uv's preferred backend | — Pending |
| Separate dev dependencies | ruff, pytest, pytest-cov belong in dev deps, not runtime | — Pending |
| Keep current dep versions | Migration-only scope, minimize risk | — Pending |

---
*Last updated: 2026-02-27 after initialization*
