---
phase: 10-sweep-runner
plan: 02
subsystem: simulation
tags: [python, concurrent-futures, tqdm, ProcessPoolExecutor, memory-management, sweep, backtesting, metrics]

requires:
  - phase: 10-sweep-runner plan 01
    provides: SweepConfig, SweepCell, SweepResult dataclasses, _enumerate_cells, _make_output_dir, _make_failed_row helpers
  - phase: 09-monte-carlo-allocation-modeling
    provides: generate_scenario() factory, run_backtest(), build_results_dataframe()
  - phase: 08-foundation-fixes-budget-promotion
    provides: compute_flip_rate, compute_gini, compute_participation_rate, compute_margin_shift, compute_enp, compute_nakamoto_coefficient

provides:
  - _run_cell(): module-level function mapping SweepCell params to generate_scenario->run_backtest->metrics pipeline
  - run_sweep(): orchestrator with ProcessPoolExecutor parallelism, tqdm progress, skip-and-continue error handling, auto-export
  - SWEP-03/04/06 integration and static tests in test_sweep.py
  - tqdm>=4.60.0,<5 declared in pyproject.toml

affects:
  - phase-11-extended-analysis: consumes SweepResult.summary_df with full metric columns for extended analysis

tech-stack:
  added: [tqdm>=4.60.0 (declared explicit dependency)]
  patterns:
    - Module-level _run_cell() for ProcessPoolExecutor picklability — never nest worker functions
    - Deferred imports inside worker function to avoid circular imports across process boundaries
    - as_completed() pattern for tqdm progress: one pbar.update(1) per completed future
    - del raw, events, results_df + gc.collect() after metric computation for bounded memory (SWEP-04)
    - fail_fast: ex.shutdown(wait=False, cancel_futures=True) before re-raise for clean executor teardown

key-files:
  created: []
  modified:
    - apps/simulations/src/backtesting/sweep.py
    - apps/simulations/tests/test_sweep.py
    - apps/simulations/pyproject.toml

key-decisions:
  - "Module-level _run_cell() is required (not nested) for ProcessPoolExecutor picklability — pickle can only serialize top-level functions"
  - "Deferred imports inside _run_cell() avoid circular import issues when function executes in worker processes"
  - "_make_failed_row extended with enp_legacy_mean/enp_signals_mean/nakamoto_legacy_mean/nakamoto_signals_mean columns to match successful row schema"
  - "Static source inspection (inspect.getsource) used for SWEP-04/06 tests — dynamic memory/progress profiling is fragile in CI"

patterns-established:
  - "_run_cell parameters: cell.lock_profile['long'] -> l_max_days, cell.alpha -> pareto_alpha, cell.curve_type -> curve_type"
  - "base_cfg passthrough: kwargs.setdefault('lock_profile', 'independent') prevents passing dict as lock_profile to generate_scenario"
  - "Integration tests use n_voters=20, n_proposals=3 for speed while still running actual simulations"

requirements-completed: [SWEP-03, SWEP-04, SWEP-06]

duration: 3min
completed: 2026-02-28
---

# Phase 10 Plan 02: Sweep Runner Execution Engine Summary

**ProcessPoolExecutor sweep engine with tqdm progress, per-cell memory management, skip-and-continue error handling, and auto-export of summary.csv/config.json**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-02-28T12:32:48Z
- **Completed:** 2026-02-28T12:35:23Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Implemented module-level `_run_cell()` that maps SweepCell parameters to the full generate_scenario -> run_backtest -> metrics pipeline with bounded memory management
- Implemented `run_sweep()` orchestrator using ProcessPoolExecutor + as_completed + tqdm, producing SweepResult with 12 rows for 2x3x1x2 cartesian grid
- Added SWEP-03/04/06 tests covering integration (single cell and 12-cell sweep), static memory management verification, and tqdm usage verification

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement _run_cell() and run_sweep() with parallelism, progress, and memory management** - `ba9b621` (feat)
2. **Task 2: Add SWEP-03, SWEP-04, SWEP-06 tests and tqdm dependency** - `3e8b2a8` (feat)

## Files Created/Modified

- `apps/simulations/src/backtesting/sweep.py` - Added _run_cell() (module-level), run_sweep() orchestrator, numpy import, run_sweep to __all__, extended _make_failed_row with ENP/Nakamoto columns
- `apps/simulations/tests/test_sweep.py` - Added test_swep03_parallel_execution, test_swep03_multi_cell_sweep, test_swep04_memory_release, test_swep06_tqdm_progress; updated imports to include _run_cell and run_sweep
- `apps/simulations/pyproject.toml` - Added tqdm>=4.60.0,<5 to project dependencies

## Decisions Made

- **Module-level _run_cell():** Must be top-level (not nested) because pickle (used by ProcessPoolExecutor) cannot serialize closures or nested functions
- **Deferred imports:** All backtesting.* imports inside _run_cell() body to avoid circular import issues when Python spawns worker processes
- **Extended _make_failed_row:** Added enp_legacy_mean, enp_signals_mean, nakamoto_legacy_mean, nakamoto_signals_mean columns to ensure consistent schema between success/failure rows
- **Static test strategy:** inspect.getsource() used for SWEP-04/06 — dynamic memory profiling unreliable in CI environments

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Extended _make_failed_row with ENP and Nakamoto columns**
- **Found during:** Task 1 (implementing _run_cell return dict)
- **Issue:** Original _make_failed_row only had flip_rate, gini_legacy, gini_signals, participation_rate, margin_shift_mean/std. The _run_cell return dict added enp_legacy_mean, enp_signals_mean, nakamoto_legacy_mean, nakamoto_signals_mean. Schema mismatch would corrupt summary_df when mixing success/failure rows.
- **Fix:** Added the four ENP/Nakamoto NaN columns to _make_failed_row to match the successful row schema
- **Files modified:** apps/simulations/src/backtesting/sweep.py
- **Verification:** All 169 tests pass including the multi-cell sweep test
- **Committed in:** ba9b621 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 missing critical)
**Impact on plan:** Required for correct DataFrame construction when mixing successful and failed cells. No scope creep.

## Issues Encountered

- `uv run pytest` failed with "Readme file does not exist: README.md" build error (pre-existing). Used `uv run --no-project pytest` instead (same pattern as prior phases).

## Next Phase Readiness

- `run_sweep()` is complete and tested — Phase 10 plan 02 is the last plan in phase 10
- Phase 11 extended analysis can consume SweepResult.summary_df with all metric columns (flip_rate, gini_legacy, gini_signals, participation_rate, margin_shift_mean/std, enp_legacy_mean/signals_mean, nakamoto_legacy_mean/signals_mean)
- All 169 tests pass (no regressions)

---
## Self-Check: PASSED

- apps/simulations/src/backtesting/sweep.py: FOUND
- apps/simulations/tests/test_sweep.py: FOUND
- .planning/phases/10-sweep-runner/10-02-SUMMARY.md: FOUND
- Commit ba9b621: FOUND
- Commit 3e8b2a8: FOUND

*Phase: 10-sweep-runner*
*Completed: 2026-02-28*
