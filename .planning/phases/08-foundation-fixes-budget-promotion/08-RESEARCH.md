# Phase 8: Foundation Fixes & Budget Promotion - Research

**Researched:** 2026-02-28
**Domain:** Python module refactoring — NumPy NaN semantics, dataclass class hierarchies, parameter threading
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### budget.py Public API
- Class-based API: VoterLedger as a public class (promoted from _VoterLedger)
- VoterLedger is mutable, accumulates vote records over time (matches current behavior)
- compute_allocation_fraction is a standalone public function, not a VoterLedger method — keeps it composable for Phase 9's MC sampling
- budget.py is a leaf module: only imports numpy/stdlib, no internal backtesting imports — maximum testability and reusability

#### AllocationDistribution Design
- Class hierarchy with base class, not a single discriminated dataclass
- Three concrete subclasses: BetaDistribution, UniformDistribution, TruncnormDistribution
- Each subclass has a .sample(rng, size) method that knows how to draw from itself
- Parameters validated on construction (e.g., Beta a,b > 0) — fail fast with clear errors before any simulation runs

#### NaN Propagation Strategy
- _gini() returns np.nan for zero-sum arrays, _enp() returns np.nan for zero-weight arrays
- NaN propagates silently through downstream metrics — no logging, no warnings (NaN is a valid expected result for zero-participation proposals)
- Add explicit edge-case tests for zero-sum gini and zero-weight enp as regression tests
- Establish NaN-for-degenerate-inputs as a documented convention for all metric functions (sets pattern for Phase 11 extended analysis)

#### curve_type Threading
- Represented as Literal['sqrt', 'log', 'linear'] — string literals, not Enum
- Default value is 'sqrt' (backward-compatible with current hardcoded behavior)
- Three curve types supported: sqrt, log, linear (linear is trivial to add and completes the sweep comparison set)
- Validated at the generate_scenario() boundary — fail fast before any work starts, clear error listing valid types

### Claude's Discretion
- Internal organization of budget.py (method ordering, helper functions)
- Exact VoterLedger method signatures beyond what's specified
- How factory.py delegates to the new budget.py module
- Test file organization for new edge-case tests

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| BUDG-01 | Promote `_VoterLedger` and `_compute_allocation_fraction` to public `backtesting/data/budget.py` module | Module extraction pattern: copy classes to budget.py, make public (remove underscore prefix), update factory.py to import from budget.py, update backtesting/data/__init__.py exports |
| BUDG-02 | Fix `_gini()` to return `np.nan` for zero-sum arrays instead of `0.0` | One-line guard change: `if n == 0 or arr.sum() == 0: return np.nan` — confirmed correct NumPy behavior |
| BUDG-03 | Fix `_enp()` to return `np.nan` for zero-weight arrays instead of `0.0` | One-line guard change: `if total == 0: return np.nan` — test_enp asserts `enp >= 1.0`, which must be updated |
| BUDG-04 | Thread `curve_type` as a parameter through `generate_scenario()` → metrics computation | generate_scenario() gains `curve_type` param; sufs.py `suf_tallies` must pass curve_type to `compute_signals_weight`; pipeline.py _GENERATE_SCENARIO_KEYS must include it |
| BUDG-05 | Add `AllocationDistribution` dataclass to `budget.py` supporting Beta/truncnorm/uniform | Class hierarchy in budget.py — BetaDistribution, UniformDistribution, TruncnormDistribution each with `.sample(rng, size)` |
| BUDG-06 | All existing tests pass after budget promotion refactor | 147 tests currently pass; test_factory.py imports `_VoterLedger` directly (must be updated); no test currently covers curve_type threading or NaN returns |
</phase_requirements>

---

## Summary

Phase 8 is a pure Python refactoring and bug-fix phase with no new external dependencies. The work divides cleanly into three concerns: (1) two one-line NaN fixes in `metrics.py`, (2) a module promotion refactoring that moves `_VoterLedger`/`_compute_allocation_fraction` from `factory.py` into a new public `budget.py` with a new `AllocationDistribution` class hierarchy, and (3) threading `curve_type` through the call stack from `generate_scenario()` down to `compute_signals_weight()` via `suf_tallies` in `sufs.py`.

