---
phase: 08-foundation-fixes-budget-promotion
plan: 01
subsystem: testing
tags: [numpy, metrics, nan, gini, enp, backtesting]

# Dependency graph
requires: []
provides:
  - NaN-for-degenerate-inputs convention documented in metrics.py module docstring
  - _gini() returns np.nan for zero-sum and empty arrays
  - _enp() returns np.nan for zero-weight arrays
  - Three NaN regression tests: test_gini_zero_sum_returns_nan, test_gini_empty_array_returns_nan, test_enp_zero_weight_returns_nan
affects: [phase-10-sweep-heatmaps, phase-11-extended-analysis]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "NaN-for-degenerate-inputs: metric helpers return np.nan (not 0.0) for zero-sum or zero-weight arrays"
    - "Phase 11 extended analysis must follow the NaN convention — downstream aggregation uses np.nanmean etc."

key-files:
  created: []
  modified:
    - apps/simulations/src/backtesting/metrics.py
    - apps/simulations/tests/test_metrics.py

key-decisions:
  - "NaN-for-degenerate-inputs convention: return float(np.nan), not 0.0, to avoid silently corrupting sweep heatmaps with invalid 'perfect equality' readings"
  - "test_enp NaN guard added for safety even though non-degenerate fixture never produces NaN"

patterns-established:
  - "NaN-for-degenerate-inputs: zero-participation = np.nan, not 0.0 (zero participation is degenerate, not perfect equality)"

requirements-completed: [BUDG-02, BUDG-03]

# Metrics
duration: 1min
completed: 2026-02-28
---

# Phase 8 Plan 01: Fix _gini() and _enp() NaN Returns Summary

**_gini() and _enp() now return np.nan for degenerate (zero-sum/zero-weight) inputs, preventing silent corruption of sweep heatmaps with invalid 'perfect equality' readings**

## Performance

- **Duration:** ~1 min
- **Started:** 2026-02-28T16:39:06Z
- **Completed:** 2026-02-28T16:40:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Fixed _gini() to return float(np.nan) for zero-sum and empty arrays instead of 0.0
- Fixed _enp() to return float(np.nan) for zero-weight arrays instead of 0.0
- Documented NaN-for-degenerate-inputs convention in module docstring
- Added 3 NaN regression tests (BUDG-02, BUDG-03) to prevent regression
- Updated test_enp ENP assertions with NaN guard for forward compatibility

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix _gini() and _enp() NaN returns** - `cec4d44` (fix)
2. **Task 2: Add NaN regression tests and update existing test_enp assertion** - `55d5f7c` (test)

## Files Created/Modified
- `apps/simulations/src/backtesting/metrics.py` - Updated _gini and _enp to return np.nan for degenerate inputs; added NaN convention to module docstring and function docstrings
- `apps/simulations/tests/test_metrics.py` - Added 3 NaN regression tests; updated test_enp ENP >= 1.0 assertions with math.isnan guard

## Decisions Made
- Returning float(np.nan) ensures downstream aggregation (np.nanmean) silently skips degenerate proposals rather than corrupting sweep heatmap averages with invalid 0.0 values
- Updated test_enp assertions to allow NaN even though the non-degenerate fixture never produces NaN — guards against future fixture changes

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- _gini and _enp now follow the NaN-for-degenerate-inputs convention
- All 14 test_metrics.py tests pass
- Phase 10 sweep heatmaps can safely use np.nanmean over ENP/Gini outputs without risk of 0.0 corrupting averages

---
*Phase: 08-foundation-fixes-budget-promotion*
*Completed: 2026-02-28*
