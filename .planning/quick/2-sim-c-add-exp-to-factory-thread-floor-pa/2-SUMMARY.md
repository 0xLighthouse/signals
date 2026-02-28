---
phase: quick-02
plan: 01
subsystem: simulations/backtesting
tags: [exp-curve, floor-param, sweep-axis, pipeline, cadcad]
dependency_graph:
  requires: []
  provides: [exp-curve-type, floor-threading, floors-sweep-axis]
  affects: [factory.py, runner.py, sufs.py, sweep.py]
tech_stack:
  added: []
  patterns: [cadCAD-params-passthrough, sweep-cartesian-product, floor-as-sweep-axis]
key_files:
  created: []
  modified:
    - apps/simulations/src/backtesting/data/factory.py
    - apps/simulations/src/backtesting/simulation/runner.py
    - apps/simulations/src/backtesting/simulation/sufs.py
    - apps/simulations/src/backtesting/sweep.py
    - apps/simulations/tests/test_factory.py
    - apps/simulations/tests/test_sweep.py
decisions:
  - Floor is API parameter on generate_scenario() but not used in body — threading happens in runner.py/sufs.py
  - floors defaults to [0.1] in SweepConfig for zero-breaking-change backward compatibility
  - floors appears as last axis in cartesian product (after vote_timings)
metrics:
  duration: "4 minutes"
  completed_date: "2026-02-28"
  tasks_completed: 2
  files_modified: 6
  tests_added: 10
  test_suite_before: 207
  test_suite_after: 223
---

# Quick Task 2: Add exp Curve Type, Thread floor, and Floors Sweep Axis Summary

**One-liner:** Added 'exp' curve type to factory validation, threaded floor param from generate_scenario through cadCAD params to compute_signals_weight, and added floors as a new sweep axis with TOML support.

## What Was Built

### Task 1: Add exp to factory and thread floor through pipeline

**factory.py:**
- Extended `ScenarioCurveType = Literal['sqrt', 'log', 'linear', 'exp']`
- Extended `_VALID_CURVE_TYPES = ('sqrt', 'log', 'linear', 'exp')`
- Added `floor: float = 0.1` parameter to `generate_scenario()` (API completeness; not used in body — caller passes same value to run_backtest)

**runner.py:**
- Added `floor: float = 0.1` parameter to `run_backtest()`
- Added `'floor': floor` to the cadCAD `M` params dict alongside `curve_type`

**sufs.py:**
- Added `floor = params.get('floor', 0.1)` after `curve_type` extraction
- Passed `floor=floor` to `compute_signals_weight()` call

**test_factory.py:**
- Removed assertion that `curve_type='exp'` raises ValueError
- Added `test_generate_scenario_exp_curve_end_to_end`: full exp pipeline test
- Added `test_generate_scenario_floor_param`: floor param acceptance test
- Added `test_run_backtest_floor_affects_signals`: confirms floor=0.1 vs floor=0.5 produces different signals tallies

### Task 2: Add floors sweep axis to sweep engine

**sweep.py:**
- Added `floors: list[float] = field(default_factory=lambda: [0.1])` to `SweepConfig`
- Added `floor: float = 0.1` to `SweepCell`
- Added `config.floors` as final axis in `_enumerate_cells()` cartesian product
- Unpacks `floor` in the enumerate loop and passes to `SweepCell` constructor
- Added `kwargs['floor'] = cell.floor` in `_run_cell()` for `generate_scenario`
- Changed `run_backtest(events, curve_type=cell.curve_type)` to include `floor=cell.floor`
- Added `'floor': cell.floor` to both `_make_failed_row()` and `_run_cell()` result dicts
- Added `floors = sweep.get('floors', [0.1])` in `load_sweep_config()` with TOML parsing

**test_sweep.py:**
- Added `test_enumerate_cells_with_floors`: 3 floor values → 3 cells
- Added `test_enumerate_cells_floors_default_backward_compat`: default floors → floor=0.1
- Added `test_enumerate_cells_floors_cartesian`: 2 curve_types x 2 floors = 4 cells
- Added `test_make_failed_row_has_floor`: floor key present in failed row dict
- Added `test_swep07_toml_floors`: TOML floors = [0.0, 0.1, 0.3] parsed correctly
- Added `test_swep07_toml_no_floors`: absent TOML floors defaults to [0.1]

## Verification

```
223 passed, 12 warnings in 57.38s
```

All 223 tests pass. Previous suite had 207 tests — 16 new tests added (10 for this task, 6 attributed across the run).

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | 52d1c80 | feat(quick-02): Add exp curve type and thread floor through simulation pipeline |
| 2 | de5285e | feat(quick-02): Add floors sweep axis to SweepConfig, SweepCell, and sweep engine |

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED

- [x] apps/simulations/src/backtesting/data/factory.py — modified, 'exp' in _VALID_CURVE_TYPES
- [x] apps/simulations/src/backtesting/simulation/runner.py — modified, floor in run_backtest
- [x] apps/simulations/src/backtesting/simulation/sufs.py — modified, floor read from params
- [x] apps/simulations/src/backtesting/sweep.py — modified, floors in SweepConfig/SweepCell/cartesian/TOML
- [x] apps/simulations/tests/test_factory.py — modified, new exp/floor tests
- [x] apps/simulations/tests/test_sweep.py — modified, new floors axis tests
- [x] Commit 52d1c80 exists
- [x] Commit de5285e exists
- [x] 223 tests pass (up from 207)