The critical risk for BUDG-06 (all 147 tests pass) is that `test_factory.py` already imports `_VoterLedger` and `BLOCKS_PER_DAY` directly from `backtesting.data.factory`. After promotion, `_VoterLedger` disappears from factory.py — this test must be updated to import `VoterLedger` from `backtesting.data.budget`. Additionally, `test_metrics.py` asserts `enp >= 1.0` for every proposal — once `_enp()` returns `np.nan` for zero-weight arrays, NaN comparisons will fail (`nan >= 1.0` is False in Python). The test fixtures use a non-degenerate scenario that should never produce zero-weight groups, but this must be verified.

The `curve_type` threading requires surgical changes in three files: `factory.py` (add parameter + validation), `sufs.py` (thread through to `compute_signals_weight`), and `pipeline.py` (add to `_GENERATE_SCENARIO_KEYS`). The `CurveType` literal type already exists in `weighting/signals.py` and already supports `sqrt`, `log`, `linear`, and `exp` — CONTEXT.md locks the supported set to `['sqrt', 'log', 'linear']` only, so the generate_scenario boundary validation must explicitly reject `exp`.

**Primary recommendation:** Execute in three independent waves — (Wave 1) NaN fixes + regression tests, (Wave 2) budget.py module promotion + AllocationDistribution, (Wave 3) curve_type threading + pipeline integration — each wave ending with a full test run.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| numpy | >=1.26.4,<2 (pinned in pyproject.toml) | NaN constants, array ops | Already a direct dependency; `np.nan` is the canonical IEEE 754 sentinel |
| pytest | >=8.0.0,<9 (pinned in pyproject.toml) | Test runner | Already the project test framework |
| dataclasses (stdlib) | Python 3.12 stdlib | AllocationDistribution base class + subclasses | Zero-dependency, matches existing frozen dataclass patterns in metrics.py |
| abc (stdlib) | Python 3.12 stdlib | Abstract base class for AllocationDistribution | Enforces `.sample()` contract on subclasses |
| scipy.stats | >=1.13.0,<2 (pinned in pyproject.toml) | `truncnorm.rvs()` for TruncnormDistribution.sample() | Already a direct dependency; used by Phase 9 MC sampling |
| typing.Literal | Python 3.12 stdlib | CurveType annotation | Already used in signals.py for CurveType |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| abc.abstractmethod | stdlib | Enforce .sample() on AllocationDistribution subclasses | Use on the base class `.sample()` method to make it abstract |
| math.isnan | stdlib | NaN checks in tests | Use `math.isnan()` in test assertions — already used in test_metrics.py for NaN-tolerant checks |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Abstract base class for AllocationDistribution | Single discriminated dataclass with `dist_type: Literal[...]` | CONTEXT.md locks to class hierarchy — each subclass owns its `.sample()` logic, enabling Phase 9 to call `.sample()` without conditionals |
| `np.nan` return in `_gini()/_enp()` | Raising ValueError | NaN-as-sentinel is the documented project convention for degenerate inputs; calling code uses `np.nanmean()` etc. already |
| Literal['sqrt','log','linear'] in generate_scenario | Importing CurveType from weighting.signals | Literal in generate_scenario signature avoids circular imports since budget.py must be a leaf module; CurveType in signals.py supports 'exp' which is out of scope here |

---

## Architecture Patterns

### Recommended Project Structure

After Phase 8, the `backtesting/data/` directory becomes:

```
src/backtesting/data/
├── __init__.py       # exports updated to include VoterLedger, AllocationDistribution, compute_allocation_fraction
├── budget.py         # NEW: VoterLedger, LockEntry, AllocationDistribution hierarchy, compute_allocation_fraction
├── factory.py        # MODIFIED: imports VoterLedger/compute_allocation_fraction from budget; gains curve_type param
├── loader.py         # UNCHANGED
└── schema.py         # UNCHANGED
```

