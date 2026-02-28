---
phase: 11-extended-analysis
plan: 02
subsystem: analysis
tags: [python, pandas, numpy, scipy, backtesting, governance, dataclasses, statistics]

# Dependency graph
requires:
  - phase: 11-extended-analysis-01
    provides: analysis.py with MarginClassBreakdown, VoterArchetypes, __all__ skeleton
  - phase: 10-sweep-runner
    provides: results_df schema (14-column DataFrame from build_results_dataframe)
  - phase: 08-foundation-fixes-budget-promotion
    provides: compute_signals_weight() for counterfactual weight computation
provides:
  - backtesting/analysis.py: AddressInfluence, TimingSensitivity, SignificanceResult, BootstrapCI frozen dataclasses
  - address_influence(): ANAL-02 — per-voter influence with median-lock counterfactual baseline
  - timing_sensitivity(): ANAL-03 — 2D pivot heatmap of weight_ratio by timing x lock quantile
  - influence_significance(): ANAL-05 — Mann-Whitney U significance test on influence distributions
  - bootstrap_ci(): ANAL-06 — bootstrap confidence interval for aggregate metrics
  - Complete analysis module: 6 public functions, 6 frozen dataclasses, full __all__
affects:
  - sweep pipeline (consumes complete analysis module for all ANAL metrics)
  - reporting/visualization layer (heatmaps, significance tests, CI bars)

# Tech tracking
tech-stack:
  added:
    - scipy.stats.mannwhitneyu (Mann-Whitney U test)
    - scipy.stats.bootstrap (bootstrap CI with percentile method)
  patterns:
    - median-lock counterfactual pattern: isolates commitment signal by comparing actual vs. median lock
    - 2D pivot_table with observed=True to suppress pandas 2.x FutureWarning for categorical axes
    - NaN-guard pattern for degenerate inputs (< 2 elements) applied to statistical functions
    - np.vectorize(_compute_signals_weight) for vectorized counterfactual column computation

key-files:
  created: []
  modified:
    - apps/simulations/src/backtesting/analysis.py
    - apps/simulations/tests/test_analysis.py

key-decisions:
  - "delta = signals_share - counterfactual_share (not legacy_share) — isolates commitment signal"
  - "median-lock counterfactual holds participation constant, varies only lock duration dimension"
  - "timing_sensitivity uses observed=True in pivot_table to prevent pandas 2.x FutureWarning"
  - "influence_significance returns NaN (not 0.0 or raise) for degenerate inputs < 2 elements"

patterns-established:
  - "Counterfactual pattern: median_lock baseline lets us ask who wins from their actual commitment"
  - "Statistical functions follow NaN-for-degenerate convention matching metrics.py and analysis.py"
  - "2D pivot heatmap: pd.qcut with duplicates='drop' + observed=True for robust cross-dimensional analysis"

requirements-completed: [ANAL-02, ANAL-03, ANAL-05, ANAL-06]

# Metrics
duration: 4min
completed: 2026-02-28
---

# Phase 11 Plan 02: Extended Analysis Functions (ANAL-02/03/05/06) Summary

**Four statistical analysis functions using median-lock counterfactual (address_influence), 2D timing x lock heatmap (timing_sensitivity), Mann-Whitney U test (influence_significance), and bootstrap CI (bootstrap_ci) completing the full analysis.py module**

## Performance

- **Duration:** 4 min
- **Started:** 2026-02-28T13:59:13Z
- **Completed:** 2026-02-28T14:03:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Implemented `address_influence()` (ANAL-02): per-voter influence shares with median-lock counterfactual baseline; delta = signals_share - counterfactual_share correctly isolates commitment signal
- Implemented `timing_sensitivity()` (ANAL-03): 2D pivot table heatmap (timing quantile x lock quantile) of weight_ratio; returns proper DataFrame with `observed=True` to suppress FutureWarning
- Implemented `influence_significance()` (ANAL-05): Mann-Whitney U test wrapper with NaN guard for degenerate inputs
- Implemented `bootstrap_ci()` (ANAL-06): scipy.stats.bootstrap percentile CI with NaN guard for single-element arrays
- Extended `test_analysis.py` from 6 to 15 tests; full 193-test suite green

## Task Commits

Each task was committed atomically:

1. **Task 1: Add four new analysis functions to analysis.py** - `c525dee` (feat)
2. **Task 2: Add ANAL-02/03/05/06 tests to test_analysis.py** - `4daeda2` (test)

**Plan metadata:** (docs commit follows)

## Files Created/Modified
- `apps/simulations/src/backtesting/analysis.py` - Extended with AddressInfluence, TimingSensitivity, SignificanceResult, BootstrapCI dataclasses and address_influence(), timing_sensitivity(), influence_significance(), bootstrap_ci() functions; __all__ updated to 6+6
- `apps/simulations/tests/test_analysis.py` - 9 new tests covering ANAL-02 (2 tests), ANAL-03 (2 tests), ANAL-05 (3 tests), ANAL-06 (2 tests)

## Decisions Made
- `delta = signals_share - counterfactual_share` not `signals_share - legacy_share` — the counterfactual correctly answers "who benefits from their actual lock commitment relative to the median participant?" rather than "who benefits from Signals over legacy?"
- Median-lock counterfactual holds voter participation constant (same voters, same stakes) and varies only lock duration — produces within-protocol comparison isolating the commitment dimension
- `timing_sensitivity` uses `observed=True` in `pivot_table()` to prevent pandas 2.x FutureWarning for categorical groupby
- Statistical functions (`influence_significance`, `bootstrap_ci`) return NaN for degenerate inputs rather than raising exceptions — consistent with NaN-for-degenerate convention established in metrics.py

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Complete analysis module (6 public functions, 6 frozen dataclasses) ready for consumption
- Full test suite (193 tests) green — no regressions
- Phase 11 complete: ANAL-01 through ANAL-07 all implemented and tested
- Ready for visualization/reporting layer or sweep integration that consumes analysis results

## Self-Check: PASSED

- FOUND: apps/simulations/src/backtesting/analysis.py
- FOUND: apps/simulations/tests/test_analysis.py
- FOUND: .planning/phases/11-extended-analysis/11-02-SUMMARY.md
- FOUND: commit c525dee (feat: four new analysis functions)
- FOUND: commit 4daeda2 (test: ANAL-02/03/05/06 tests)

---
*Phase: 11-extended-analysis*
*Completed: 2026-02-28*
