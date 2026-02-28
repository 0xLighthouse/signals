# Signals

## What This Is

A monorepo containing TypeScript/Solidity applications and a Python simulations sub-project (`apps/simulations`). The simulations validate Signals' commitment-weighted governance mechanism (voting power = stake × lock-duration curve) using synthetic Governor-style data, producing publication-grade analysis with parameter sweep capabilities and a single CLI command.

## Core Value

Produce credible, quantitative evidence that commitment-weighted voting improves governance outcomes — publishable results that DAOs can act on.

## Requirements

### Validated

- ✓ pyproject.toml uses PEP 621 format with hatchling backend — v1.0
- ✓ uv.lock replaces poetry.lock with 36-package resolution — v1.0
- ✓ Dev deps (ruff, pytest, pytest-cov) separated from runtime deps — v1.0
- ✓ `uv sync --dev` installs all packages successfully — v1.0
- ✓ Governor-compatible event schema (PROPOSAL_CREATED, VOTE_CAST, PROPOSAL_FINALIZED) with Pydantic v2 validation — v2.0
- ✓ Synthetic data factory with configurable profiles, Pareto stakes (Gini >= 0.65), tri-modal timing — v2.0
- ✓ Signals weight W = stake × f(lock_duration) as pure function with 4 curve types — v2.0
- ✓ cadCAD dual-tally simulation (legacy + Signals) in single pass with immutable state — v2.0
- ✓ 10 governance metrics as pure functions on results DataFrame — v2.0
- ✓ 11 publication-grade matplotlib plots using OO API exclusively — v2.0
- ✓ Pipeline orchestrator: CLI + programmatic API, TOML config, configurable output — v2.0
- ✓ Budget/lock constraint system as public testable module with AllocationDistribution hierarchy — v3.0
- ✓ NaN-for-degenerate-inputs convention across all metric functions (_gini, _enp, _nakamoto) — v3.0
- ✓ curve_type threaded as first-class parameter through full pipeline — v3.0
- ✓ Monte Carlo allocation modeling with Beta/truncnorm/uniform distribution draws — v3.0
- ✓ Seed-safe MC sampling via SeedSequence.spawn() with independent generators — v3.0
- ✓ VoteTimingConfig for controlling vote timing distributions — v3.0
- ✓ Dedicated cartesian sweep engine with ProcessPoolExecutor parallelism and memory management — v3.0
- ✓ TOML-configurable sweep grid (curve_types, alphas, lock_profiles, vote_timings) — v3.0
- ✓ 6-function extended analysis module (margin flips, influence, timing sensitivity, archetypes, significance, bootstrap CI) — v3.0
- ✓ Report bundle: heatmaps, CSV/JSON export, detail plots, composite figure — v3.0

### Active

(No active milestone — ready for v3.1 or new direction)

### Out of Scope

- Predictive behavioral economics — not needed for validation; replay is counterfactual
- On-chain deployment or gas modeling — simulation only
- Full delegate strategy modeling — future extension; adds behavioral assumptions without ground truth
- Agent-based strategic voter modeling — explodes complexity beyond replay scope
- Real-time / streaming simulation — adds web3.py/RPC infra with zero validation benefit
- Interactive Streamlit/Dash dashboard — static publication figures are the deliverable
- Full Shapley value computation — O(2^n) infeasible at realistic voter counts; Nakamoto is sufficient
- CI/CD pipeline updates — handle separately
- Monorepo structure changes — only Python sub-project affected
- MCMC sampling — no posterior inference needed; plain MC is correct
- 3D surface plots — hard to read, no publication advantage over 2D heatmaps
- Bayesian optimization for sweep — overkill for ~200 cell grids

## Context

Shipped v1.0 (Poetry to uv migration), v2.0 (Backtesting & Simulation), and v3.0 (Sweep Engine & Extended Analysis) on 2026-02-27/28.

**Codebase state:** 5,718 LOC Python source (20+ modules), 4,147 LOC tests (12+ modules), 207+ tests passing.

**Tech stack:** Python 3.12, uv, hatchling, cadCAD, pandas, numpy, matplotlib, scipy, Pydantic v2, tqdm.