The `sufs.py` threading path:

```
sufs.py (suf_tallies)
  └── compute_signals_weight(stake, lock_days, curve_type=curve_type)
        └── lock_curve(lock_duration_days, curve_type, ...)
```

The `curve_type` flows from `generate_scenario(curve_type=...)` → cadCAD params `M` dict → `suf_tallies` reads `params['curve_type']`.

### Pattern 1: Module Promotion (BUDG-01)

**What:** Rename `_VoterLedger` → `VoterLedger`, `_LockEntry` → `LockEntry`, `_compute_allocation_fraction` → `compute_allocation_fraction`; move them to `budget.py`; have `factory.py` import from `budget.py`.

**When to use:** Private internals that need public testability and reuse.

**Example:**

```python
# budget.py — leaf module, no internal backtesting imports
import numpy as np
from dataclasses import dataclass, field
from typing import Literal

AllocationStrategy = Literal['uniform_fraction', 'conviction_weighted', 'aggressive']

@dataclass
class LockEntry:
    """A single token lock: amount locked until unlock_block."""
    amount: float
    unlock_block: int

@dataclass
class VoterLedger:
    """Tracks a voter's total stake and active locks for budget allocation."""
    total_stake: float
    locks: list[LockEntry] = field(default_factory=list)

    def available_balance(self, at_block: int) -> float:
        locked = sum(lock.amount for lock in self.locks if lock.unlock_block > at_block)
        return max(0.0, self.total_stake - locked)

    def add_lock(self, amount: float, unlock_block: int) -> None:
        self.locks.append(LockEntry(amount=amount, unlock_block=unlock_block))

def compute_allocation_fraction(
    strategy: AllocationStrategy,
    lock_duration_days: float,
    l_max_days: float,
    rng: 'np.random.Generator',
) -> float:
    """Return the fraction of available balance a voter commits to one proposal."""
    ...
```

```python
# factory.py — updated imports
from backtesting.data.budget import (
    VoterLedger,
    LockEntry,
    AllocationStrategy,
    compute_allocation_fraction,
)
```

### Pattern 2: AllocationDistribution Class Hierarchy (BUDG-05)

**What:** Abstract base class + three concrete subclasses in `budget.py`. Each owns its `.sample()` implementation.

**When to use:** When Phase 9 needs to draw samples without knowing which distribution was configured.

**Example:**

```python
from abc import ABC, abstractmethod
import numpy as np
from scipy import stats

class AllocationDistribution(ABC):
    """Abstract base: knows how to sample allocation fractions in [0, 1]."""

    @abstractmethod
    def sample(self, rng: np.random.Generator, size: int) -> np.ndarray:
        """Draw `size` allocation fractions. Returns ndarray of shape (size,)."""
        ...

@dataclass
class BetaDistribution(AllocationDistribution):
    """Beta(a, b) distribution bounded to [0, 1]."""
    a: float
    b: float

    def __post_init__(self) -> None:
        if self.a <= 0 or self.b <= 0:
            raise ValueError(f'BetaDistribution requires a > 0, b > 0, got a={self.a}, b={self.b}')

    def sample(self, rng: np.random.Generator, size: int) -> np.ndarray:
        return rng.beta(self.a, self.b, size=size)

@dataclass
class UniformDistribution(AllocationDistribution):
    """Uniform(low, high) distribution."""
    low: float = 0.15
    high: float = 0.45

    def __post_init__(self) -> None:
        if self.low >= self.high:
            raise ValueError(f'UniformDistribution requires low < high, got {self.low}, {self.high}')

    def sample(self, rng: np.random.Generator, size: int) -> np.ndarray:
        return rng.uniform(self.low, self.high, size=size)

@dataclass
class TruncnormDistribution(AllocationDistribution):
    """Truncated normal distribution clipped to [clip_low, clip_high]."""
    mean: float = 0.35
    std: float = 0.15
    clip_low: float = 0.0
    clip_high: float = 1.0

    def sample(self, rng: np.random.Generator, size: int) -> np.ndarray:
        a = (self.clip_low - self.mean) / self.std
        b = (self.clip_high - self.mean) / self.std
        return stats.truncnorm.rvs(a, b, loc=self.mean, scale=self.std,
                                   size=size, random_state=rng)
```

