# Milestones

## v1.0 Poetry to uv Migration (Shipped: 2026-02-27)

**Phases:** 1 completed (Phase 2 skipped) | **Plans:** 1 | **Tasks:** 2
**Timeline:** 2026-02-27 (single session, ~6 min execution)
**Git range:** `7bfe82e` → `4af6f08`

**Key accomplishments:**
- Rewrote pyproject.toml from Poetry to PEP 621 format with hatchling build backend
- Separated runtime deps (7) from dev deps (3) using `[dependency-groups]`
- Generated uv.lock with 36 packages, deleted poetry.lock (1253 lines removed)
- Verified `uv sync --dev` installs all packages successfully

### Known Gaps

Phase 2 (Verify) was not executed. The following requirements remain unverified:

- **VER-01**: All existing tests pass after migration
- **VER-02**: Simulations can be imported and run
- **VER-03**: Ruff linting still works with existing config

These should be manually verified before relying on the migrated environment.

---


## v2.0 Backtesting & Simulation (Shipped: 2026-02-27)

**Phases:** 5 (Phases 3-7) | **Plans:** 9 | **Tests:** 147 passing
**Source:** 2,621 LOC Python (15 modules) | **Tests:** 2,398 LOC (8 modules)
**Timeline:** 2026-02-27 (single day)
**Git range:** `7f038f6` → `f933024` (13 feat commits)

**Key accomplishments:**
- Pydantic v2 event schema with Governor-compatible types and construction-time validation
- Synthetic data factory with Pareto stakes (Gini >= 0.65), tri-modal timing, 3 profiles, seed reproducibility
- cadCAD dual-tally simulation computing legacy (stake) and Signals (commitment-weighted) tallies in a single pass
- 10 governance metrics as pure functions on DataFrame (flip rate, Gini, ENP, Nakamoto, margin shift, transition matrix, participation, late-vote share, lock-in timing, top-k)
- 11 publication-grade matplotlib plots using OO API exclusively with consistent rcParams
- Pipeline orchestrator: `run_pipeline()` + CLI composing all layers with TOML config and NaN-safe JSON export

**Audit:** Passed — 46/46 requirements, 18/18 integrations wired, 2/2 E2E flows verified

---


## v3.0 Sweep Engine & Extended Analysis (Shipped: 2026-02-28)

**Phases:** 7 (Phases 8-12 including 10.1 and 11.1) | **Plans:** 13 | **Tests:** 207+ passing
**Source:** 5,718 LOC Python (src/) | **Tests:** 4,147 LOC (tests/)
**Timeline:** 2026-02-28 (single day)
**Git range:** `24158b9` → `e0cc1a4` (26 feat/fix/test commits, 60 files changed, +11,854 lines)

**Key accomplishments:**
- Formalized budget/lock constraint system as public `budget.py` module with AllocationDistribution hierarchy (Beta/truncnorm/uniform), fixing NaN-corrupting bugs in `_gini`, `_enp`, `_nakamoto`
- Monte Carlo allocation modeling with `mc_dist` distribution draws, seed-safe via `SeedSequence.spawn()`, plus `VoteTimingConfig` for vote timing control
- Dedicated cartesian sweep engine (`sweep.py`) with `ProcessPoolExecutor` parallelism, tqdm progress, memory management, TOML config — handles curve_type × alpha × lock_profile × vote_timing × mc_dist grid
- Deep governance analysis module (`analysis.py`): margin-class flip breakdown, median-lock counterfactual address influence, 2D timing sensitivity, voter archetypes, Mann-Whitney U significance, bootstrap confidence intervals
- Report bundle (`report.py`): `generate_sweep_report()` producing annotated heatmaps (origin='lower', RdYlGn), best/worst detail plots, multi-panel composite figure, CSV/JSON export with NaN sanitization
- Zero-regression test growth: 147 → 207+ tests across all 7 phases

**Audit:** tech_debt — 33/33 requirements satisfied, 7/7 phases passed, 2 non-critical integration gaps (analysis→report wiring, mc_dists TOML loading)

---

