---
phase: 03-foundation
verified: 2026-02-27T16:30:00Z
status: passed
score: 16/16 must-haves verified
re_verification: false
---

# Phase 3: Foundation Verification Report

**Phase Goal:** A testable data and weighting layer exists that can be exercised without cadCAD
**Verified:** 2026-02-27T16:30:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| #  | Truth | Status | Evidence |
|----|-------|--------|----------|
| 1  | Pydantic v2 models exist for PROPOSAL_CREATED, VOTE_CAST, and PROPOSAL_FINALIZED with Governor Bravo field names | VERIFIED | `schema.py` lines 38-108 — three BaseModel classes with correct fields; all 3 confirmed importable |
| 2  | Pydantic rejects malformed events (bad support value, negative weight, end_block <= start_block) at construction time | VERIFIED | `schema.py` `@field_validator` and `@model_validator(mode='after')` decorators; 6 rejection tests pass in `TestValidationRejectsBadEvents` |
| 3  | EventType and VoteSupport are Python enums with correct values | VERIFIED | `schema.py` lines 24-35 — `EventType(str, Enum)` with PROPOSAL_CREATED/VOTE_CAST/PROPOSAL_FINALIZED; `VoteSupport(str, Enum)` with FOR/AGAINST/ABSTAIN |
| 4  | GovernorDataLoader Protocol is defined and runtime-checkable | VERIFIED | `schema.py` lines 115-142 — `@runtime_checkable class GovernorDataLoader(Protocol)`; `test_protocol_is_runtime_checkable` passes |
| 5  | lock_curve() returns values in [floor, 1.0] for all four curve types (sqrt, linear, log, exp) | VERIFIED | `signals.py` lines 19-75 — floor+scale normalization pattern; 16 parametrized tests across all 4 curve types pass |
| 6  | sqrt curve exhibits diminishing returns — delta decreases at 30/60/90/120 day intervals | VERIFIED | `signals.py` sqrt formula `sqrt(L/L_max)` is concave; `test_diminishing_returns_sqrt` confirms d1>d2>d3>d4 |
| 7  | compute_signals_weight() = stake * f(lock_duration) with no cadCAD import | VERIFIED | `signals.py` line 110: `return stake * lock_curve(...)`. Zero cadCAD import lines in source; `test_no_cadcad_import` scans import statements and passes |
| 8  | compute_legacy_weight(stake) == stake for any positive value | VERIFIED | `signals.py` line 134: `return float(stake)`; `test_legacy_weight_identity` parametrized on [0, 1, 100, 1e6, 0.001] — all pass |
| 9  | Factory generates a configurable number of voters, proposals, and participation rate | VERIFIED | `factory.py` `generate_scenario()` lines 186-363 — accepts n_voters, n_proposals, avg_participation_rate; `test_configurable_counts` passes |
| 10 | Pareto stake distribution (alpha=0.7) achieves Gini >= 0.65 at n=200 voters | VERIFIED | `factory.py` `_generate_stakes()` lines 36-62 — Pareto(alpha=0.7) distribution; `test_gini_requirement` confirms Gini >= 0.65 across 5 seeds |
| 11 | Vote timing follows tri-modal distribution (early/mid/late within proposal window) | VERIFIED | `factory.py` `_generate_vote_timing()` lines 91-123 — 30% early, 40% mid, 30% late; `test_trimodal_timing` confirms each window > 10% |
| 12 | Generated event stream has no double votes and no out-of-window votes | VERIFIED | `factory.py` `seen_voters` set tracks uniqueness per proposal; votes clamped to `[start_block, end_block-1]`; `test_referential_integrity` passes |
| 13 | Factory accepts distribution profile parameter (pareto, uniform, bimodal) | VERIFIED | `factory.py` `StakeProfile = Literal['pareto', 'uniform', 'bimodal']`; all three branches implemented in `_generate_stakes`; `test_distribution_profiles` passes |
| 14 | Same seed produces identical event streams (reproducibility) | VERIFIED | `factory.py` uses `np.random.default_rng(seed)` — single RNG for all randomness; `test_reproducibility` confirms identical output for seed=42 |
| 15 | SyntheticLoader and ParquetLoader both satisfy GovernorDataLoader Protocol | VERIFIED | `loader.py` both classes have `load() -> pd.DataFrame`; module-level `assert isinstance(SyntheticLoader([]), GovernorDataLoader)` at line 225; `test_protocol_compliance` passes |
| 16 | Loader rejects event streams with referential integrity violations (fail fast) | VERIFIED | `loader.py` `validate_event_stream()` lines 58-128 — three checks (unknown proposal, double vote, out-of-window); raises `ValueError`; three `test_fail_fast_*` tests all pass |