### Pattern 3: NaN Fix (BUDG-02/03)

**What:** Replace the `return 0.0` branch in `_gini()` and `_enp()` with `return np.nan`.

**When to use:** Any metric helper that receives a degenerate (zero-weight) input — the NaN-for-degenerate convention must be documented in `metrics.py` at the module level for Phase 11 implementers.

**Example:**

```python
def _gini(arr: np.ndarray) -> float:
    """Standard Gini coefficient for a 1-D array of non-negative values.

    Returns np.nan for zero-sum arrays (NaN-for-degenerate convention —
    zero participation is a valid but degenerate case, not 'perfect equality').
    """
    arr = np.sort(arr.astype(float))
    n = len(arr)
    if n == 0 or arr.sum() == 0:
        return np.nan   # CHANGED from 0.0
    idx = np.arange(1, n + 1)
    return float((2 * (idx * arr).sum()) / (n * arr.sum()) - (n + 1) / n)

def _enp(weights: np.ndarray) -> float:
    """Effective Number of Parties — ENP = 1 / sum(s_i^2).

    Returns np.nan for zero-weight arrays (NaN-for-degenerate convention).
    """
    total = weights.sum()
    if total == 0:
        return np.nan   # CHANGED from 0.0
    shares = weights / total
    return float(1.0 / (shares ** 2).sum())
```

### Pattern 4: curve_type Threading (BUDG-04)

**What:** Add `curve_type` param to `generate_scenario()`, pass it through cadCAD `M` params dict, read it in `suf_tallies` and forward to `compute_signals_weight`.

**When to use:** Any simulation parameter that must vary across sweep cells.

**Example — generate_scenario signature:**

```python
ScenarioCurveType = Literal['sqrt', 'log', 'linear']

def generate_scenario(
    ...
    curve_type: ScenarioCurveType = 'sqrt',  # new param — default preserves backward compat
    ...
) -> list[GovernorEvent]:
    # Validate at boundary
    _VALID_CURVE_TYPES = ('sqrt', 'log', 'linear')
    if curve_type not in _VALID_CURVE_TYPES:
        raise ValueError(
            f"curve_type={curve_type!r} is not valid. Must be one of: {_VALID_CURVE_TYPES}"
        )
    ...
```

**Example — sufs.py suf_tallies threaded:**

```python
def suf_tallies(params, substep, state_history, prev_state, policy_input):
    ...
    curve_type = params.get('curve_type', 'sqrt')  # read from cadCAD M params
    ...
    tallies[pid]['signals'][support] += compute_signals_weight(stake, lock_days, curve_type=curve_type)
    ...
```

**Example — runner.py run_backtest updated:**

```python
# run_backtest gains optional curve_type param or reads from M dict
# The cleanest approach: factory passes curve_type into the event stream
# as a simulation-level parameter via cadCAD M dict
config_sim({'T': range(n_events), 'N': 1, 'M': {
    'event_stream': tuple(event_records),
    'curve_type': curve_type,  # new key
}})
```

> Note: cadCAD M params are broadcast to every SUF via the `params` dict. Adding `curve_type` to M makes it available in `suf_tallies` without structural changes to PSUBS.

**Alternative (simpler, avoids cadCAD M threading):** Pass `curve_type` directly through the Python call chain: `run_backtest(events, curve_type='log')` → `runner.py` stores it → passes to `build_results_dataframe()` or directly into SUF construction. However, this requires modifying PSUBS which couples tightly to cadCAD internals. The M dict approach is cleaner for cadCAD's architecture.

**Recommendation:** Use the cadCAD M dict approach — it is the standard cadCAD pattern for sweep parameters and aligns with Phase 10's sweep runner design.

### Anti-Patterns to Avoid

