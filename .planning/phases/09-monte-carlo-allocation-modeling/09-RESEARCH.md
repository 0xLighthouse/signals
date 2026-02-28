# Phase 9: Monte Carlo Allocation Modeling - Research

**Researched:** 2026-02-28
**Domain:** NumPy SeedSequence, probability distributions, Python dataclasses
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Distribution Configuration**
- Beta distribution only in this phase (naturally bounded [0,1])
- `AllocationDistribution` type with `type='beta'`, `a`, `b` parameters
- Invalid parameters (a<=0, b<=0) raise `ValueError` immediately at construction time — no silent clamping
- One allocation fraction drawn per scenario (not per proposal) — matches current fixed-value semantics

**Seed & Reproducibility**
- Reproducibility guaranteed within same NumPy version only (no cross-version pinning)
- Use `np.random.SeedSequence(base_seed).spawn(n_samples)` for independent MC generators
- Per-sample spawned seeds included in output metadata — enables reproducing individual interesting samples
- Allocation RNG independent from vote-timing RNG (separate spawned generators) — changing allocation distribution doesn't affect vote-timing randomness
- If no base_seed provided, auto-generate one and log it in output metadata so runs are always reproducible after the fact

**Vote-Timing Parameters**
- `early_frac` and `mid_frac` exposed via a nested `VoteTimingConfig` object (not top-level params)
- API: `generate_scenario(vote_timing=VoteTimingConfig(early=0.3, mid=0.5))`
- Fail fast with `ValueError` if `early_frac + mid_frac > 1.0` (remaining is implicitly `late_frac`)

**Backward Compatibility**
- `generate_scenario()` without `mc_dist` must produce bit-identical output to v2.0 for the same seed
- SeedSequence spawning only activates when `mc_dist` is provided — old seed path untouched otherwise
- No snapshot regression test required — success criteria validation is sufficient

### Claude's Discretion

- `AllocationDistribution` type design (dataclass vs Pydantic model vs other — match codebase patterns)
- Whether `early_frac`/`mid_frac` are fixed floats or also support distributional draws in MC mode
- Default values for `early_frac`/`mid_frac` (match current `_generate_vote_timing` internals)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| MCAL-01 | Replace fixed allocation strategies with `rng.beta(a, b)` distribution draws parameterized by `AllocationDistribution` | `BetaDistribution.sample()` already exists in `budget.py`; integration into `generate_scenario()` via `mc_dist` param is the work |
| MCAL-02 | Use `np.random.SeedSequence(base_seed).spawn(n_samples)` for independent MC generators | Verified: SeedSequence children produce distinct RNG streams via `spawn_key`; `default_rng(child)` works correctly |
| MCAL-03 | `generate_scenario()` accepts optional `mc_dist` parameter for allocation distribution (backward compatible) | Two-RNG split (alloc_child + scenario_child via `parent.spawn(2)`) preserves backward compat when `mc_dist=None` |
| MCAL-04 | MC runner produces N independent samples per configuration with distinct seeds | New `backtesting/mc.py` module; uses `SeedSequence(base_seed).spawn(n_samples)` + metadata per sample |
| MCAL-05 | Expose `early_frac`/`mid_frac` vote-timing parameters through `generate_scenario()` | `_generate_vote_timing` already accepts these params; thread via new `VoteTimingConfig` dataclass |
</phase_requirements>

## Summary

