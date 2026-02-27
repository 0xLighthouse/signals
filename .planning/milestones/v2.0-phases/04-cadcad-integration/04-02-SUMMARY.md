---
phase: 04-cadcad-integration
plan: 02
subsystem: simulation
tags: [cadcad, event-replay, backtesting, voting, runner, dataframe, integration-test]

# Dependency graph
requires:
  - phase: 04-cadcad-integration
    plan: 01
    provides: PSUBS, policy_event_replay, suf_step, suf_tallies from backtesting.simulation
  - phase: 03-foundation
    provides: compute_legacy_weight and compute_signals_weight pure functions from backtesting.weighting.signals
provides:
  - apps/simulations/src/backtesting/simulation/runner.py — run_backtest() and build_results_dataframe()
  - apps/simulations/src/backtesting/simulation/__init__.py — public exports for simulation subpackage
  - apps/simulations/tests/conftest.py — minimal_event_records, backtest_raw_result, backtest_dataframe fixtures
  - apps/simulations/tests/test_simulation_runner.py — all 8 SIM tests passing (SIM-01 through SIM-08)
affects: [any phase consuming cadCAD event-replay results, Phase 5 metrics analysis]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - cadCAD Configuration with tuple(event_records) for M param — prevents parameter sweep by making stream non-iterable by cadCAD internals
    - DataFrame builder pattern — skips raw_result[0] (initial state), aligns raw_result[1..N] with event_records[0..N-1] by position
    - Explicit float64 cast for all tally columns — avoids None/NaN dtype ambiguity in pandas

key-files:
  created:
    - apps/simulations/src/backtesting/simulation/runner.py
  modified:
    - apps/simulations/src/backtesting/simulation/__init__.py
    - apps/simulations/tests/conftest.py
    - apps/simulations/tests/test_simulation_runner.py

key-decisions:
  - "run_backtest uses tuple(event_records) for M param — prevents cadCAD from sweeping the event stream as a parameter list"
  - "build_results_dataframe skips raw_result[0] (initial state) and aligns by position — deterministic, no key lookups needed"
  - "timestep column taken from cadCAD state dict directly via state.get('timestep', i+1) — preserves cadCAD's own numbering"
  - "All 6 tally columns explicitly cast to float64 after DataFrame construction — handles None values from non-tally events"
  - "Consolidate minimal_event_records to conftest fixture — single source of truth for all 8 SIM tests"

patterns-established:
  - "cadCAD runner pattern: Configuration -> Executor.execute() -> raw_result list of N+1 dicts"
  - "Results builder pattern: enumerate(raw_result[1:]) aligned with event_records[i] — O(N) single pass"
  - "Tally extraction pattern: check pid exists in tallies_now before unpacking legacy/signals sub-dicts"

requirements-completed: [SIM-01, SIM-08]

# Metrics
duration: 3min
completed: 2026-02-27
---

# Phase 4 Plan 02: CadCAD Runner and Results DataFrame Summary

**cadCAD Configuration+Executor wired to PSUBS producing a 14-column float64 results DataFrame — all 8 SIM tests green (142 total), zero skipped**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-27T16:22:56Z
- **Completed:** 2026-02-27T16:26:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Implemented `run_backtest()` — wires PSUBS into cadCAD `Configuration` with `tuple(event_records)` for M param, returns N+1 raw_result list
- Implemented `build_results_dataframe()` — produces 14-column DataFrame with all tally columns explicitly cast to float64
- Updated `__init__.py` to export `run_backtest` and `build_results_dataframe` as the public simulation subpackage API
- Added three conftest fixtures (`minimal_event_records`, `backtest_raw_result`, `backtest_dataframe`) for integration test reuse
- Consolidated module-level test data to conftest fixture — all 8 SIM tests now use the same event source
- Un-skipped and implemented `test_sim01_no_errors` and `test_sim08_results_dataframe` — both pass
- Full test suite: 142 passed, 0 skipped, 0 failures

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement runner.py and update simulation __init__.py** - `7732094` (feat)
2. **Task 2: Add conftest fixtures and un-skip SIM-01 and SIM-08 integration tests** - `894087c` (feat)

## Files Created/Modified

- `apps/simulations/src/backtesting/simulation/runner.py` — `run_backtest()` and `build_results_dataframe()` functions (created)
- `apps/simulations/src/backtesting/simulation/__init__.py` — Updated to export public simulation API
- `apps/simulations/tests/conftest.py` — Added Phase 4 fixtures section with three fixtures
- `apps/simulations/tests/test_simulation_runner.py` — Consolidated to use conftest fixture, implemented SIM-01 and SIM-08

## Decisions Made

- `tuple(event_records)` for M param: cadCAD would sweep a list as multiple runs rather than treating it as a single parameter — wrapping in tuple prevents this behavior
- Skip raw_result[0] in DataFrame builder: index 0 is the cadCAD initial state (step=0, tallies={}) with no corresponding event; `enumerate(raw_result[1:])` ensures i aligns exactly with event_records[i]
- All 6 tally columns cast to float64 after DataFrame construction: events like PROPOSAL_CREATED and PROPOSAL_FINALIZED leave tally columns as None — explicit cast ensures consistent dtype regardless of event mix
- Consolidate minimal_event_records from module-level constant to conftest fixture: single source of truth prevents drift between unit and integration tests

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

- Commit hook requires lowercase type prefix — first commit attempt used `Feat(04-02)` which failed; fixed to `feat(04-02)`.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `from backtesting.simulation import run_backtest, build_results_dataframe` works end-to-end
- Full event-replay pipeline verified: synthetic events -> cadCAD simulation -> results DataFrame
- Phase 4 complete — Phase 5 metrics analysis can consume `build_results_dataframe()` output directly
- Resolved blocker from STATE.md: cadCAD `Executor.execute()` pattern validated with real events (no `Experiment.append_model()` needed for single-config execution)

---
*Phase: 04-cadcad-integration*
*Completed: 2026-02-27*

## Self-Check: PASSED

- runner.py: FOUND
- __init__.py: FOUND
- conftest.py: FOUND
- test_simulation_runner.py: FOUND
- 04-02-SUMMARY.md: FOUND
- Commit 7732094: FOUND
- Commit 894087c: FOUND
