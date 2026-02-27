---
phase: 06-plots
plan: 01
subsystem: visualization
tags: [matplotlib, numpy, pandas, backtesting, plots, publication-grade]

# Dependency graph
requires:
  - phase: 05-metrics
    provides: FlipRateResult, GiniResult, ENPResult, MarginShiftResult, TransitionMatrix, LateVoteShareResult, LockinTimingResult, TopKConcentrationResult dataclasses
  - phase: 04-cadcad-integration
    provides: results_df with event_type, legacy_for, signals_for, weight, lock_duration_days columns
provides:
  - 11 matplotlib Figure-returning plot functions covering all Phase 5 metrics
  - Module-level rcParams: serif font, y-axis horizontal grid, 300 DPI, white background
  - BLUE/ORANGE color constants locked to Legacy/Signals regimes
  - OO-API-only matplotlib module with no pyplot state
affects: [07-pipeline, reporting, analysis]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "matplotlib OO API: Figure() + add_subplot() + ax.method() — never plt.*"
    - "matplotlib.use('Agg') as first line before any Figure import"
    - "rcParams.update() at module import for shared publication styling"
    - "compute_signals_weight imported as _cw inside function body to avoid circular import"
    - "twinx() for dual-axis histogram + weight overlay (PLOT-11)"

key-files:
  created:
    - apps/simulations/src/backtesting/plots.py
  modified: []

key-decisions:
  - "compute_signals_weight imported inside plot_lorenz_curve and plot_lock_duration_histogram as _cw to avoid module-level circular dependency"
  - "Dynamic figsize for per-proposal charts: max(8, n * 0.5 + 2) width for PLOT-08; max(4, n * 0.4 + 1) height for PLOT-02"
  - "NaN guard via np.nan_to_num for LateVoteShareResult — NaN is valid (no lock-in) but bars need numeric values"
  - "Flip detection in PLOT-10: first vote index where sign(legacy_margin) != sign(signals_margin), marked with red dotted vertical line"
  - "last bin inclusive edge in PLOT-11 histogram to capture right-edge votes"

patterns-established:
  - "OO matplotlib: every function uses Figure(figsize=...) + fig.add_subplot(1,1,1)"
  - "Color discipline: BLUE for Legacy, ORANGE for Signals in every dual-regime chart"
  - "Self-contained figures: each function sets title, x-label, y-label, and legend"

requirements-completed: [PLOT-01, PLOT-02, PLOT-03, PLOT-04, PLOT-05, PLOT-06, PLOT-07, PLOT-08, PLOT-09, PLOT-10, PLOT-11, PLOT-12]

# Metrics
duration: 2min
completed: 2026-02-27
---

# Phase 06 Plan 01: Plots Summary

**11 publication-grade matplotlib Figure functions with module-level rcParams, OO-API-only, no pyplot state — covering flip rate, margin shift, transition matrix, Gini, top-k, ENP, cumulative vote curve, late-vote share, Lorenz curve, proposal story, and lock duration histogram.**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-02-27T17:25:48Z
- **Completed:** 2026-02-27T17:27:31Z
- **Tasks:** 1 of 1
- **Files modified:** 1

## Accomplishments

- Created `apps/simulations/src/backtesting/plots.py` with all 11 plot functions (PLOT-01 through PLOT-11) plus module-level rcParams (PLOT-12)
- Enforced strict OO matplotlib API: `matplotlib.use('Agg')` first, `Figure()` + `add_subplot()` pattern, zero `plt.*` calls
- All functions accept frozen dataclasses from Phase 5 metrics and return `matplotlib.figure.Figure` objects for caller-controlled saving

## Task Commits

Each task was committed atomically:

1. **Task 1: Module header, rcParams, and all 11 plot functions** - `565b350` (feat)

## Files Created/Modified

- `apps/simulations/src/backtesting/plots.py` - All 11 plot functions + PLOT-12 rcParams at module import

## Decisions Made

- `compute_signals_weight` imported as `_cw` inside `plot_lorenz_curve` and `plot_lock_duration_histogram` function bodies to avoid circular import at module level (metrics.py already imports it at module top)
- Dynamic figsize for dense per-proposal charts (PLOT-02, PLOT-08) using `max(base, n * scale + offset)` formula
- Flip detection in PLOT-10 scans for first vote index where `sign(legacy_margin) != sign(signals_margin)`, marked with red dotted vertical line at `ls=':'`

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

- Commit hook rejected lowercase subject ("implement") — fixed to sentence-case ("Implement") per commitlint rule. Warning only on footer blank line (non-blocking).

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `backtesting.plots` importable cleanly with no pyplot state
- All 11 Figure-returning functions ready for Phase 7 pipeline to call and save as PDF/PNG
- Phase 06 Plan 02 (test_plots.py) can now import and exercise all 11 functions against the metrics fixture

---
*Phase: 06-plots*
*Completed: 2026-02-27*
