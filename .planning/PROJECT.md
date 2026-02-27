# Signals

## What This Is

A monorepo containing TypeScript/Solidity applications and a Python simulations sub-project (`apps/simulations`). The simulations validate Signals' commitment-weighted governance mechanism (voting power = stake × lock-duration curve × decay) using synthetic Governor-style data, with architecture designed for seamless swap to real DAO data.

## Core Value

Produce credible, quantitative evidence that commitment-weighted voting improves governance outcomes — publishable results that DAOs can act on.

## Current Milestone: v2.0 Signals Backtesting & Simulation

**Goal:** Build a complete simulation + analysis pipeline: synthetic data → cadCAD replay → Signals weighting → metrics → publication-grade plots.

**Target features:**
- Synthetic Governor-compatible data generation
- Event-based cadCAD replay simulation with Signals weighting
- Legacy vs Signals tally comparison
- Full metrics suite (Gini, ENP, timing, flips, sensitivity)
- Publication-grade plotting suite
- Parameter sweep support (lock curve, decay, duration)

## Requirements

### Validated

- ✓ pyproject.toml uses PEP 621 format with hatchling backend — v1.0
- ✓ uv.lock replaces poetry.lock with 36-package resolution — v1.0
- ✓ Dev deps (ruff, pytest, pytest-cov) separated from runtime deps — v1.0
- ✓ `uv sync --dev` installs all packages successfully — v1.0

### Active

(See REQUIREMENTS.md for v2.0 scoped requirements)

### Out of Scope

- Predictive behavioral economics — not needed for validation
- On-chain deployment or gas modeling — simulation only
- Full delegate strategy modeling — future extension
- CI/CD pipeline updates — handle separately
- Monorepo structure changes — only Python sub-project affected

## Context

Shipped v1.0 (Poetry to uv migration) on 2026-02-27.
Starting v2.0 fresh — old simulation code can be replaced.
Tech stack: Python 3.12, uv, hatchling, cadCAD, pandas, numpy, matplotlib, seaborn.
The project uses a `src/` layout within `apps/simulations`.

**Signals weight function:** W_signals = S × f(L) where S = stake, L = lock duration, f(L) = monotonic increasing with diminishing returns after ~3 months.

**Data architecture:** Governor-style event stream (PROPOSAL_CREATED, VOTE_CAST, PROPOSAL_FINALIZED). Synthetic data must match real schema for zero-cost swap later.

## Constraints

- **Python version**: >=3.12
- **Build backend**: hatchling with src layout packages config
- **Scope**: `apps/simulations` only within the monorepo
- **Data format**: Governor-compatible event schema — synthetic and real must be interchangeable
- **Plotting**: Publication-grade (Matplotlib primary, Plotly/Altair optional)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Use hatchling as build backend | Modern default, minimal config, uv preferred | ✓ Good |
| Separate dev dependencies | ruff, pytest, pytest-cov belong in dev deps, not runtime | ✓ Good |
| hatchling build targets for src/ layout | Project uses subdirectories, not a single package | ✓ Good |
| Install uv + Python 3.12 via uv bootstrap | Host had only Python 3.10, no uv | ✓ Good |
| Fresh start for v2.0 | Old pipeline can be replaced; new simulation is a different domain | — Pending |
| Governor-compatible event schema | Enables seamless swap from synthetic to real DAO data | — Pending |

---
*Last updated: 2026-02-27 after v2.0 milestone start*
