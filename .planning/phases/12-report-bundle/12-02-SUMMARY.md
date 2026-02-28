---
phase: 12-report-bundle
plan: 02
subsystem: simulations
tags: [matplotlib, pandas, numpy, heatmap, bar-chart, composite, subplot_mosaic, detail-plots, sweep, report]

requires:
  - phase: 12-report-bundle
    plan: 01
    provides: generate_sweep_report, _plot_metric_heatmap, ReportResult, _METRIC_CMAPS

provides:
  - _plot_cell_detail() bar chart for single sweep config
  - _build_composite() 2x2 subplot_mosaic combining key metric heatmaps
  - Updated generate_sweep_report producing detail/ and composite.png

affects: []

tech-stack:
  added: []
  patterns:
    - Figure.subplot_mosaic for multi-panel layout (no pyplot)
    - nlargest/nsmallest for best/worst N config selection
    - NaN-to-0.0 substitution in bar charts (not None — bar heights must be numeric)
    - Inline heatmap rendering into subplot_mosaic axes (reuse _METRIC_CMAPS, no sub-Figure)

key-files:
  created: []
  modified:
    - apps/simulations/src/backtesting/report.py
    - apps/simulations/tests/test_report.py

key-decisions:
  - "NaN metric values replaced with 0.0 for bar heights in _plot_cell_detail — bar charts
    cannot accept NaN as a height value, so 0.0 is the correct substitution"
  - "_build_composite inlines imshow logic per panel rather than calling _plot_metric_heatmap
    — that function creates its own Figure which cannot be embedded into subplot_mosaic axes"
  - "Composite uses 4 panels: flip_rate, gini_legacy, enp_signals_mean, margin_shift_mean
    — covers the primary outcome metrics for publication-ready summary"

patterns-established:
  - "subplot_mosaic 2x2 layout: [['A','B'],['C','D']] with Figure(figsize=(18,12))"
  - "detail PNG naming: best_{rank:02d}_cell_{cell_id}.png / worst_{rank:02d}_cell_{cell_id}.png"
  - "composite.png at dpi=200 (lower than detail dpi=300 — composite is wider, overview image)"

requirements-completed: [REPT-05, REPT-06]

duration: 4min
completed: 2026-02-28
---

# Phase 12 Plan 02: Report Bundle Detail Plots and Composite Figure Summary

**Per-config detail bar charts (REPT-06) and 2x2 subplot_mosaic composite figure (REPT-05)
added to report.py; 6 new tests bring test_report.py to 14 passing tests**

## Performance

- **Duration:** 4 min
- **Started:** 2026-02-28T16:17:03Z
- **Completed:** 2026-02-28T16:20:42Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- `_plot_cell_detail(row, title)`: bar chart of 9 metrics for a single sweep config, NaN->0.0
  for bar heights, ORANGE (#FF9800) bars, rotated x-axis labels, Figure(figsize=(10,5))
- `_build_composite(summary_df, row_axis, col_axis)`: 2x2 `subplot_mosaic` rendering
  flip_rate, gini_legacy, enp_signals_mean, margin_shift_mean heatmaps with origin='lower',
  colorbar, cell annotations, suptitle, tight_layout with room for suptitle
- `generate_sweep_report` updated: produces `detail/best_{rank:02d}_cell_{id}.png` and
  `detail/worst_{rank:02d}_cell_{id}.png` for best_n/worst_n configs ranked by ranking_metric,
  plus `composite.png` at dpi=200 — all appended to ReportResult.saved_paths
- 6 new tests covering REPT-05 and REPT-06; all 14 test_report.py tests pass
- Full test suite: 214 passing tests, no regressions

## Task Commits

1. **Task 1: Add _plot_cell_detail, _build_composite, wire into generate_sweep_report** - `8190d7a` (feat)
2. **Task 2: Add tests for detail plots and composite figure** - `e0cc1a4` (feat)

## Files Created/Modified

- `apps/simulations/src/backtesting/report.py` — Added _DETAIL_METRICS constant, _ORANGE color,
  _plot_cell_detail, _COMPOSITE_METRICS, _build_composite; updated generate_sweep_report to
  call both and extend saved_paths with detail/ and composite.png paths
- `apps/simulations/tests/test_report.py` — Added Figure import, _plot_cell_detail and
  _build_composite imports, 6 new test functions for REPT-05 and REPT-06

## Decisions Made

- NaN metric values replaced with 0.0 for bar heights in `_plot_cell_detail` — bar charts
  cannot accept NaN as a height value; 0.0 is the correct substitution (not None)
- `_build_composite` inlines `imshow` logic per panel rather than calling `_plot_metric_heatmap`
  — that function creates its own Figure which cannot be embedded into subplot_mosaic axes
- Composite figure uses 4 panels: flip_rate, gini_legacy, enp_signals_mean, margin_shift_mean
  — covers primary outcome metrics suitable for publication-ready summary image

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## Next Phase Readiness

- Phase 12 report bundle is now complete: heatmaps, CSV/JSON, detail plots, composite figure
- generate_sweep_report produces a full output bundle ready to be called from sweep runner CLI
- REPT-01 through REPT-08 all completed across Plan 01 and Plan 02

---
*Phase: 12-report-bundle*
*Completed: 2026-02-28*

## Self-Check: PASSED

- report.py: FOUND
- test_report.py: FOUND
- 12-02-SUMMARY.md: FOUND
- Commit 8190d7a (Task 1): FOUND
- Commit e0cc1a4 (Task 2): FOUND
