---
phase: 08-foundation-fixes-budget-promotion
plan: "03"
subsystem: simulations
tags: [python, backtesting, curve_type, cadcad, metrics, pipeline, sweep]

# Dependency graph
requires:
  - 08-01 (metrics.py NaN convention)
  - 08-02 (budget.py leaf module)
provides:
  - curve_type flows from generate_scenario() -> cadCAD M dict -> suf_tallies -> compute_signals_weight
  - curve_type flows through all 6 metrics functions via _add_signals_weight_column
  - pipeline.py extracts and threads curve_type end-to-end
  - generate_scenario() validates curve_type at boundary (rejects exp and invalid values)
  - ScenarioCurveType = Literal['sqrt', 'log', 'linear'] defined in factory.py
affects:
  - 09-monte-carlo-sweep
  - 10-sweep-engine (critical: sweep cells can now vary curve_type without metrics corruption)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "curve_type threading: validate-at-boundary pattern — generate_scenario() is the validation gate, all downstream code trusts the value"
    - "cadCAD M dict as parameter carrier: curve_type passed through M dict into SUF params"
    - "np.vectorize scalar broadcast: curve_type str passes as third positional arg to vectorized _compute_signals_weight"

key-files:
  created: []
  modified:
    - apps/simulations/src/backtesting/data/factory.py
    - apps/simulations/src/backtesting/simulation/runner.py
    - apps/simulations/src/backtesting/simulation/sufs.py
    - apps/simulations/src/backtesting/metrics.py
    - apps/simulations/src/backtesting/pipeline.py
    - apps/simulations/tests/test_factory.py

key-decisions:
  - "Validate curve_type at generate_scenario() boundary only — downstream (runner, metrics, pipeline) trusts the value and uses defaults"
  - "ScenarioCurveType excludes 'exp' even though weighting/signals.py supports it — Phase 8 CONTEXT.md restriction"
  - "curve_type passed through cadCAD M dict (not initial_state) — M dict is the correct parameter carrier in cadCAD"
  - "np.vectorize scalar broadcast: pass curve_type as third positional arg to vectorized _compute_signals_weight — broadcasts correctly"

patterns-established:
  - "All sweep-variable parameters must thread through the full generate_scenario -> run_backtest -> metric pipeline to prevent silent metric corruption"

requirements-completed: [BUDG-04, BUDG-06]

# Metrics
duration: ~4 min
completed: 2026-02-28
---

# Phase 8 Plan 03: curve_type Threading Summary

**curve_type flows as a first-class parameter from generate_scenario() through cadCAD M dict to suf_tallies to compute_signals_weight, and independently through all 6 metrics functions via _add_signals_weight_column — preventing silent metric corruption in Phase 10 sweep cells**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-02-28T00:23:26Z
- **Completed:** 2026-02-28T00:27:45Z
- **Tasks:** 3
- **Files modified:** 6

## Accomplishments

- Added `ScenarioCurveType = Literal['sqrt', 'log', 'linear']` and `_VALID_CURVE_TYPES` to factory.py; `generate_scenario()` now accepts `curve_type` with validation rejecting 'exp' and invalid types
- `run_backtest()` gains `curve_type: str = 'sqrt'` param; passes it into cadCAD `M` dict as `'curve_type'`
- `suf_tallies` reads `curve_type` from `params.get('curve_type', 'sqrt')` and passes to `compute_signals_weight`
- `_add_signals_weight_column` gains `curve_type` param; uses `np.vectorize` scalar broadcast to pass it to `_compute_signals_weight`
- All 6 metric functions gain `curve_type` param: `compute_gini`, `compute_enp`, `compute_nakamoto_coefficient`, `compute_late_vote_share`, `compute_lockin_timing`, `compute_top_k_concentration`
- `pipeline.py` adds `'curve_type'` to `_GENERATE_SCENARIO_KEYS`, extracts it from data config, passes to `run_backtest` and all 6 metric functions
- Added 2 regression tests: curve_type validation (exp/invalid rejected) and functional impact (sqrt vs log produces different signals tallies)
- 152 tests pass (150 existing + 2 new)

## Task Commits

Each task was committed atomically:

1. **Task 1: Thread curve_type through generate_scenario, runner, and SUFs** - `b4ddf0f` (feat)
2. **Task 2: Thread curve_type through metrics layer and pipeline** - `c5df116` (feat)
3. **Task 3: Full test suite pass and curve_type regression test** - `e39bfa1` (test)

## Files Created/Modified

- `apps/simulations/src/backtesting/data/factory.py` — Added ScenarioCurveType, _VALID_CURVE_TYPES, curve_type param to generate_scenario() with validation
- `apps/simulations/src/backtesting/simulation/runner.py` — Added curve_type param to run_backtest(); added to cadCAD M dict
- `apps/simulations/src/backtesting/simulation/sufs.py` — suf_tallies reads curve_type from params, passes to compute_signals_weight
- `apps/simulations/src/backtesting/metrics.py` — _add_signals_weight_column + 6 metric functions gain curve_type param
- `apps/simulations/src/backtesting/pipeline.py` — 'curve_type' added to _GENERATE_SCENARIO_KEYS; extracted from config, threaded to run_backtest and all metrics
- `apps/simulations/tests/test_factory.py` — 2 new curve_type tests: validation and functional impact

## Decisions Made

- Validation at `generate_scenario()` boundary only — acts as the single gate so downstream code doesn't need to re-validate
- `ScenarioCurveType` excludes 'exp' per Phase 8 CONTEXT.md restriction even though `weighting/signals.py` supports it
- `curve_type` travels through cadCAD `M` dict — the correct parameter carrier; `initial_state` would be shared/mutated across timesteps
- `np.vectorize` with scalar `curve_type` broadcasts correctly as third positional arg to `_compute_signals_weight`

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 9 (MC sweep) can call `generate_scenario(..., curve_type=curve_type)` and `run_backtest(events, curve_type=curve_type)` and all metrics will use the correct curve
- Phase 10 (sweep engine) can vary curve_type across sweep cells without risk of metrics layer silently using a different curve
- All 152 tests pass — no regressions

## Self-Check: PASSED

- FOUND: apps/simulations/src/backtesting/data/factory.py
- FOUND: apps/simulations/src/backtesting/simulation/runner.py
- FOUND: apps/simulations/src/backtesting/simulation/sufs.py
- FOUND: apps/simulations/src/backtesting/metrics.py
- FOUND: apps/simulations/src/backtesting/pipeline.py
- FOUND: apps/simulations/tests/test_factory.py
- FOUND: .planning/phases/08-foundation-fixes-budget-promotion/08-03-SUMMARY.md
- FOUND: commit b4ddf0f (feat: Task 1)
- FOUND: commit c5df116 (feat: Task 2)
- FOUND: commit e39bfa1 (test: Task 3)

---
*Phase: 08-foundation-fixes-budget-promotion*
*Completed: 2026-02-28*
