---
phase: 09-monte-carlo-allocation-modeling
plan: 01
subsystem: simulations
tags: [monte-carlo, allocation, beta-distribution, two-rng, factory, vote-timing]

# Dependency graph
requires:
  - phase: 08-foundation-fixes-budget-promotion
    provides: AllocationDistribution ABC with BetaDistribution/UniformDistribution/TruncnormDistribution in budget.py

provides:
  - VoteTimingConfig dataclass with early/mid fraction validation in factory.py
  - mc_dist parameter on generate_scenario() enabling MC allocation sampling
  - vote_timing parameter on generate_scenario() enabling custom timing distributions
  - Two-RNG architecture: alloc_rng draws one fraction per scenario, scenario_rng unchanged
  - MCAL-01, MCAL-03, MCAL-05 test coverage in test_factory.py
affects:
  - 09-02 (sweep runner — will call generate_scenario with mc_dist sweeping BetaDistribution params)
  - 09-03 (pipeline integration — mc_dist threading into pipeline config)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Two-RNG split: SeedSequence.spawn(2) separates alloc_rng from scenario_rng — alloc_frac drawn once per scenario, not per voter"
    - "mc_dist=None code path fully unchanged — backward-compatible via if/else branching on alloc_frac sentinel"
    - "VoteTimingConfig dataclass with __post_init__ validation — same pattern as BetaDistribution in budget.py"

key-files:
  created: []
  modified:
    - apps/simulations/src/backtesting/data/factory.py
    - apps/simulations/tests/test_factory.py

key-decisions:
  - "alloc_frac drawn ONCE per scenario (not per voter) — ensures all voters in a scenario share the same MC-drawn allocation fraction, making the scenario a locked decision"
  - "Two-RNG split via SeedSequence.spawn(2) — alloc_rng is completely independent from scenario_rng, so mc_dist=None path bit-identical to v2.0 for same seed"
  - "mc_dist=None branch uses rng = np.random.default_rng(seed) unchanged — backward compat preserved by if/else not try/except"
  - "VoteTimingConfig placed in factory.py not budget.py — it configures scenario generation, not allocation math; keeps budget.py a leaf module"

patterns-established:
  - "Two-RNG split pattern: SeedSequence.spawn(2) for orthogonal RNG streams — use this for any future MC parameter injection into generate_scenario()"
  - "alloc_frac sentinel: float | None = None set before the if/else block, checked per-voter inside budget block — keeps MC mode opt-in with zero impact on None path"

requirements-completed: [MCAL-01, MCAL-03, MCAL-05]

# Metrics
duration: 2min
completed: 2026-02-28
---

# Phase 9 Plan 01: MC Allocation + VoteTimingConfig in generate_scenario() Summary

**Two-RNG architecture wires BetaDistribution into generate_scenario() via mc_dist param: one alloc_frac drawn per scenario using SeedSequence.spawn(2), with mc_dist=None path bit-identical to v2.0**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-28T01:13:56Z
- **Completed:** 2026-02-28T01:16:25Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- VoteTimingConfig dataclass added to factory.py with early/mid fraction validation (raises ValueError if early+mid > 1.0 or negative)
- generate_scenario() extended with mc_dist and vote_timing params — two-RNG split activates only when mc_dist is provided
- MCAL-01, MCAL-03, MCAL-05, and validation tests added to test_factory.py — all 22 factory tests pass, 156 total tests pass

## Task Commits

Each task was committed atomically:

1. **Task 1: Add VoteTimingConfig and extend generate_scenario() signature** - `418c4c6` (feat)
2. **Task 2: Add MCAL-01, MCAL-03, MCAL-05 tests** - `fa9a4a4` (feat)

**Plan metadata:** (docs: complete plan — pending)

## Files Created/Modified
- `apps/simulations/src/backtesting/data/factory.py` - Added VoteTimingConfig dataclass, AllocationDistribution import, mc_dist + vote_timing params, two-RNG split, VoteTimingConfig threading into _generate_vote_timing
- `apps/simulations/tests/test_factory.py` - Added BetaDistribution + VoteTimingConfig imports, four new test functions covering MCAL-01/03/05 and validation

## Decisions Made
- alloc_frac drawn once per scenario not per voter — scenario-level locked decision matches Monte Carlo semantics where a scenario "is" a particular allocation regime
- SeedSequence.spawn(2) instead of two manual seeds — ensures true orthogonality between alloc_rng and scenario_rng with no seed collision risk
- VoteTimingConfig lives in factory.py not budget.py — keeps budget.py a pure leaf module with no scenario-layer concerns

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- generate_scenario() now accepts mc_dist, enabling Phase 9 sweep runner to pass BetaDistribution(a, b) for each parameter grid point
- Backward compatibility confirmed: all 156 tests pass, existing callers unaffected
- alloc_frac sentinel pattern ready for Phase 9-02 sweep runner to iterate over mc_dist instances

---
*Phase: 09-monte-carlo-allocation-modeling*
*Completed: 2026-02-28*