- **Don't import backtesting internals in budget.py**: budget.py must be a leaf module (only numpy/stdlib/scipy). Importing from `backtesting.data.schema` or `backtesting.simulation` would break the Phase 9 MC composability.
- **Don't rename _LockEntry without updating test_factory.py**: `test_factory.py::TestBudgetAllocation::test_zero_balance_voters_skipped` imports `_VoterLedger` directly. This test MUST be updated to use the public name.
- **Don't forget to update _GENERATE_SCENARIO_KEYS in pipeline.py**: If `curve_type` is added to `generate_scenario()` but not to `_GENERATE_SCENARIO_KEYS`, pipeline config will silently ignore the curve_type key from TOML.
- **Don't skip the ENP test assertion update**: After the `_enp()` NaN fix, the existing `test_enp` assertion `assert enp_val >= 1.0` will fail for NaN results (`nan >= 1.0` is False in Python). The fixture uses a non-degenerate scenario, but the assertion must use `math.isnan(enp_val) or enp_val >= 1.0`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Truncated normal sampling | Custom rejection sampling loop | `scipy.stats.truncnorm.rvs()` | Already a direct dep; handles edge cases (very narrow bands, extreme truncation) |
| Abstract interface enforcement | Runtime isinstance checks | `abc.ABC` + `@abstractmethod` | Zero cost, raises TypeError at instantiation rather than at call time |
| NaN detection in tests | `val != val` | `math.isnan(val)` | Readable, already used in test_metrics.py |

**Key insight:** This phase is entirely internal Python refactoring. There are no new library dependencies to add.

---

## Common Pitfalls

### Pitfall 1: test_enp NaN assertion failure

**What goes wrong:** After `_enp()` returns `np.nan` for zero-weight arrays, `test_metrics.py::test_enp` asserts `enp_val >= 1.0` for every proposal. `nan >= 1.0` evaluates to `False` in Python — the test fails even though the non-degenerate fixture never actually produces zero-weight proposals.

**Why it happens:** The test was written before the NaN convention existed. The assertion didn't need a NaN guard because `_enp()` returned `0.0` which simply failed `>= 1.0` anyway.

**How to avoid:** Update the assertion to: `assert math.isnan(enp_val) or enp_val >= 1.0`

**Warning signs:** Test failure message: `AssertionError: legacy ENP[...] = nan < 1.0`

### Pitfall 2: Direct private import in test_factory.py

**What goes wrong:** `test_factory.py::TestBudgetAllocation::test_zero_balance_voters_skipped` imports `_VoterLedger` directly from `backtesting.data.factory`. After the class is moved to `budget.py` and renamed `VoterLedger`, this import raises `ImportError`.

**Why it happens:** The test was written to test the budget internals while they were still private in factory.py.

