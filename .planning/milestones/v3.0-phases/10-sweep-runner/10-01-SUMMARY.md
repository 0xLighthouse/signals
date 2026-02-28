---
phase: 10-sweep-runner
plan: 01
subsystem: simulation
tags: [python, dataclasses, itertools, tomllib, pandas, sweep, backtesting]

requires:
  - phase: 09-monte-carlo-allocation-modeling
    provides: MCSample, MCResult, run_mc_samples() — MC execution layer sweep will orchestrate
  - phase: 08-foundation-fixes-budget-promotion
    provides: generate_scenario() with curve_type/allocation_strategy params, AllocationDistribution ABC

provides:
  - SweepConfig dataclass: curve_types, alphas, lock_profiles, allocation_strategies, max_workers
  - SweepCell dataclass: single parameter combination with sequential cell_id
  - SweepResult dataclass: summary_df, failed_cells, output_dir
  - _enumerate_cells(): itertools.product cartesian grid enumeration
  - load_sweep_config(): TOML [base]/[sweep] loader with required max_workers
  - _make_output_dir(), _nan_to_none(), _make_failed_row() helpers

affects:
  - 10-02: run_sweep() executor builds directly on SweepConfig/SweepCell/SweepResult
  - phase-11-extended-analysis: consumes SweepResult.summary_df for analysis

tech-stack:
  added: []
  patterns:
    - itertools.product for cartesian parameter grid enumeration
    - tomllib for structured TOML config with [[array-of-tables]] for lock_profiles
    - lock_profile dict with short/long keys — long maps to l_max_days, short captured for analysis only

key-files:
  created:
    - apps/simulations/src/backtesting/sweep.py
    - apps/simulations/tests/test_sweep.py
  modified: []

key-decisions:
  - "lock_profile.long maps to l_max_days in generate_scenario; lock_profile.short captured for analysis only (no l_min_days param exists)"
  - "max_workers is required in TOML — no auto-detection, KeyError raised if missing"
  - "allocation_strategies defaults to ['uniform_fraction'] if not specified in TOML"

patterns-established:
  - "SweepCell carries the full lock_profile dict — executor extracts long for l_max_days, short for summary_df columns"
  - "cell_id is sequential integer starting from 0, matches row index in summary_df"

requirements-completed: [SWEP-01, SWEP-02, SWEP-05, SWEP-07]

duration: 2min
completed: 2026-02-28
---

# Phase 10 Plan 01: Sweep Data Model Summary

**SweepConfig/SweepCell/SweepResult dataclasses with itertools.product cartesian grid and TOML config loading via tomllib**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-02-28T12:28:19Z
- **Completed:** 2026-02-28T12:30:21Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Created sweep data model with SweepConfig, SweepCell, SweepResult dataclasses
- Implemented _enumerate_cells() using itertools.product for true cartesian grid enumeration
- Implemented load_sweep_config() parsing TOML [base]/[sweep] sections with required max_workers
- Added SWEP-01/02/05/07 requirement-traced tests — all 5 pass, full suite 165 tests green

## Task Commits

Each task was committed atomically:

1. **Task 1: Create SweepConfig, SweepCell, SweepResult dataclasses** - `f3736c8` (feat)
2. **Task 2: Add SWEP-01/02/05/07 tests for sweep data model** - `ce6dd81` (test)

## Files Created/Modified

- `apps/simulations/src/backtesting/sweep.py` - SweepConfig/SweepCell/SweepResult dataclasses, _enumerate_cells(), load_sweep_config(), _make_output_dir(), _nan_to_none(), _make_failed_row()
- `apps/simulations/tests/test_sweep.py` - Five tests covering SWEP-01 cartesian product, SWEP-02 cartesian-not-zip, SWEP-05 summary_df shape, SWEP-07 TOML loading and missing max_workers

## Decisions Made

- lock_profile.long maps to l_max_days in generate_scenario; short key captured for analysis but not passed to factory (no l_min_days parameter exists in generate_scenario)
- max_workers required in TOML — raises KeyError if missing, no auto-detection
- allocation_strategies defaults to ['uniform_fraction'] if not in TOML [sweep] section

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 02 can proceed immediately: SweepConfig/SweepCell/SweepResult type contracts are established
- run_sweep() in Plan 02 receives SweepConfig, calls _enumerate_cells(), iterates cells, returns SweepResult
- lock profile mapping is documented: cell.lock_profile['long'] -> l_max_days, cell.lock_profile['short'] -> summary_df column

---
*Phase: 10-sweep-runner*
*Completed: 2026-02-28*
