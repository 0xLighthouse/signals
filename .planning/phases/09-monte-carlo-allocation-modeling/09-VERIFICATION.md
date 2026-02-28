---
phase: 09-monte-carlo-allocation-modeling
verified: 2026-02-28T04:30:00Z
status: passed
score: 8/8 must-haves verified
re_verification: false
---

# Phase 9: Monte Carlo Allocation Modeling Verification Report

**Phase Goal:** Allocation fractions are drawn from configurable probability distributions rather than fixed values, with seed-safe independent generators per sample, enabling MC allocation as a continuous sweep axis
**Verified:** 2026-02-28T04:30:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| #   | Truth                                                                                        | Status     | Evidence                                                                                                          |
| --- | -------------------------------------------------------------------------------------------- | ---------- | ----------------------------------------------------------------------------------------------------------------- |
| 1   | `generate_scenario(mc_dist=BetaDistribution(2,5))` draws from Beta(2,5), not uniform        | VERIFIED   | 200-sample mean = 0.2815, matches Beta(2,5) expected 0.286; uniform would be ~0.5                                |
| 2   | `generate_scenario()` without mc_dist produces bit-identical output for same seed            | VERIFIED   | Two runs with seed=42 produce identical block_number, weight, voter, support sequences                           |
| 3   | `VoteTimingConfig(early=0.3, mid=0.5)` alters timing; `early=0.6, mid=0.5` raises ValueError| VERIFIED   | VoteTimingConfig.__post_init__ raises `ValueError: early + mid must be <= 1.0, got 0.6 + 0.5 = 1.1`            |
| 4   | `generate_scenario(vote_timing=VoteTimingConfig(early=0.80, mid=0.10))` shifts votes earlier | VERIFIED   | Block number arrays differ between heavy-early and default config for same seed                                   |
| 5   | 50 MC samples with same base_seed produce 50 distinct allocation sequences                   | VERIFIED   | `set(round(f, 12) for f in fracs)` has 50 unique elements; all in [0, 1]                                        |
| 6   | MC runner produces N samples each with a distinct seed in metadata                           | VERIFIED   | `len(set(seeds)) == 50` confirmed with base_seed=42, n_samples=50                                               |
| 7   | MC runner with base_seed=None auto-generates a seed and records it in MCResult               | VERIFIED   | `result.base_seed = 113677689495431003457614710658547948973` (large int from SeedSequence().entropy)             |
| 8   | Each MCSample contains events and the drawn allocation fraction                              | VERIFIED   | All 50 samples have `len(events) > 0` and `0.0 <= alloc_frac <= 1.0`                                           |

**Score:** 8/8 truths verified

### Required Artifacts

| Artifact                                                         | Expected                                           | Status     | Details                                                                    |
| ---------------------------------------------------------------- | -------------------------------------------------- | ---------- | -------------------------------------------------------------------------- |
| `apps/simulations/src/backtesting/data/factory.py`               | VoteTimingConfig dataclass, mc_dist param, two-RNG split | VERIFIED | Contains `class VoteTimingConfig`, `mc_dist` param, SeedSequence.spawn(2) split at line 304 |
| `apps/simulations/tests/test_factory.py`                         | MCAL-01, MCAL-03, MCAL-05 test coverage            | VERIFIED   | Contains `test_mcal01_mc_dist_draws_from_beta`, `test_mcal03_backward_compat`, `test_mcal05_vote_timing_config`, `test_vote_timing_config_validation` |
| `apps/simulations/src/backtesting/mc.py`                         | MCSample, MCResult dataclasses and run_mc_samples()| VERIFIED   | Contains `class MCSample`, `class MCResult`, `run_mc_samples()` with SeedSequence.spawn(n_samples) |
| `apps/simulations/tests/test_mc.py`                              | MCAL-02, MCAL-04 test coverage                     | VERIFIED   | Contains `test_mcal02_independent_sequences`, `test_mcal04_mc_runner_distinct_seeds`, `test_mc_runner_reproducible`, `test_mc_runner_auto_seed` |

### Key Link Verification

