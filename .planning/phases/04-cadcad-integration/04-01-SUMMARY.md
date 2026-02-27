---
phase: 04-cadcad-integration
plan: 01
subsystem: simulation
tags: [cadcad, event-replay, backtesting, voting, tallies, policy, suf]

# Dependency graph
requires:
  - phase: 03-foundation
    provides: compute_legacy_weight and compute_signals_weight pure functions from backtesting.weighting.signals
provides:
  - backtesting/simulation/__init__.py — subpackage init
  - backtesting/simulation/policies.py — policy_event_replay function
  - backtesting/simulation/sufs.py — suf_step, suf_tallies, PSUBS
  - tests/test_simulation_runner.py — SIM-01 through SIM-08 test stubs
affects: [04-cadcad-integration-plan-02, any phase using cadCAD event-replay runner]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Pure Python cadCAD policy and SUF functions — no cadCAD imports, independently testable
    - deepcopy-first SUF pattern — suf_tallies always deepcopies before any mutation
    - Event-replay indexing by step counter — policy reads params['event_stream'][prev_state['step']]
    - Dual-tally accumulation — single VOTE_CAST pass updates both legacy and signals sub-dicts

key-files:
  created:
    - apps/simulations/src/backtesting/simulation/__init__.py
    - apps/simulations/src/backtesting/simulation/policies.py
    - apps/simulations/src/backtesting/simulation/sufs.py
    - apps/simulations/tests/test_simulation_runner.py
  modified: []

key-decisions:
  - "No cadCAD imports in policies.py or sufs.py — pure Python, cadCAD wired only in runner.py (Plan 02)"
  - "suf_tallies deepcopies tallies before any dispatch — SIM-07 identity check confirms no shared state"
  - "PSUBS defined in sufs.py alongside the SUFs — cohesion; runner.py imports PSUBS as single wiring point"
  - "SIM-01 and SIM-08 stubs use pytest.mark.skip with explicit reason — test file structure complete without blocking CI"

patterns-established:
  - "Pure policy/SUF pattern: functions take (params, substep, state_history, prev_state[, policy_input]) with no side effects"
  - "Dual-tally state shape: tallies[proposal_id] = {legacy: {FOR/AGAINST/ABSTAIN}, signals: {FOR/AGAINST/ABSTAIN}}"
  - "Event-replay by step index: stream[prev_state['step']] — deterministic, reproducible, no external state"

requirements-completed: [SIM-02, SIM-03, SIM-04, SIM-05, SIM-06, SIM-07]

# Metrics
duration: 8min
completed: 2026-02-27
---

# Phase 4 Plan 01: CadCAD Simulation Subpackage Summary

**Pure-Python cadCAD policy (event_replay) and SUFs (step, tallies) with dual-tally accumulation — 6 unit tests green, 2 integration stubs skipped pending runner.py**

## Performance

- **Duration:** 8 min
- **Started:** 2026-02-27T16:00:00Z
- **Completed:** 2026-02-27T16:08:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Created `backtesting/simulation/` subpackage with three files: `__init__.py`, `policies.py`, `sufs.py`
- `policy_event_replay` reads event at `prev_state['step']` from `params['event_stream']`, returns `None` past end of stream
- `suf_tallies` dispatches all three event types (PROPOSAL_CREATED, VOTE_CAST, PROPOSAL_FINALIZED) with deepcopy guarantee
- VOTE_CAST accumulates both `legacy` (raw stake via `compute_legacy_weight`) and `signals` (lock-weighted via `compute_signals_weight`) in a single pass
- `PSUBS` wires policy and SUFs ready for cadCAD `Configuration` in Plan 02
- Full test file with all 8 SIM test stubs — 6 pass (SIM-02 through SIM-07), 2 skipped pending runner.py

## Task Commits

Each task was committed atomically:

1. **Task 1: Simulation subpackage — policies and SUFs** - `d3a3e5c` (feat)
2. **Task 2: Simulation runner test suite** - `6cae3e8` (test)

## Files Created/Modified

- `apps/simulations/src/backtesting/simulation/__init__.py` — Subpackage init (empty body, exports added in Plan 02)
- `apps/simulations/src/backtesting/simulation/policies.py` — `policy_event_replay` pure function
- `apps/simulations/src/backtesting/simulation/sufs.py` — `suf_step`, `suf_tallies`, `PSUBS` definition
- `apps/simulations/tests/test_simulation_runner.py` — All 8 SIM test cases (6 unit, 2 skipped stubs)

## Decisions Made

- No cadCAD imports in policies.py or sufs.py — pure Python ensures independent testability and avoids cadCAD side effects during import; runner.py (Plan 02) is the single cadCAD entry point
- suf_tallies deepcopies tallies as the first operation before any event dispatch — guarantees SIM-07 identity check passes even for passthrough events (PROPOSAL_FINALIZED, None)
- PSUBS defined in sufs.py alongside the SUFs rather than in runner.py — cohesion; runner.py imports `PSUBS` as a single wiring point
- SIM-01 and SIM-08 use `pytest.mark.skip` with explicit reason strings — test file is structurally complete without blocking CI green

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

- Commit hook requires sentence-case subject line — initial commit attempt rejected, fixed by capitalizing "CadCAD" in subject.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `backtesting/simulation/` subpackage is importable and fully tested in isolation
- `PSUBS` ready for `cadcad.configuration.Configuration` wiring in Plan 02
- SIM-01 and SIM-08 stubs clearly labelled with skip reason — Plan 02 un-skips them once runner.py is implemented
- Remaining blocker from STATE.md: cadCAD `Experiment.append_model()` behavior should be validated during Plan 02 implementation

---
*Phase: 04-cadcad-integration*
*Completed: 2026-02-27*