**How to avoid:** Update the import to `from backtesting.data.budget import VoterLedger, BLOCKS_PER_DAY`. Note: `BLOCKS_PER_DAY` is a module-level constant in `factory.py` — it should stay in `factory.py` (it's a simulation parameter, not a budget concern). The test may need to import it from `factory` separately.

**Warning signs:** `ImportError: cannot import name '_VoterLedger' from 'backtesting.data.factory'`

### Pitfall 3: cadCAD M dict key collision

**What goes wrong:** cadCAD's `config_sim` M dict is a sweep parameter dict. If `curve_type` is added as a string value (not a tuple), cadCAD may interpret it as a scalar and zip it element-wise — depending on the cadCAD version and how other M params are structured.

**Why it happens:** cadCAD M params follow specific rules about sweep vs. non-sweep params.

**How to avoid:** Inspect how `event_stream` is currently passed (as `tuple(event_records)` — a single-element sweep). Pass `curve_type` as a plain string: `'M': {'event_stream': tuple(event_records), 'curve_type': 'sqrt'}`. Since there is only N=1 run, no sweep collision is possible. Verify by checking that `params.get('curve_type')` in `suf_tallies` returns the string, not a list.

**Warning signs:** `params['curve_type']` returns a list `['sqrt']` instead of `'sqrt'`

### Pitfall 4: Silent curve_type bypass in metrics

**What goes wrong:** Even after threading `curve_type` through `generate_scenario()` → `suf_tallies` → `compute_signals_weight`, the metrics layer still calls `_add_signals_weight_column()` which calls `compute_signals_weight` with **no** curve_type argument (defaults to `'sqrt'`). So `generate_scenario(curve_type='log')` produces events, but when the results DataFrame is used to re-compute signals weights in metrics, it uses sqrt not log.

**Why it happens:** The metrics layer (`_add_signals_weight_column` in `metrics.py`) is decoupled from the simulation layer — it re-computes weights from the raw `weight` and `lock_duration_days` columns rather than reading pre-computed signals tallies.

**How to avoid:** This phase must decide: either (a) thread `curve_type` into the metrics functions as well, or (b) verify that the signals tally columns (`signals_for`, `signals_against`, `signals_abstain`) in the results DataFrame are already correctly computed by the cadCAD run with the right curve_type, and that `_add_signals_weight_column` is only used for per-row signals weight display in certain metrics.

**Investigation required:** Check which metrics use `_add_signals_weight_column` vs. the pre-computed tally columns. From code review: `compute_enp`, `compute_nakamoto_coefficient`, `compute_top_k_concentration`, and `compute_late_vote_share` all call `_add_signals_weight_column`. These re-compute signals weights from the raw data. This means curve_type MUST be threaded into `_add_signals_weight_column` as well, or those metrics will silently use sqrt regardless of configuration.

**Resolution:** Add `curve_type` parameter to `_add_signals_weight_column` and thread it from each metric function's call site. This is a larger change than initially apparent — but required for correctness.

**Warning signs:** `generate_scenario(curve_type='log')` runs without error but the Gini/ENP metrics are identical to `curve_type='sqrt'` output.

### Pitfall 5: backtesting/data/__init__.py stale exports

**What goes wrong:** After promoting `VoterLedger` to `budget.py`, the `backtesting/data/__init__.py` doesn't export it, making it inaccessible via `from backtesting.data import VoterLedger`.

**Why it happens:** The `__init__.py` currently only re-exports from `factory`, `loader`, and `schema`. `budget.py` is a new file.

**How to avoid:** Add imports from `budget.py` to `__init__.py`. The CONTEXT.md requirement states `budget.py` should be "importable and unit-testable independently of the factory" — this means the public API should be reachable via `from backtesting.data.budget import VoterLedger` directly. Exporting through `__init__.py` is optional convenience but good hygiene.

---

## Code Examples

### NaN Fix — _gini() (BUDG-02)

Current code in `/home/biscii/src/signals/apps/simulations/src/backtesting/metrics.py` lines 25-33:

```python
def _gini(arr: np.ndarray) -> float:
    arr = np.sort(arr.astype(float))
    n = len(arr)
    if n == 0 or arr.sum() == 0:
        return 0.0          # BUG: should be np.nan
    idx = np.arange(1, n + 1)
    return float((2 * (idx * arr).sum()) / (n * arr.sum()) - (n + 1) / n)
```

Fixed:

```python
def _gini(arr: np.ndarray) -> float:
    """Standard Gini coefficient for a 1-D array of non-negative values.

    Returns np.nan for zero-sum arrays (NaN-for-degenerate-inputs convention).
    Zero participation is a valid but degenerate case, not 'perfect equality'.
    """
    arr = np.sort(arr.astype(float))
    n = len(arr)
    if n == 0 or arr.sum() == 0:
        return float(np.nan)
    idx = np.arange(1, n + 1)
    return float((2 * (idx * arr).sum()) / (n * arr.sum()) - (n + 1) / n)
```

### NaN Fix — _enp() (BUDG-03)

Current code lines 35-41:

```python
def _enp(weights: np.ndarray) -> float:
    total = weights.sum()
    if total == 0:
        return 0.0          # BUG: should be np.nan
    shares = weights / total
    return float(1.0 / (shares ** 2).sum())
```

Fixed:

```python
def _enp(weights: np.ndarray) -> float:
    """Effective Number of Parties — ENP = 1 / sum(s_i^2).

    Returns np.nan for zero-weight arrays (NaN-for-degenerate-inputs convention).
    ENP=0 is outside the valid range [1, n_voters] and would corrupt sweep heatmaps.
    """
    total = weights.sum()
    if total == 0:
        return float(np.nan)
    shares = weights / total
    return float(1.0 / (shares ** 2).sum())
```

### Regression tests for NaN edge cases

```python
# tests/test_metrics.py (new tests to add)

def test_gini_zero_sum_returns_nan():
    """BUDG-02: _gini() returns np.nan for zero-sum arrays."""
    from backtesting.metrics import _gini
    import math
    result = _gini(np.array([0.0, 0.0, 0.0]))
    assert math.isnan(result), f'Expected nan, got {result}'

def test_gini_empty_array_returns_nan():
    """BUDG-02: _gini() returns np.nan for empty arrays."""
    from backtesting.metrics import _gini
    import math
    result = _gini(np.array([]))
    assert math.isnan(result), f'Expected nan, got {result}'

def test_enp_zero_weight_returns_nan():
    """BUDG-03: _enp() returns np.nan for zero-weight arrays."""
    from backtesting.metrics import _enp
    import math
    result = _enp(np.array([0.0, 0.0, 0.0]))
    assert math.isnan(result), f'Expected nan, got {result}'
```

### generate_scenario curve_type parameter (BUDG-04)

```python
# In factory.py — updated signature
ScenarioCurveType = Literal['sqrt', 'log', 'linear']
_VALID_CURVE_TYPES: tuple[str, ...] = ('sqrt', 'log', 'linear')

def generate_scenario(
    n_voters: int = 200,
    ...
    curve_type: ScenarioCurveType = 'sqrt',   # new param
    ...
) -> list[GovernorEvent]:
    if curve_type not in _VALID_CURVE_TYPES:
        raise ValueError(
            f'curve_type={curve_type!r} is invalid. '
            f'Must be one of: {_VALID_CURVE_TYPES}'
        )
    ...
    # pass curve_type to run_backtest via events metadata, or
    # use it directly in the factory's own weight computation if any
```

### pipeline.py _GENERATE_SCENARIO_KEYS update (BUDG-04)

```python
# In pipeline.py — add 'curve_type' to the allowed keys set
_GENERATE_SCENARIO_KEYS = frozenset({
    'n_voters', 'n_proposals', 'total_supply', 'avg_participation_rate',
    'stake_profile', 'lock_profile', 'pareto_alpha', 'l_max_days',
    'proposal_window_blocks', 'seed', 'budget_enabled', 'allocation_strategy',
    'blocks_per_day', 'curve_type',   # added
})
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `_gini()` returns 0.0 for zero participation | `_gini()` returns np.nan | Phase 8 | Downstream metrics use np.nanmean() — already used in compute_margin_shift |
| `_enp()` returns 0.0 for zero weight | `_enp()` returns np.nan | Phase 8 | test_enp assertion must be updated to allow NaN |
| curve_type hardcoded to 'sqrt' in sufs.py | curve_type threaded from generate_scenario() | Phase 8 | Enables sweep over curve shape in Phase 10 |
| Budget internals private in factory.py | VoterLedger public in budget.py | Phase 8 | Phase 9 MC sampling imports VoterLedger directly |

**Deprecated/outdated after Phase 8:**
- `_VoterLedger` in factory.py: replaced by `VoterLedger` in budget.py
- `_LockEntry` in factory.py: replaced by `LockEntry` in budget.py
- `_compute_allocation_fraction` in factory.py: replaced by `compute_allocation_fraction` in budget.py

---

## Open Questions

1. **Does curve_type need to thread into the metrics layer?**
   - What we know: `_add_signals_weight_column()` in metrics.py re-computes signals weights from raw data using the default `curve_type='sqrt'`. This is used by `compute_enp`, `compute_nakamoto_coefficient`, `compute_top_k_concentration`, `compute_late_vote_share`, and `compute_lockin_timing`.
   - What's unclear: The success criterion says `generate_scenario(curve_type='log')` "produces metrics using the log curve (not hardcoded sqrt)". This implies metrics must also use the threaded curve_type, not just the cadCAD simulation tallies.
   - Recommendation: Thread `curve_type` into `_add_signals_weight_column(vote_df, curve_type='sqrt')` and propagate through all five calling metric functions. This is the correct interpretation of the success criterion. Plan for this as a task.

2. **Should `curve_type` be stored on the run artifacts or event stream?**
   - What we know: Currently `run_backtest` takes only `event_records`. The `curve_type` must be available during `suf_tallies` execution.
   - What's unclear: Best mechanism — cadCAD M dict param vs. module-level override vs. passing through a new `run_backtest(events, curve_type=...)` signature.
   - Recommendation: Use cadCAD M dict (`params['curve_type']`) — it is the established cadCAD pattern for simulation parameters (as evidenced by the existing `event_stream` M param). Requires `run_backtest` to accept `curve_type` and pass it through `config_sim`.

3. **Does `BLOCKS_PER_DAY` belong in budget.py or stay in factory.py?**
   - What we know: `test_factory.py` imports it from factory. It's a simulation constant (L2 block rate), not a budget concept.
   - Recommendation: Keep `BLOCKS_PER_DAY` in `factory.py`. Update the test import accordingly.

---

## Validation Architecture

> Skipped — `workflow.nyquist_validation` is not set to true in `.planning/config.json`

---

## Sources

### Primary (HIGH confidence)

- Direct codebase inspection: `/home/biscii/src/signals/apps/simulations/src/backtesting/metrics.py` — confirmed `_gini()` line 29 returns `0.0`, `_enp()` line 38 returns `0.0`
- Direct codebase inspection: `/home/biscii/src/signals/apps/simulations/src/backtesting/data/factory.py` — confirmed `_VoterLedger`, `_LockEntry`, `_compute_allocation_fraction` are private; `generate_scenario()` has no `curve_type` parameter
- Direct codebase inspection: `/home/biscii/src/signals/apps/simulations/src/backtesting/simulation/sufs.py` — confirmed `compute_signals_weight(stake, lock_days)` is called with no `curve_type` (defaults to `'sqrt'`)
- Direct codebase inspection: `/home/biscii/src/signals/apps/simulations/src/backtesting/weighting/signals.py` — confirmed `CurveType = Literal['sqrt', 'linear', 'log', 'exp']` and `compute_signals_weight` already accepts `curve_type` parameter
- Direct codebase inspection: `/home/biscii/src/signals/apps/simulations/tests/test_factory.py` — confirmed `from backtesting.data.factory import _VoterLedger` import at line 353 that will break
- Test run: 147 tests collected confirmed via `.venv/bin/pytest --collect-only -q`
- Direct codebase inspection: `/home/biscii/src/signals/apps/simulations/src/backtesting/pipeline.py` — confirmed `_GENERATE_SCENARIO_KEYS` at line 206 does not include `curve_type`

### Secondary (MEDIUM confidence)

- NumPy documentation (well-established behavior): `float(np.nan)` returns IEEE 754 NaN; `nan >= 1.0` evaluates to `False` in Python; `np.nanmean([nan, 1.0])` correctly ignores NaN — all consistent with current usage in `compute_margin_shift` which already uses `np.nanmean()`
- cadCAD v0.5.3 M dict pattern: cadCAD M params dict (`config_sim({'M': {...}})`) passes sweep parameters to SUFs via the `params` argument — already used in project for `event_stream`

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries already in pyproject.toml dependencies; no new deps needed
- Architecture: HIGH — all files directly inspected; promotion pattern and threading path confirmed from source
- Pitfalls: HIGH — Pitfalls 1-3 confirmed by direct code inspection; Pitfall 4 (metrics layer bypass) identified by tracing the call chain in metrics.py

**Research date:** 2026-02-28
**Valid until:** 2026-03-28 (stable Python refactoring — no fast-moving external APIs)
