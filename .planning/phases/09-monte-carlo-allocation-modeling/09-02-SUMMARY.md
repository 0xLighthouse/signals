---
phase: 09-monte-carlo-allocation-modeling
plan: 02
subsystem: simulations
tags: [monte-carlo, seed-sequence, mc-runner, beta-distribution, reproducibility]

# Dependency graph
requires:
  - phase: 09-monte-carlo-allocation-modeling
    plan: 01
    provides: generate_scenario() with mc_dist + vote_timing params, VoteTimingConfig, two-RNG split architecture
  - phase: 08-foundation-fixes-budget-promotion
    provides: AllocationDistribution ABC with BetaDistribution in budget.py

provides:
  - MCSample dataclass with index, seed, alloc_frac, events
  - MCResult dataclass with base_seed, n_samples, samples list
  - run_mc_samples() function using SeedSequence.spawn(n_samples) for independent streams
  - MCAL-02, MCAL-04 test coverage in test_mc.py

affects:
  - 09-03 (pipeline integration — will call run_mc_samples as the MC engine)
  - 10 (sweep runner — consumes run_mc_samples across parameter grids)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SeedSequence.spawn(n_samples) for N independent child streams — each child produces a unique sample_seed via generate_state(1)[0]"
    - "alloc_frac reproduced externally by mirroring generate_scenario's SeedSequence.spawn(2) split: alloc_ss.spawn(2)[0] -> alloc_rng -> mc_dist.sample()"
    - "Auto-seed pattern: SeedSequence().entropy used as int base_seed when None passed — fully reproducible if stored"

key-files:
  created:
    - apps/simulations/src/backtesting/mc.py
    - apps/simulations/tests/test_mc.py
  modified: []

key-decisions:
  - "Pass int seed (child.generate_state(1)[0]) to generate_scenario, not the SeedSequence child directly — generate_scenario internally wraps seed in SeedSequence(seed), so int is the correct type"
  - "alloc_frac captured by re-deriving externally (mirror generate_scenario's SeedSequence.spawn(2)) — avoids changing generate_scenario's return type"
  - "Auto base_seed stored as ss.entropy (large int) — no int conversion needed, MCResult.base_seed typed as int covers numpy int too"

patterns-established:
  - "MC runner pattern: SeedSequence.spawn(N) -> per-child int seeds -> generate_scenario(seed=int) -> replay alloc_frac externally"
  - "Metadata-first design: MCSample carries alloc_frac for sweep runner analysis without re-running generate_scenario"

requirements-completed: [MCAL-02, MCAL-04]

# Metrics
duration: 1min
completed: 2026-02-28
---

# Phase 9 Plan 02: MC Runner Module Summary

**MCSample/MCResult dataclasses and run_mc_samples() with SeedSequence.spawn(N) independence: 50 samples from the same base_seed produce 50 statistically independent, reproducible allocation streams**

## Performance

- **Duration:** 1 min
- **Started:** 2026-02-28T01:18:46Z
- **Completed:** 2026-02-28T01:20:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- `backtesting/mc.py` created with MCSample, MCResult dataclasses and run_mc_samples() function
- SeedSequence.spawn(n_samples) produces N independent child streams — no inter-sample RNG correlation
- alloc_frac reproduced per sample by mirroring generate_scenario's internal SeedSequence.spawn(2) split
- MCAL-02 and MCAL-04 tests pass; full suite at 160 tests passing (was 156)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create backtesting/mc.py MC runner module** - `14a04ae` (feat)
2. **Task 2: Add MCAL-02, MCAL-04 tests for MC runner** - `e1587d0` (feat)

**Plan metadata:** (docs: complete plan — pending)

## Files Created/Modified
- `apps/simulations/src/backtesting/mc.py` - MCSample/MCResult dataclasses, run_mc_samples() with SeedSequence.spawn independence, auto-seed mode, alloc_frac reproduction
- `apps/simulations/tests/test_mc.py` - 4 tests covering MCAL-02, MCAL-04, reproducibility, and auto-seed behavior

## Decisions Made
- `generate_state(1)[0]` cast to int for sample_seed — generate_scenario expects an int (wraps it in SeedSequence(seed)), not a SeedSequence child directly
- alloc_frac derived externally rather than returning it from generate_scenario — keeps factory API unchanged, metadata extracted by mirroring the internal two-RNG split
- `ss.entropy` stored directly as base_seed — SeedSequence().entropy is already a large int, no conversion needed

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- run_mc_samples() is the complete MC engine for Phase 10's sweep runner
- MCSample.alloc_frac enables sweep analysis without re-running scenarios
- MCResult.base_seed enables full experiment reproduction from a single stored value
- All 160 simulation tests pass, no regressions

## Self-Check: PASSED

- apps/simulations/src/backtesting/mc.py: FOUND
- apps/simulations/tests/test_mc.py: FOUND
- .planning/phases/09-monte-carlo-allocation-modeling/09-02-SUMMARY.md: FOUND
- Commit 14a04ae: FOUND
- Commit e1587d0: FOUND

---
*Phase: 09-monte-carlo-allocation-modeling*
*Completed: 2026-02-28*