**Score:** 16/16 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `apps/simulations/src/backtesting/data/schema.py` | Pydantic v2 event models, enums, GovernorDataLoader Protocol | VERIFIED | 143 lines — substantive, exports all required names |
| `apps/simulations/src/backtesting/weighting/signals.py` | Pure weighting functions — no cadCAD import | VERIFIED | 135 lines — lock_curve, compute_signals_weight, compute_legacy_weight, CurveType; no cadCAD/pandas imports confirmed |
| `apps/simulations/src/backtesting/data/factory.py` | Synthetic event stream generator | VERIFIED | 364 lines — generate_scenario, StakeProfile, LockProfile with all helper functions |
| `apps/simulations/src/backtesting/data/loader.py` | SyntheticLoader, ParquetLoader, events_to_dataframe, validate_event_stream | VERIFIED | 228 lines — all four exports present, Protocol assertion at module load time |
| `apps/simulations/src/backtesting/__init__.py` | Package init | VERIFIED | Exists |
| `apps/simulations/src/backtesting/data/__init__.py` | Re-exports all public names from schema, factory, loader | VERIFIED | 44 lines — full `__all__` with 14 exported names |
| `apps/simulations/src/backtesting/weighting/__init__.py` | Re-exports weighting functions | VERIFIED | Exists |
| `apps/simulations/tests/test_schema.py` | Tests for DATA-01, DATA-06 | VERIFIED | Substantive — 396 lines covering 8 test classes |
| `apps/simulations/tests/test_weighting.py` | Tests for WGHT-01 through WGHT-04 | VERIFIED | Substantive — 296 lines covering 9 test classes |
| `apps/simulations/tests/test_factory.py` | Tests for DATA-02 through DATA-08 | VERIFIED | Substantive — 281 lines covering 10 test functions |
| `apps/simulations/tests/test_loader.py` | Tests for DATA-05, DATA-09 | VERIFIED | Substantive — 244 lines covering 9 test functions |
| `apps/simulations/tests/conftest.py` | Shared fixtures for backtesting tests | VERIFIED | Backtesting fixtures present (default_scenario_config, small_scenario_config, sample_events, sample_dataframe) |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `weighting/signals.py` | `numpy` | `import numpy as np` | WIRED | Line 13: `import numpy as np`; used for sqrt, log1p, exp, clip |
| `data/schema.py` | `pydantic` | `from pydantic import BaseModel, field_validator, model_validator` | WIRED | Line 21 — all three imports present and used in validators |
| `data/factory.py` | `data/schema.py` | `from backtesting.data.schema import` | WIRED | Lines 21-28 — imports ProposalCreatedEvent, VoteCastEvent, ProposalFinalizedEvent, VoteSupport, GovernorEvent, EventType |
| `data/loader.py` | `data/schema.py` | `from backtesting.data.schema import` | WIRED | Line 28 — imports EventType, GovernorDataLoader, GovernorEvent |
| `data/loader.py` | `pandas` | `import pandas as pd` | WIRED | Line 26 — used in events_to_dataframe and validate_event_stream |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| DATA-01 | 03-01 | Governor-compatible event schema defines PROPOSAL_CREATED, VOTE_CAST, PROPOSAL_FINALIZED | SATISFIED | `schema.py` — three Pydantic v2 models with correct Governor Bravo field names |
| DATA-02 | 03-02 | Synthetic event stream generator produces configurable voter counts, proposal counts, participation rates | SATISFIED | `factory.py` `generate_scenario()` with n_voters, n_proposals, avg_participation_rate params |
| DATA-03 | 03-02 | Synthetic stake distribution follows Pareto (Gini >= 0.65) | SATISFIED | `_generate_stakes()` with pareto_alpha=0.7; Gini verified >= 0.65 across 5 seeds |
| DATA-04 | 03-02 | Synthetic vote timing follows tri-modal distribution | SATISFIED | `_generate_vote_timing()` — 30% early, 40% mid, 30% late; tested and verified |
| DATA-05 | 03-02 | Synthetic data enforces referential integrity (no double votes, no out-of-window votes) | SATISFIED | Factory: `seen_voters` set + block clamping. Loader: `validate_event_stream()` + fail fast on violation |
| DATA-06 | 03-01 | Pydantic v2 validates all event data at construction time | SATISFIED | `@field_validator` and `@model_validator(mode='after')` in all three models; 6 rejection cases tested |
| DATA-07 | 03-02 | User can select voter behavior profiles (power-law, uniform, bimodal stake distributions) | SATISFIED | `StakeProfile = Literal['pareto', 'uniform', 'bimodal']`; all three implemented and tested |
| DATA-08 | 03-02 | User can set a random seed for reproducible event stream generation | SATISFIED | `seed` parameter passed to `np.random.default_rng(seed)`; test_reproducibility confirms identical output |
| DATA-09 | 03-02 | Data loader interface supports swapping synthetic for real Governor data with zero architecture changes | SATISFIED | `GovernorDataLoader` Protocol structural typing — SyntheticLoader and ParquetLoader both satisfy without inheritance |
| WGHT-01 | 03-01 | Signals weight function computes W = stake x f(lock_duration) as pure function independent of cadCAD | SATISFIED | `compute_signals_weight()` = `stake * lock_curve(...)`; zero cadCAD import lines confirmed |
| WGHT-02 | 03-01 | Lock curve f(L) is parameterized and supports linear, log, sqrt, and exponential shapes | SATISFIED | `CurveType = Literal['sqrt', 'linear', 'log', 'exp']`; all four implemented with floor+scale normalization |
| WGHT-03 | 03-01 | Lock curve exhibits diminishing returns after ~3 months | SATISFIED | sqrt formula is concave; 30-day sequential deltas confirmed decreasing (d1>d2>d3>d4) |
| WGHT-04 | 03-01 | Legacy weight function computes W = stake (identity) for baseline comparison | SATISFIED | `compute_legacy_weight(stake) = float(stake)` — identity function confirmed across 5 stake values |

