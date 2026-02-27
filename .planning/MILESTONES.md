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

