---
phase: 11-extended-analysis
plan: 01
subsystem: analysis
tags: [python, pandas, numpy, backtesting, governance, dataclasses]

# Dependency graph
requires:
  - phase: 10-sweep-runner
    provides: results_df schema (14-column DataFrame from build_results_dataframe)
  - phase: 05-metrics
    provides: frozen-dataclass pure-function pattern (metrics.py), NaN convention
provides:
  - backtesting/analysis.py: MarginClassBreakdown, VoterArchetypes frozen dataclasses
  - margin_class_breakdown(): ANAL-01 — bins flipped proposals by legacy margin class
  - voter_archetypes(): ANAL-04 — tertile stake classification (retail/medium/whale)
  - Module structure per ANAL-07: independent of cadCAD, pure functions, __all__
affects:
  - 11-02 (next plan extends analysis.py with ANAL-02/03/05/06)
  - sweep pipeline (consumes analysis functions for heatmap metrics)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Pure-function analysis module independent of metrics.py (no cross-import)
    - frozen dataclass results with inline _get_final_tallies replication
    - pd.qcut with duplicates='drop' for robust tertile classification
    - NaN-for-degenerate-inputs convention applied to zero-denominator margins

key-files:
  created:
    - apps/simulations/src/backtesting/analysis.py
    - apps/simulations/tests/test_analysis.py
  modified: []

key-decisions:
  - "analysis.py is independent of metrics.py — _get_final_tallies replicated inline to keep module boundaries clean"
  - "pd.qcut with duplicates='drop' handles Pareto-distributed stake edge cases without full fallback"
  - "margin_class_breakdown uses pd.cut bins=[0.0, 0.10, 0.30, 1.01] include_lowest=True for clean [0,10%)/[10%,30%)/[30%,100%] buckets"

patterns-established:
  - "analysis.py pattern: from __future__ import annotations, dataclasses, numpy, pandas only — no simulation imports"
  - "Inline _get_final_tallies replication: analysis modules do not import from metrics.py"
  - "VoterArchetypes.labels returns DataFrame with ['voter', 'weight', 'archetype'] columns"

requirements-completed: [ANAL-01, ANAL-04, ANAL-07]

# Metrics
duration: 2min
completed: 2026-02-28
---

# Phase 11 Plan 01: Extended Analysis Module (ANAL-01/04/07) Summary

**Pure-function analysis.py with margin_class_breakdown (flip binning by legacy margin) and voter_archetypes (tertile stake classification), plus 6-test coverage for ANAL-01/04/07**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-28T13:54:47Z
- **Completed:** 2026-02-28T13:56:48Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Created `backtesting/analysis.py` with `MarginClassBreakdown` and `VoterArchetypes` frozen dataclasses following the metrics.py pattern
- Implemented `margin_class_breakdown()` (ANAL-01): bins flipped proposals into tight (<10%), moderate (10-30%), decisive (>=30%) classes using `pd.cut`
- Implemented `voter_archetypes()` (ANAL-04): classifies voters by total stake tertile (retail/medium/whale) via `pd.qcut` with duplicate-edge handling
- Created `test_analysis.py` with 6 tests covering all three requirements (ANAL-01/04/07); full 184-test suite green

## Task Commits

Each task was committed atomically:

1. **Task 1: Create analysis.py with margin_class_breakdown and voter_archetypes** - `e1132a9` (feat)
2. **Task 2: Create test_analysis.py for ANAL-01, ANAL-04, ANAL-07** - `fa4ed3b` (test)

**Plan metadata:** (docs commit follows)

## Files Created/Modified
- `apps/simulations/src/backtesting/analysis.py` - Extended analysis module: MarginClassBreakdown, VoterArchetypes, margin_class_breakdown(), voter_archetypes()
- `apps/simulations/tests/test_analysis.py` - 6 tests covering ANAL-01 (3 tests), ANAL-04 (2 tests), ANAL-07 (1 test)

## Decisions Made
- `analysis.py` is module-independent of `metrics.py` — `_get_final_tallies` is replicated inline rather than imported, keeping a clean boundary between the metrics and analysis subsystems
- `pd.qcut` with `duplicates='drop'` handles Pareto-distributed stake edge cases (common with Pareto profiles where many voters share identical total stakes)
- Margin bins use `[0.0, 0.10, 0.30, 1.01]` with `include_lowest=True` so exactly 0% margin (rare but possible) is correctly classified as tight

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `backtesting/analysis.py` module established with ANAL-01/04/07 complete
- `__all__` is ready for Plan 02 to extend with ANAL-02 (address influence), ANAL-03 (flip driver attribution), ANAL-05 (cohort participation), ANAL-06 (lock duration effectiveness)
- Full test suite (184 tests) green — no regressions from this plan

## Self-Check: PASSED

- FOUND: apps/simulations/src/backtesting/analysis.py
- FOUND: apps/simulations/tests/test_analysis.py
- FOUND: .planning/phases/11-extended-analysis/11-01-SUMMARY.md
- FOUND: commit e1132a9 (feat: analysis.py)
- FOUND: commit fa4ed3b (test: test_analysis.py)

---
*Phase: 11-extended-analysis*
*Completed: 2026-02-28*