All 13 requirement IDs (DATA-01 through DATA-09, WGHT-01 through WGHT-04) claimed by plans 03-01 and 03-02 are satisfied. No orphaned requirements — REQUIREMENTS.md maps no additional IDs to Phase 3 beyond those claimed.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `tests/conftest.py` | 63 | `from cadcad.state import generate_initial_state` | Info | Pre-existing import from before Phase 3; does not affect backtesting modules. The backtesting source files (schema.py, signals.py, factory.py, loader.py) have zero cadCAD imports. Tests run successfully with this import present. |

No blockers or warnings. The cadCAD import in conftest.py is a pre-existing fixture for earlier cadCAD tests and is entirely separate from the Phase 3 backtesting layer. The key requirement (WGHT-01) is that `signals.py` has no cadCAD import — confirmed clean.

### Human Verification Required

None. All phase 3 verification items are programmatic (type checking, mathematical properties, test pass/fail). The layer operates headlessly without UI or external services.

### Test Results

```
100 passed in 0.11s
tests/test_schema.py:  31 tests — all pass
tests/test_weighting.py: 50 tests — all pass
tests/test_factory.py:  10 tests — all pass
tests/test_loader.py:    9 tests — all pass
```

### Summary

Phase 3 goal is fully achieved. The testable data and weighting layer:

1. **Is exercisable without cadCAD** — `signals.py` is a pure-function module; `schema.py`, `factory.py`, and `loader.py` have zero cadCAD imports. The full test suite of 100 tests passes in 0.11s with no cadCAD dependency.

2. **Has validated data structures** — Three Pydantic v2 event models enforce Governor Bravo field names and reject malformed events at construction time.

3. **Has a scientifically correct weighting layer** — `lock_curve()` returns values in [floor, 1.0] for all four shapes; sqrt exhibits confirmed diminishing returns; `compute_signals_weight` = stake * f(L) formula is wired end-to-end.

4. **Has realistic synthetic data generation** — `generate_scenario()` produces Pareto-distributed stakes (Gini >= 0.65), tri-modal vote timing, configurable profiles, and guaranteed referential integrity.

5. **Has a swappable loader interface** — `GovernorDataLoader` Protocol allows zero-architecture-change swap from synthetic to real on-chain data via structural typing.

---

_Verified: 2026-02-27T16:30:00Z_
_Verifier: Claude (gsd-verifier)_