Phase 9 wires the `AllocationDistribution` hierarchy (already built in Phase 8's `budget.py`) into `generate_scenario()` and introduces a new MC runner. The core technical work is: (1) adding an optional `mc_dist` parameter to `generate_scenario()` that activates a two-RNG architecture — one RNG for allocation draws, one for everything else — using `SeedSequence.spawn(2)` for independence; (2) adding a `VoteTimingConfig` dataclass and wiring `early_frac`/`mid_frac` through to `_generate_vote_timing`; and (3) creating a new `backtesting/mc.py` module that runs N scenarios with independent seeds derived from `SeedSequence(base_seed).spawn(n_samples)`.

NumPy 1.26.4 (pinned in `pyproject.toml`) fully supports `SeedSequence.spawn()`. The `BetaDistribution`, `UniformDistribution`, and `TruncnormDistribution` classes are already implemented and validated. The entire codebase uses the `dataclass` pattern for internal config objects (see `budget.py`, `pipeline.py`), making `VoteTimingConfig` a straightforward addition. The backward-compatibility constraint is the sharpest risk: `generate_scenario()` currently uses a single `rng = np.random.default_rng(seed)` for all draws; splitting into two RNGs when `mc_dist` is provided must leave the `mc_dist=None` path completely unchanged.

The MC runner outputs a list of `MCSample` result objects, each containing events, metadata (per-sample seed for reproduction), and the drawn allocation fraction. This structure prepares for Phase 10's sweep engine, which will consume `MCResult` objects.

**Primary recommendation:** Implement in two tasks: Task 1 extends `generate_scenario()` + adds `VoteTimingConfig`; Task 2 builds `backtesting/mc.py` runner. Tests go in Task 3 against `tests/test_mc.py`.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `numpy` | 1.26.4 (pinned) | `SeedSequence.spawn()`, `default_rng()`, `rng.beta()` | Already the project RNG — do not introduce alternatives |
| `dataclasses` (stdlib) | Python 3.12 stdlib | `VoteTimingConfig`, `MCSample`, `MCResult` dataclasses | Established pattern in `budget.py` and `pipeline.py` |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `scipy.stats` | 1.13.0+ | `TruncnormDistribution.sample()` (already implemented) | Only for `TruncnormDistribution` — do not add new scipy usage |
| `typing` (stdlib) | Python 3.12 stdlib | `Literal`, `dataclass` type annotations | Already used throughout |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `np.random.SeedSequence` | `np.random.default_rng(seed + i)` | NEVER: correlated streams — see Common Pitfalls |
| `dataclass` for VoteTimingConfig | `Pydantic BaseModel` | Pydantic is only used for schema events (network-facing); internal configs use dataclass |

**Installation:** No new packages needed. All required libraries are already in `pyproject.toml`.

## Architecture Patterns

### Recommended Project Structure
```
apps/simulations/src/backtesting/
├── data/
│   ├── budget.py          # AllocationDistribution hierarchy (Phase 8, DONE)
│   └── factory.py         # generate_scenario() — add mc_dist + vote_timing params HERE
├── mc.py                  # NEW: MC runner module (MCAL-04)
└── simulation/
    └── runner.py          # Unchanged
```

### Pattern 1: Two-RNG Split in generate_scenario()

**What:** When `mc_dist` is provided, spawn two independent RNG streams from the base seed using `SeedSequence.spawn(2)`: one for allocation fraction draws, one for the rest of the scenario.

**When to use:** Only when `mc_dist` is not None. The `mc_dist=None` path remains `rng = np.random.default_rng(seed)` — unchanged.

**Example:**
```python
# Source: verified in project venv (numpy 1.26.4)
def generate_scenario(
    ...,
    mc_dist: AllocationDistribution | None = None,
    vote_timing: VoteTimingConfig | None = None,
) -> list[GovernorEvent]:
    if mc_dist is not None:
        if seed is None:
            parent_ss = np.random.SeedSequence()
            effective_seed = parent_ss.entropy  # log this in metadata
        else:
            parent_ss = np.random.SeedSequence(seed)
            effective_seed = seed
        alloc_child, scenario_child = parent_ss.spawn(2)
        alloc_rng = np.random.default_rng(alloc_child)
        rng = np.random.default_rng(scenario_child)
        # Draw ONE allocation fraction for the entire scenario
        alloc_frac = float(mc_dist.sample(alloc_rng, 1)[0])
    else:
        # UNCHANGED: backward-compatible path
        rng = np.random.default_rng(seed)
        alloc_frac = None  # uses compute_allocation_fraction() as before
```

### Pattern 2: SeedSequence.spawn() for MC Runner

**What:** `SeedSequence.spawn(n_samples)` produces N children with distinct `spawn_key`s. Passing each child directly to `np.random.default_rng()` produces N statistically independent RNG streams.

**When to use:** In the MC runner to produce N independent scenarios.

**Example:**
```python
# Source: verified in project venv (numpy 1.26.4)
import numpy as np

def run_mc_samples(config: dict, mc_dist: AllocationDistribution,
                   n_samples: int = 50, base_seed: int | None = None) -> 'MCResult':
    if base_seed is None:
        ss = np.random.SeedSequence()
        base_seed = ss.entropy  # log for reproducibility
    else:
        ss = np.random.SeedSequence(base_seed)

    children = ss.spawn(n_samples)
    samples = []
    for i, child in enumerate(children):
        # generate_state(1)[0] produces a unique int for metadata
        sample_seed = int(child.generate_state(1)[0])
        events = generate_scenario(**config, seed=child, mc_dist=mc_dist)
        samples.append(MCSample(
            index=i,
            seed=sample_seed,  # for output metadata
            events=events,
        ))
    return MCResult(base_seed=base_seed, samples=samples)
```

**Key detail:** `child.entropy` is the same for all children (the parent's base seed). Distinctness comes from `child.spawn_key`. Use `child.generate_state(1)[0]` to derive a unique int for metadata.

### Pattern 3: VoteTimingConfig Dataclass

**What:** Wraps `early_frac` and `mid_frac` with validation. Defaults match current `_generate_vote_timing` internals (`early=0.30`, `mid=0.40`).

**Example:**
```python
# Source: inferred from factory.py _generate_vote_timing defaults
from dataclasses import dataclass

@dataclass
class VoteTimingConfig:
    """Vote timing fraction configuration. late_frac = 1 - early - mid."""
    early: float = 0.30
    mid: float = 0.40

    def __post_init__(self) -> None:
        if self.early + self.mid > 1.0:
            raise ValueError(
                f'early_frac + mid_frac must be <= 1.0, '
                f'got {self.early} + {self.mid} = {self.early + self.mid}'
            )
        if self.early < 0 or self.mid < 0:
            raise ValueError('early_frac and mid_frac must be >= 0')
```

### Pattern 4: Using mc_dist in budget allocation loop

**What:** When `alloc_frac` is pre-drawn (from mc_dist), skip `compute_allocation_fraction()` and use the pre-drawn value directly in the budget allocation loop.

**Example:**
```python
# In generate_scenario's per-proposal voter loop:
if budget_enabled:
    available = ledgers[voter_idx].available_balance(vote_block)
    if available <= 0.0:
        continue

    if alloc_frac is not None:
        # MC mode: use pre-drawn fraction
        frac = alloc_frac
    else:
        # Legacy mode: compute per-voter fraction (unchanged)
        frac = compute_allocation_fraction(
            allocation_strategy, lock_days, l_max_days, rng
        )
    allocated = available * frac
```

### Anti-Patterns to Avoid

- **Calling `default_rng(seed + i)` per sample:** Produces correlated streams. `SeedSequence.spawn()` is the correct pattern — see Common Pitfalls.
- **Using `child.entropy` as the per-sample metadata seed:** All children share the parent's entropy. Use `child.generate_state(1)[0]` for a unique int.
- **Modifying the `mc_dist=None` code path:** The backward-compat contract requires bit-identical output. Any change to the `else` branch breaks this.
- **Drawing allocation fraction per proposal (not per scenario):** CONTEXT.md locked: one draw per scenario, not per proposal. The pre-drawn `alloc_frac` is used for every voter in every proposal.
- **Placing VoteTimingConfig in budget.py:** It's a factory concern, not a budget concern. Define in `factory.py` or a new `config.py` alongside factory.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Independent RNG streams | custom hash/offset per sample | `np.random.SeedSequence.spawn()` | Cryptographically independent; stdlib; already used in requirements |
| Beta-bounded sampling | manual rejection sampling | `rng.beta(a, b)` from `BetaDistribution.sample()` | Already implemented in `budget.py`; naturally bounded [0,1] |
| Entropy generation for auto-seed | `uuid` or `os.urandom` | `np.random.SeedSequence().entropy` | Returns reproducible large int that can seed a new SeedSequence exactly |

**Key insight:** The entire distribution hierarchy is already built. Phase 9 is integration work, not implementation of new mathematical primitives.

## Common Pitfalls

### Pitfall 1: `default_rng(seed + i)` for multiple samples
**What goes wrong:** Samples appear independent but have correlated structures — particularly in low-dimensional draws.
**Why it happens:** Arithmetic offsets on seeds don't guarantee statistical independence.
**How to avoid:** Use `np.random.SeedSequence(base_seed).spawn(n_samples)` exclusively. Pass each child directly to `default_rng()`.
**Warning signs:** If MC samples produce allocation fractions that visually cluster, this is the likely cause.

### Pitfall 2: Breaking backward compatibility in generate_scenario()
**What goes wrong:** Adding `mc_dist` parameter changes the internal RNG call sequence even for `mc_dist=None` callers, producing different outputs for the same seed.
**Why it happens:** Any code added before `rng = np.random.default_rng(seed)` — even a type check — can shift state if it accidentally touches a global RNG.
**How to avoid:** The `mc_dist=None` branch must contain exactly the same code as today, with the new `mc_dist` branch completely isolated behind `if mc_dist is not None:`.
**Warning signs:** `test_reproducibility` in `test_factory.py` will fail.

### Pitfall 3: SeedSequence child entropy is not unique
**What goes wrong:** Logging `child.entropy` in per-sample metadata records the same value for all samples.
**Why it happens:** All children share the parent's entropy value; uniqueness is in `spawn_key`, not `entropy`.
**How to avoid:** Use `int(child.generate_state(1)[0])` to derive a unique reproducible int per sample. Store this in `MCSample.seed`.
**Warning signs:** All samples show the same seed in output metadata.

### Pitfall 4: vote_timing validation off by precision
**What goes wrong:** `early_frac + mid_frac > 1.0` fails to catch `0.5 + 0.5 = 1.0` (valid) vs `0.6 + 0.5 = 1.1` (invalid) due to floating point.
**Why it happens:** Strict `> 1.0` check handles float addition naturally (1.0 + epsilon triggers it).
**How to avoid:** Use strict `>` not `>=`. `early + mid == 1.0` means `late_frac == 0.0`, which is valid (no late votes).
**Warning signs:** Tests rejecting valid `early=0.5, mid=0.5` inputs.

### Pitfall 5: N=50 performance unknowns
**What goes wrong:** 50 full cadCAD simulation runs per MC batch may be too slow for development iteration.
**Why it happens:** Phase 9 scope is unclear on whether the MC runner calls just `generate_scenario()` or the full `run_backtest()` + metrics pipeline.
**How to avoid:** Scope the MC runner to `generate_scenario()` only in Phase 9. The full pipeline integration belongs to Phase 10. Flag if SC2 test (50 samples) runs too slowly.
**Warning signs:** `run_mc_samples` test takes >30s. Phase 9 flag from STATE.md: "N=50 MC samples per config feasibility unknown without profiling — validate during Phase 9 execution."

## Code Examples

Verified patterns from codebase + project venv:

### Generating 50 independent Beta(2,5) allocation fractions
```python
# Source: verified in project venv, numpy 1.26.4
import numpy as np
from backtesting.data.budget import BetaDistribution

dist = BetaDistribution(a=2, b=5)
base_seed = 42
n_samples = 50

children = np.random.SeedSequence(base_seed).spawn(n_samples)
rngs = [np.random.default_rng(c) for c in children]

# One fraction per sample
fracs = [float(dist.sample(rng, 1)[0]) for rng in rngs]
# All distinct:
assert len(set(round(f, 10) for f in fracs)) == n_samples  # True
```

### Verifying allocation RNG independence from scenario RNG
```python
# Source: verified in project venv, numpy 1.26.4
import numpy as np

parent = np.random.SeedSequence(42)
alloc_child, scenario_child = parent.spawn(2)

alloc_rng = np.random.default_rng(alloc_child)
scenario_rng = np.random.default_rng(scenario_child)

# These are independent streams:
alloc_draw = alloc_rng.beta(2, 5)     # 0.098...
scenario_draw = scenario_rng.uniform() # 0.570...
assert alloc_draw != scenario_draw     # True
```

### Auto-seed with logging for reproducibility
```python
# Source: verified in project venv, numpy 1.26.4
import numpy as np

ss = np.random.SeedSequence()  # no seed = auto-generate
base_seed = ss.entropy         # large int, e.g. 152939142...
# Log base_seed -> user can reproduce by passing it back as seed=base_seed
```

### Deriving unique per-sample metadata seed from SeedSequence child
```python
# Source: verified in project venv, numpy 1.26.4
import numpy as np

children = np.random.SeedSequence(42).spawn(5)
# WRONG: child.entropy is same for all (= 42)
# CORRECT: generate_state produces unique ints
metadata_seeds = [int(c.generate_state(1)[0]) for c in children]
# [2684470948, 4091952314, 233227757, 3276785861, 3644269654]
assert len(set(metadata_seeds)) == 5  # True
```

### Current _generate_vote_timing defaults (for VoteTimingConfig)
```python
# Source: factory.py line 103-104
# early_frac: float = 0.30  (30% early votes)
# mid_frac: float = 0.40    (40% mid votes)
# late_frac = 0.30 (implicit)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `np.random.seed()` global seeding | `np.random.default_rng(seed)` per-generator | NumPy 1.17 | Non-global, reproducible |
| Arithmetic seed offsets (`seed + i`) | `SeedSequence.spawn(n)` | NumPy 1.17 | Cryptographically independent streams |
| `np.random.beta()` (legacy) | `rng.beta(a, b)` on Generator instance | NumPy 1.17 | No global state |

**Deprecated/outdated:**
- `np.random.seed()` / `np.random.beta()`: Legacy global API. Never use in new code — codebase already uses `default_rng()`.
- Arithmetic seed derivation (`seed + i`): Statistically unsafe. Replaced by `SeedSequence.spawn()`.

## Open Questions

1. **MC runner output scope: events-only or full pipeline?**
   - What we know: MCAL-04 says "N independent samples per configuration" — not "N pipeline results"
   - What's unclear: Does the MC runner call `run_backtest()` + metrics, or just `generate_scenario()`?
   - Recommendation: Scope to `generate_scenario()` only in Phase 9. Phase 10 sweep engine will run the full pipeline. `MCSample` contains `events: list[GovernorEvent]` + metadata. This keeps Phase 9 fast and focused.

2. **Where does `VoteTimingConfig` live?**
   - What we know: It's used in `generate_scenario()` in `factory.py`. Codebase puts event schemas in `schema.py`, budget configs in `budget.py`.
   - What's unclear: Should it go in `factory.py` (local to its only user) or a new `config.py`?
   - Recommendation: Define `VoteTimingConfig` in `factory.py` alongside `generate_scenario()`. If Phase 10 needs it, promote to `config.py` then.

3. **MC runner module location**
   - What we know: It's a peer to `pipeline.py` (not a simulation sub-module), producing output consumable by Phase 10 sweep
   - Recommendation: `backtesting/mc.py` — top-level backtesting module alongside `pipeline.py` and `metrics.py`

4. **`early_frac`/`mid_frac`: fixed floats or distributional in MC mode?**
   - What we know: CONTEXT.md marks this as Claude's Discretion
   - Recommendation: Fixed floats only in Phase 9. `VoteTimingConfig(early=0.3, mid=0.5)` takes scalar values. Distributional timing is marked as MCAL-F03 (v3.1 future requirement).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | pytest 8.x |
| Config file | `pyproject.toml` (no `[tool.pytest]` section — uses defaults) |
| Quick run command | `cd apps/simulations && .venv/bin/python -m pytest tests/test_factory.py tests/test_mc.py -q` |
| Full suite command | `cd apps/simulations && .venv/bin/python -m pytest tests/ -q` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MCAL-01 | `generate_scenario(mc_dist=BetaDistribution(2,5))` draws Beta fractions, not uniform | unit | `pytest tests/test_factory.py::test_mcal01_mc_dist_draws_from_beta -x` | ❌ Wave 0 |
| MCAL-02 | 50 samples same base_seed → 50 distinct allocation sequences | unit | `pytest tests/test_mc.py::test_mcal02_independent_sequences -x` | ❌ Wave 0 |
| MCAL-03 | `generate_scenario()` without `mc_dist` = bit-identical to v2.0 | unit | `pytest tests/test_factory.py::test_mcal03_backward_compat -x` | ❌ Wave 0 |
| MCAL-04 | MC runner produces N samples with distinct seeds in metadata | unit | `pytest tests/test_mc.py::test_mcal04_mc_runner_distinct_seeds -x` | ❌ Wave 0 |
| MCAL-05 | `generate_scenario(vote_timing=VoteTimingConfig(early=0.3, mid=0.5))` changes timing | unit | `pytest tests/test_factory.py::test_mcal05_vote_timing_config -x` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `cd apps/simulations && .venv/bin/python -m pytest tests/test_factory.py tests/test_mc.py -q --tb=short`
- **Per wave merge:** `cd apps/simulations && .venv/bin/python -m pytest tests/ -q`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/test_mc.py` — covers MCAL-02, MCAL-04 (new MC runner module)
- [ ] New test functions in `tests/test_factory.py` — covers MCAL-01, MCAL-03, MCAL-05

*(Existing test infrastructure: pytest 8.x with conftest.py, no framework install needed)*

## Sources

### Primary (HIGH confidence)
- Codebase direct inspection — `budget.py`, `factory.py`, `pipeline.py`, `tests/test_factory.py`, `tests/conftest.py`
- NumPy 1.26.4 venv execution — all SeedSequence patterns verified with `apps/simulations/.venv/bin/python`
- `apps/simulations/pyproject.toml` — confirmed numpy==1.26.4, pytest==8.x, scipy==1.13.x

### Secondary (MEDIUM confidence)
- `.planning/REQUIREMENTS.md` — MCAL-01 through MCAL-05 descriptions and research annotations
- `.planning/STATE.md` — Phase 9 flag: "N=50 MC samples per config feasibility unknown without profiling"

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries verified in project venv; no new dependencies needed
- Architecture: HIGH — patterns verified by running code against actual project venv + codebase inspection
- Pitfalls: HIGH — backward compat and SeedSequence pitfalls verified empirically

**Research date:** 2026-02-28
**Valid until:** 2026-03-28 (stable numpy API, no fast-moving dependencies)