The project uses a `src/` layout within `apps/simulations`. The `backtesting` package contains: `data/` (schema, factory, loader, budget), `weighting/` (signals, legacy), `simulation/` (policies, SUFs, runner), `metrics.py`, `plots.py`, `pipeline.py`, `mc.py`, `sweep.py`, `analysis.py`, `report.py`.

**Signals weight function:** W_signals = S × f(L) where S = stake, L = lock duration, f(L) = monotonic increasing with diminishing returns after ~3 months. Four curve types: sqrt, linear, log, exp.

**Data architecture:** Governor-style event stream (PROPOSAL_CREATED, VOTE_CAST, PROPOSAL_FINALIZED). GovernorDataLoader Protocol enables synthetic-to-real data swap. Pipeline and sweep engine call `generate_scenario()` directly; real-data ingestion would require pipeline code change.

**Known tech debt:**
- `GovernorDataLoader` Protocol not exercised by pipeline (DATA-09 integration seam)
- Pre-existing `test_simulation.py` broken import (`generate_summary_stats`)
- `analysis.py` functions not wired into `report.py` (no production callers, test-only)
- `timing_sensitivity/` directory created but empty in report output
- `mc_dists` axis not loadable from TOML (programmatic API only)
- Bare `except Exception: pass` in `report.py` swallows plot errors silently

## Constraints

- **Python version**: >=3.12
- **Build backend**: hatchling with src layout packages config
- **Scope**: `apps/simulations` only within the monorepo
- **Data format**: Governor-compatible event schema — synthetic and real must be interchangeable
- **Plotting**: Publication-grade matplotlib OO API (no pyplot state)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Use hatchling as build backend | Modern default, minimal config, uv preferred | ✓ Good |
| Separate dev dependencies | ruff, pytest, pytest-cov belong in dev deps, not runtime | ✓ Good |
| hatchling build targets for src/ layout | Project uses subdirectories, not a single package | ✓ Good |
| Install uv + Python 3.12 via uv bootstrap | Host had only Python 3.10, no uv | ✓ Good |
| Fresh start for v2.0 | Old pipeline replaced; new simulation is a different domain | ✓ Good — clean codebase |
| Governor-compatible event schema | Enables seamless swap from synthetic to real DAO data | ✓ Good — Protocol tested |
| Pydantic v2 for event models | Construction-time validation catches malformed data early | ✓ Good — 6 rejection test cases |
| cadCAD with deepcopy SUFs | Immutable state prevents subtle mutation bugs | ✓ Good — id() assertions pass |
| matplotlib OO API only (no pyplot) | Avoids global state leaks in pipeline/batch execution | ✓ Good — zero pyplot imports |
| Pipeline bypasses GovernorDataLoader | Direct `generate_scenario()` call is simpler; real-data path deferred | ⚠️ Revisit when real data available |
| TOML config with deep-merge defaults | Zero-config works out of the box; overrides are surgical | ✓ Good |
| NaN-to-None sanitization before JSON | Float NaN breaks JSON spec; recursive cleaner prevents silent corruption | ✓ Good |
| NaN-for-degenerate-inputs convention | _gini/_enp/_nakamoto return np.nan for zero-sum/zero-weight; sweep uses np.nanmean | ✓ Good — prevents false metrics |
| budget.py as leaf module | No backtesting.* imports; enables clean dependency chain for MC/sweep | ✓ Good — zero circular deps |
| SeedSequence.spawn() for MC generators | Statistically independent streams without seed collision risk | ✓ Good — 50 distinct sequences verified |
| VoteTimingConfig in factory.py not budget.py | Keeps budget.py a pure leaf module | ✓ Good |
| _run_cell() module-level for picklability | ProcessPoolExecutor cannot pickle closures or nested functions | ✓ Good |
| analysis.py independent of metrics.py | Replicated _get_final_tallies inline; keeps module boundaries clean | ✓ Good |
| Median-lock counterfactual baseline | Isolates commitment signal better than raw legacy comparison | ✓ Good — but needs literature validation |
| origin='lower' for all heatmaps | Default 'upper' inverts y-axis; lower matches mathematical convention | ✓ Good |

---
*Last updated: 2026-02-28 after v3.0 milestone*