| From                               | To                                             | Via                                                       | Status   | Details                                                          |
| ---------------------------------- | ---------------------------------------------- | --------------------------------------------------------- | -------- | ---------------------------------------------------------------- |
| `factory.py generate_scenario()`   | `budget.py AllocationDistribution.sample()`    | `mc_dist.sample(alloc_rng, 1)` when mc_dist is not None   | WIRED    | factory.py line 315: `alloc_frac = float(mc_dist.sample(alloc_rng, 1)[0])` |
| `factory.py generate_scenario()`   | `factory.py _generate_vote_timing()`           | VoteTimingConfig early/mid params threaded to early_frac/mid_frac | WIRED | factory.py line 369-371: `_early = vote_timing.early if vote_timing is not None else 0.30` |
| `mc.py run_mc_samples()`           | `factory.py generate_scenario()`               | `generate_scenario(seed=child, mc_dist=mc_dist)` per sample | WIRED  | mc.py lines 142-159: full generate_scenario call with mc_dist=mc_dist |
| `mc.py run_mc_samples()`           | `numpy SeedSequence.spawn()`                   | `SeedSequence(base_seed).spawn(n_samples)` for independent generators | WIRED | mc.py line 132: `children = ss.spawn(n_samples)` |

### Requirements Coverage

| Requirement | Source Plan | Description                                                                              | Status    | Evidence                                                                         |
| ----------- | ----------- | ---------------------------------------------------------------------------------------- | --------- | -------------------------------------------------------------------------------- |
| MCAL-01     | 09-01       | Replace fixed allocation with `AllocationDistribution` draws via mc_dist parameter       | SATISFIED | `alloc_frac = float(mc_dist.sample(alloc_rng, 1)[0])` in factory.py; test_mcal01 passes |
| MCAL-02     | 09-02       | Use `np.random.SeedSequence(base_seed).spawn(n_samples)` for independent MC generators   | SATISFIED | mc.py line 132: `children = ss.spawn(n_samples)`; test_mcal02 passes with 50 distinct fracs |
| MCAL-03     | 09-01       | `generate_scenario()` accepts optional `mc_dist` parameter (backward compatible)         | SATISFIED | Signature has `mc_dist: AllocationDistribution | None = None`; test_mcal03 passes |
| MCAL-04     | 09-02       | MC runner produces N independent samples per configuration with distinct seeds            | SATISFIED | Each child seed from `generate_state(1)[0]` is unique; test_mcal04 passes        |
| MCAL-05     | 09-01       | Expose `early_frac`/`mid_frac` vote-timing parameters through `generate_scenario()`      | SATISFIED | `vote_timing: VoteTimingConfig | None = None` param; threading to `_generate_vote_timing`; test_mcal05 passes |

All 5 MCAL requirements are satisfied. No orphaned requirements detected.

### Anti-Patterns Found

None. Scanned all four phase-modified files for TODO/FIXME/PLACEHOLDER comments, empty return statements, and stub patterns. No issues found.

### Human Verification Required

None. All phase behaviors are verifiable programmatically:
- Distribution correctness: verified via statistical mean test (Beta(2,5) mean ≈ 0.286 confirmed)
- Backward compatibility: verified by bit-identical comparison
- Seed independence: verified by set-uniqueness check on 50 allocation fractions
- Timing alteration: verified by block array inequality check

### Test Suite Status

Full suite: **160 passed, 7 warnings** in 18.83 seconds. No regressions introduced.

Breakdown of new MCAL tests:
- `test_mcal01_mc_dist_draws_from_beta` — PASSED
- `test_mcal03_backward_compat` — PASSED
- `test_mcal05_vote_timing_config` — PASSED
- `test_vote_timing_config_validation` — PASSED
- `test_mcal02_independent_sequences` — PASSED
- `test_mcal04_mc_runner_distinct_seeds` — PASSED
- `test_mc_runner_reproducible` — PASSED
- `test_mc_runner_auto_seed` — PASSED

### Commit Verification

All four commits from SUMMARY.md are confirmed present in git history:
- `418c4c6` feat(09-01): Add VoteTimingConfig and extend generate_scenario() with mc_dist + vote_timing
- `fa9a4a4` feat(09-01): Add MCAL-01, MCAL-03, MCAL-05 tests to test_factory.py
- `14a04ae` feat(09-02): Create backtesting/mc.py MC runner module
- `e1587d0` feat(09-02): Add MCAL-02, MCAL-04 tests for MC runner

---

_Verified: 2026-02-28T04:30:00Z_
_Verifier: Claude (gsd-verifier)_
