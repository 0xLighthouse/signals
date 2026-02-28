---
phase: 12-report-bundle
plan: 01
subsystem: simulations
tags: [matplotlib, pandas, numpy, heatmap, json, csv, sweep, report]

requires:
  - phase: 11.1-vote-timing-sweep-wiring
    provides: SweepResult with summary_df, failed_cells, output_dir

provides:
  - generate_sweep_report() orchestrator producing structured output bundle
  - _plot_metric_heatmap() with origin='lower' and annotated cells
  - _nan_to_none_extended() handling np.int64 / np.floating for JSON safety
  - ReportResult frozen dataclass

affects: [12-02-report-bundle]

tech-stack:
  added: []
  patterns:
    - OO matplotlib API — Figure() not pyplot, same as plots.py
    - matplotlib.use('Agg') as first matplotlib call before any Figure import
    - _nan_to_none_extended extends sweep.py pattern to cover np.integer types
    - Structured output subdirectories created in orchestrator before export

key-files:
  created:
    - apps/simulations/src/backtesting/report.py
    - apps/simulations/tests/test_report.py
  modified: []

key-decisions:
  - "_nan_to_none_extended casts np.integer to int() — np.int64 is NOT a Python int
    subclass and causes json.dumps() TypeError without this cast"
  - "origin='lower' is mandatory for heatmaps — default 'upper' flips rows visually"
  - "Text color threshold at 0.6 normalized value (white above, black below)"
  - "generate_sweep_report skips metrics that cannot be pivoted (all NaN after filter)"

patterns-established:
  - "Heatmap: imshow with origin='lower', annotate via ax.text per cell, colorbar via fig.colorbar"
  - "JSON export: _nan_to_none_extended on summary dict before json.dump"

requirements-completed: [REPT-01, REPT-02, REPT-03, REPT-04, REPT-07, REPT-08]

duration: 2min
completed: 2026-02-28
---

# Phase 12 Plan 01: Report Bundle Core Summary

**report.py with generate_sweep_report orchestrator, annotated heatmaps via OO matplotlib API,
CSV/JSON exports with np.int64-safe serialization, and structured subdirectory creation**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-28T16:12:17Z
- **Completed:** 2026-02-28T16:14:57Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- `report.py` module with `generate_sweep_report()` orchestrator creating heatmaps/, detail/,
  timing_sensitivity/ subdirectories and exporting sweep_results.csv and sweep_summary.json
- `_plot_metric_heatmap()` using OO matplotlib API (no pyplot) with `origin='lower'` and
  per-cell numeric annotations with contrasting text color
- `_nan_to_none_extended()` extending sweep.py's `_nan_to_none` to handle `np.integer` types
  (np.int64, np.int32) that cause `json.dumps()` TypeError without explicit int() cast
- 8 passing tests covering all REPT requirements: directory creation, CSV/JSON export,
  origin='lower' verification, cell annotations, NaN/np.int64 handling, return type

## Task Commits

1. **Task 1: Create report.py** - `812508a` (feat)
2. **Task 2: Add tests for report module** - `39d554c` (feat)

## Files Created/Modified

- `apps/simulations/src/backtesting/report.py` — Core report module: ReportResult dataclass,
  _METRIC_CMAPS, _nan_to_none_extended, _plot_metric_heatmap, _build_summary_dict,
  generate_sweep_report orchestrator
- `apps/simulations/tests/test_report.py` — 8 tests covering REPT-01/02/03/04/07/08

## Decisions Made

- `_nan_to_none_extended` casts `np.integer` to `int()` — `np.int64` is NOT a Python `int`
  subclass and causes `json.dumps()` to raise `TypeError` without this explicit cast
- `origin='lower'` is mandatory for heatmaps — default `'upper'` inverts the row axis visually,
  making the first category appear at the top rather than the bottom
- Text color threshold at normalized value 0.6 (white above, black below) for readable annotations
- `generate_sweep_report` skips metrics that cannot be pivoted due to all-NaN after failed-cell
  filtering, rather than raising an error

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## Next Phase Readiness

- `report.py` module ready for Plan 02 to add composite figures and detail plots (REPT-05, REPT-06)
- `detail/` and `timing_sensitivity/` directories are created but empty — Plan 02 populates them
- `generate_sweep_report` accepts `best_n`, `worst_n`, `ranking_metric` kwargs that Plan 02 will use

---
*Phase: 12-report-bundle*
*Completed: 2026-02-28*

## Self-Check: PASSED

- report.py: FOUND
- test_report.py: FOUND
- 12-01-SUMMARY.md: FOUND
- Commit 812508a (Task 1): FOUND
- Commit 39d554c (Task 2): FOUND
