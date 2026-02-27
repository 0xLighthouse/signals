---
phase: 06-plots
plan: 02
subsystem: testing
tags: [matplotlib, pytest, backtesting, plots, requirement-tracing]

# Dependency graph
requires:
  - phase: 06-plots-01
    provides: 11 matplotlib Figure-returning plot functions in backtesting/plots.py
  - phase: 05-metrics
    provides: compute_flip_rate, compute_gini, compute_enp, compute_margin_shift, compute_transition_matrix, compute_late_vote_share, compute_lockin_timing, compute_top_k_concentration
  - phase: 04-cadcad-integration
    provides: metrics_results_df, metrics_windows_df conftest fixtures
provides:
  - 12 requirement-traced pytest tests covering PLOT-01 through PLOT-12
  - Figure-return and axes-count assertions for all 11 chart types
  - OO API compliance test (PLOT-12) verifying matplotlib.pyplot absent from sys.modules
affects: [07-pipeline, reporting, analysis]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "matplotlib.use('Agg') before any Figure import in test file"
    - "PLOT-12 compliance: del sys.modules['backtesting.plots'], reimport, assert pyplot absent"
    - "Reuse conftest fixtures (metrics_results_df, metrics_windows_df) directly — no fixture duplication"

key-files:
  created:
    - apps/simulations/tests/test_plots.py
  modified: []

key-decisions:
  - "Test file sets matplotlib.use('Agg') before any Figure import to avoid backend conflicts in headless CI"
  - "PLOT-12 test deletes backtesting.plots from sys.modules, removes pyplot if present, reimports, then asserts pyplot still absent — catches any lazy import too"
  - "Title spot-checks use substring assertions (e.g. 'Flip Rate' in title) rather than exact equality for resilience to minor title changes"

patterns-established:
  - "Requirement-traced tests: each docstring cites PLOT-XX requirement ID"
  - "Three-assertion pattern: isinstance(fig, Figure) + axes count + title substring"

requirements-completed: [PLOT-01, PLOT-02, PLOT-03, PLOT-04, PLOT-05, PLOT-06, PLOT-07, PLOT-08, PLOT-09, PLOT-10, PLOT-11, PLOT-12]

# Metrics
duration: 2min
completed: 2026-02-27
---

# Phase 06 Plan 02: Plot Tests Summary

**12 requirement-traced pytest tests verifying all 11 matplotlib Figure-returning plot functions and PLOT-12 OO API compliance (no pyplot state), running in 0.47s against the 50-voter seed=42 fixture.**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-02-27T17:29:39Z
- **Completed:** 2026-02-27T17:31:30Z
- **Tasks:** 1 of 1
- **Files modified:** 1

## Accomplishments

- Created `apps/simulations/tests/test_plots.py` with 12 requirement-traced tests (PLOT-01 through PLOT-12)
- All 12 tests pass (`12 passed, 1 warning in 0.47s`) — the warning is a cadCAD `datetime.utcnow()` DeprecationWarning (non-blocking, pre-existing)
- PLOT-12 compliance test correctly verifies `matplotlib.pyplot` is not in `sys.modules` after importing `backtesting.plots`
- Reused `metrics_results_df` and `metrics_windows_df` conftest fixtures without modification

## Task Commits

Each task was committed atomically:

1. **Task 1: Write 12 requirement-traced tests for all plot functions** - `29578c2` (feat)

## Files Created/Modified

- `apps/simulations/tests/test_plots.py` - 12 requirement-traced tests for PLOT-01 through PLOT-12

## Decisions Made

- Test file sets `matplotlib.use('Agg')` before any Figure import to avoid backend conflicts in headless CI environments
- PLOT-12 compliance test removes `backtesting.plots` from `sys.modules`, clears `matplotlib.pyplot` if present, reimports, then asserts `pyplot` still absent — catches any lazy re-import as well as eager imports
- Title assertions use substring matching (`'Flip Rate' in ax.get_title()`) for resilience to minor wording changes in plot functions

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None — all 12 tests passed on first run without any fixes required.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- All 12 PLOT requirements verified by automated tests
- Phase 6 (Plots) is complete — both plan 01 (plots.py) and plan 02 (test_plots.py) done
- Phase 7 (pipeline) can import and call all 11 Figure-returning functions knowing they are tested and OO-API-compliant

---
*Phase: 06-plots*
*Completed: 2026-02-27*
