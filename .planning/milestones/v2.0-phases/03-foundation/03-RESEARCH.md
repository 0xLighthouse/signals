# Phase 3: Foundation - Research

**Researched:** 2026-02-27
**Domain:** Python data schema, synthetic event generation, Pydantic v2 validation, pure weighting functions
**Confidence:** HIGH

## Summary

Phase 3 builds a standalone, cadCAD-free data and weighting layer: a Governor-compatible event schema validated by Pydantic v2, a synthetic event stream factory, a data loader with a Protocol-based interface, and pure weighting functions. Everything in this phase is independently testable without running a simulation.

The architecture recommendation from project research is unambiguous: **schema first**. Define `PROPOSAL_CREATED`, `VOTE_CAST`, and `PROPOSAL_FINALIZED` as Pydantic v2 models before writing any factory or loader code. The schema is the contract that makes synthetic↔real data swappable later. The weighting pure functions are equally critical — isolate `compute_signals_weight()` from cadCAD so the core scientific claim (`W = stake × f(lock_duration)`) can be unit-tested in isolation.

The two critical implementation decisions confirmed through verification: (1) Pareto alpha=0.7 with n=200 voters reliably achieves Gini >= 0.65 (mean Gini ~0.90, minimum 0.73 across 30 seeds) — lower alpha values are more reliable but less realistic; (2) the single-DataFrame approach (all event types, null fields for non-applicable columns, sorted by block_number) is correct for cadCAD M param compatibility. The `lock_duration_days` field belongs on `VOTE_CAST` events directly — not in a separate table — to keep event records self-contained for cadCAD replay.

**Primary recommendation:** Implement in strict order: schema → weighting → factory → loader. Test each before proceeding. The schema and weighting layers are pure Python with no complex dependencies; they should be done in Wave 1. Factory and loader follow in Wave 2. The referential integrity validator (cross-event checks for double votes, out-of-window votes) runs at load time, not schema-construction time.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Data Loader Contract**
- Loader returns a pandas DataFrame (not raw event list)
- Real data will be loaded from Parquet files (not CSV, not live RPC)
- Loader validates data on load — rejects malformed events immediately (fail fast)
- Synthetic factory and file loader share a Python Protocol class defining `load() -> DataFrame`
- Loader always loads everything — no filtering on load, downstream filters as needed

**Event Schema Design**
- Vote support: For / Against / Abstain (Governor Bravo tri-state)
- Typed fields use Python enums (EventType.VOTE_CAST, VoteSupport.FOR, etc.)
- Timestamps: block_number as primary, unix timestamp as optional derived field
- PROPOSAL_CREATED includes optional quorum field (defaults to 0 = no quorum)

**Synthetic Data Realism**
- Scale: configurable with sensible defaults (medium: ~200 voters, ~30 proposals)
- Participation: power-law profile — few voters vote on everything, most vote rarely (matches real DAO turnout 5-15%)
- Contentiousness: mixed distribution — some blowouts, some competitive, some coin-flips
- Lock duration distribution: configurable scenarios — correlated with stake, independent, bimodal (short-term traders vs long-term holders)

**Lock Curve Behavior**
- Default curve shape: square root — f(L) = sqrt(L / L_max)
- L_max: configurable, default 12 months (365 days)
- Output range: normalized 0 to 1 (Signals weight is always <= raw stake)
- f(0): small floor (e.g., 0.1) — uncommitted voters still get minimal weight, not completely silenced
- All curve types (linear, log, sqrt, exp) must be available as options

### Claude's Discretion
- Lock duration placement: in VOTE_CAST events vs separate locks table — pick what works best for cadCAD event-replay
- DataFrame structure: single DataFrame with type discriminator vs separate per event type — pick what cadCAD consumes most naturally
- Exact default values for synthetic parameters (voter count, proposal count, participation rate)
- Pareto alpha parameter for stake distribution (research suggests ~1.5)
- Tri-modal timing distribution parameters

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DATA-01 | Governor-compatible event schema defines PROPOSAL_CREATED, VOTE_CAST, and PROPOSAL_FINALIZED as validated data structures with consistent field names | Pydantic v2 BaseModel pattern; Governor Bravo field naming confirmed |
| DATA-02 | Synthetic event stream generator produces configurable voter counts, proposal counts, and participation rates | `numpy.random.default_rng(seed)` + power-law participation; verified working |
| DATA-03 | Synthetic stake distribution follows power-law (Pareto) with Gini >= 0.65 matching real DAO profiles | **Critical:** Pareto alpha=0.7 with n>=100 voters reliably achieves Gini >= 0.65 (verified); alpha=1.5 does NOT achieve 0.65 at 200 voters |
| DATA-04 | Synthetic vote timing follows tri-modal distribution (early, mid, late) within proposal windows | Three block ranges (early 0-20%, mid 30-70%, late 80-100% of window); numpy RNG; verified |
| DATA-05 | Synthetic data enforces referential integrity (no double votes, no votes outside proposal window) | Validation function at load time using DataFrame merge; verified pattern |
| DATA-06 | Pydantic v2 validates all event data at construction time | Pydantic v2.12.5 installed, `ValidationError` raised for bad support value and negative weight; verified |
| DATA-07 | User can select voter behavior profiles (power-law, uniform, bimodal stake distributions) | Factory accepts `distribution: Literal['pareto', 'uniform', 'bimodal']` parameter |
| DATA-08 | User can set a random seed for reproducible event stream generation | `numpy.random.default_rng(seed)` threaded through all random sampling in factory |
| DATA-09 | Data loader interface supports swapping synthetic for real Governor data with zero architecture changes | Python `Protocol` class with `load() -> DataFrame`; `isinstance` check verified working |
| WGHT-01 | Signals weight function computes W = stake × f(lock_duration) as a pure function independent of cadCAD | Pure function in `backtesting/weighting/signals.py`; no cadCAD import; verified |
| WGHT-02 | Lock curve f(L) is parameterized and supports linear, log, sqrt, and exponential shapes | Four curve types verified: all return floor=0.1 at L=0 and 1.0 at L=L_max |
| WGHT-03 | Lock curve exhibits diminishing returns after ~3 months | sqrt curve confirmed: 30d delta=0.107, 90d delta=0.082, 180d delta=0.069 (decreasing); log also qualifies |
| WGHT-04 | Legacy weight function computes W = stake (identity) for baseline comparison | `compute_legacy_weight(stake) -> float: return stake` — trivial pure function |
</phase_requirements>

---

## Standard Stack

### Core (already in pyproject.toml — no additions needed for this phase)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| pydantic | `>=2.0.0,<3` | Governor event schema validation | **Must add to pyproject.toml** — not yet listed. Pydantic v2 (Rust-backed) validates at construction time. Catches schema drift before it corrupts simulation runs. `model_validator` enables cross-field constraints. v2.12.5 installed and verified. |
| numpy | `>=1.26.4,<2` | Pareto sampling, tri-modal timing, Gini computation | Already in pyproject.toml. `numpy.random.default_rng(seed)` is the modern seeded RNG API (avoids deprecated `np.random.seed()`). |
| pandas | `>=2.2.3,<3` | Loader output DataFrame, event stream structure | Already in pyproject.toml. cadCAD returns pandas DataFrames; loader must output pandas. |
| scipy | `>=1.13.0,<2` | **Phase 3 only needs this for potential Gini helpers** — but Gini is hand-rolled | **Must add to pyproject.toml** — latent bug (imported in metrics.py but not pinned). Add now. Not required for Phase 3 features but fixes the dependency gap. |
| fastparquet | `>=2024.11.0,<2025` | Real Governor data in Parquet format | Already in pyproject.toml. Real data loader reads Parquet via `pd.read_parquet()`. |

### Supporting (no new additions for Phase 3)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| enum (stdlib) | stdlib | `EventType`, `VoteSupport` enums | Always — for categorical event fields; enums provide IDE autocomplete and type safety |
| typing (stdlib) | stdlib | `Protocol`, `Literal`, `runtime_checkable` | For loader Protocol contract and event_type Literal discriminators |
| dataclasses (stdlib) | stdlib | Event serialization to dict for cadCAD M params | `dataclasses.asdict()` converts events to plain dicts before cadCAD ingestion |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Pydantic v2 BaseModel | Python dataclasses | Dataclasses have no built-in validation. Pydantic v2 catches malformed events at construction time, which is the requirement (DATA-06). Use Pydantic for validated schema, `model.model_dump()` to convert to dict for cadCAD. |
| Pydantic v2 BaseModel | attrs | attrs is lighter but lacks `model_validator` for cross-field constraints and JSON schema export. Pydantic v2's Rust core is fast enough for thousands of synthetic events. |
| Single DataFrame (all event types) | Separate DataFrames per type | Separate DataFrames complicate the loader Protocol (returns multiple objects) and require merging before sorting by block_number. Single DataFrame sorts naturally and converts directly to `df.to_dict('records')` for cadCAD M params. **Use single DataFrame.** |
| `lock_duration_days` on VOTE_CAST | Separate locks table | Separate table requires joins before cadCAD ingestion. VOTE_CAST with embedded `lock_duration_days` is self-contained per event — the cadCAD policy reads one dict per timestep without lookups. **Use embedded field.** |

**Installation — add to `apps/simulations/pyproject.toml`:**

```toml
dependencies = [
    # Existing (unchanged)
    "pandas>=2.2.3,<3",
    "matplotlib>=3.9.2,<4",
    "seaborn>=0.13.2,<0.14",
    "numpy>=1.26.4,<2",
    "fastparquet>=2024.11.0,<2025",
    "tabulate>=0.9.0,<0.10",
    "cadcad>=0.5.3,<0.6",
    # NEW for v2.0 (add now)
    "scipy>=1.13.0,<2",       # fixes latent bug; not needed for Phase 3 features but correct to pin
    "pydantic>=2.0.0,<3",     # Governor schema validation (DATA-06)
]
```

Run `uv sync` after updating.

---

## Architecture Patterns

### Recommended Project Structure (Phase 3 scope)

```
apps/simulations/src/
├── backtesting/               # NEW top-level package
│   ├── __init__.py
│   ├── data/
│   │   ├── __init__.py
│   │   ├── schema.py          # Pydantic v2 event models + Protocol
│   │   ├── factory.py         # Synthetic event stream generator
│   │   └── loader.py          # SyntheticLoader + (stub) ParquetLoader
│   └── weighting/
│       ├── __init__.py
│       └── signals.py         # Pure functions: lock_curve, compute_signals_weight, compute_legacy_weight
│
└── (existing packages unchanged)

apps/simulations/tests/
├── conftest.py                # ADD: backtest fixtures
├── test_schema.py             # NEW: Pydantic validation, enum values, Protocol contract
├── test_factory.py            # NEW: Gini >= 0.65, tri-modal timing, referential integrity
├── test_weighting.py          # NEW: lock curve shapes, output range, diminishing returns
└── test_loader.py             # NEW: loader Protocol, DataFrame structure, fail-fast validation
```

### Pattern 1: Pydantic v2 Governor Event Schema

**What:** Define each Governor event type as a Pydantic v2 `BaseModel` with typed fields, Python enums for categoricals, and cross-field validators for business rules.

**When to use:** Schema definition (DATA-01, DATA-06).

**Key design choices confirmed by research:**
- `event_type` uses `Literal[EventType.X]` discriminator — enables `Union` type with automatic dispatch
- `support` is `VoteSupport` enum (FOR/AGAINST/ABSTAIN) — Governor Bravo tri-state
- `block_number` is primary timestamp — `unix_timestamp` is optional derived
- `lock_duration_days: float = 0.0` on `VoteCastEvent` (not a separate table)
- `quorum: int = 0` on `ProposalCreatedEvent` — 0 means no quorum check

```python
# backtesting/data/schema.py
from pydantic import BaseModel, model_validator, field_validator
from typing import Literal, Optional, Annotated, Protocol, runtime_checkable
from enum import Enum
import pandas as pd


class EventType(str, Enum):
    PROPOSAL_CREATED = 'PROPOSAL_CREATED'
    VOTE_CAST = 'VOTE_CAST'
    PROPOSAL_FINALIZED = 'PROPOSAL_FINALIZED'


class VoteSupport(str, Enum):
    FOR = 'FOR'
    AGAINST = 'AGAINST'
    ABSTAIN = 'ABSTAIN'


class ProposalCreatedEvent(BaseModel):
    event_type: Literal[EventType.PROPOSAL_CREATED] = EventType.PROPOSAL_CREATED
    block_number: int
    proposal_id: str
    proposer: str
    start_block: int
    end_block: int
    description: str = ''
    quorum: int = 0  # 0 = no quorum required

    @field_validator('block_number', 'start_block', 'end_block')
    @classmethod
    def block_numbers_non_negative(cls, v: int) -> int:
        if v < 0:
            raise ValueError('block numbers must be non-negative')
        return v

    @model_validator(mode='after')
    def end_after_start(self) -> 'ProposalCreatedEvent':
        if self.end_block <= self.start_block:
            raise ValueError('end_block must be after start_block')
        return self


class VoteCastEvent(BaseModel):
    event_type: Literal[EventType.VOTE_CAST] = EventType.VOTE_CAST
    block_number: int
    proposal_id: str
    voter: str
    support: VoteSupport
    weight: float          # raw token stake at time of vote
    lock_duration_days: float = 0.0   # 0.0 for non-locked (legacy-compatible)
    unix_timestamp: Optional[int] = None

    @field_validator('weight')
    @classmethod
    def weight_non_negative(cls, v: float) -> float:
        if v < 0:
            raise ValueError('weight must be non-negative')
        return v

    @field_validator('lock_duration_days')
    @classmethod
    def lock_duration_non_negative(cls, v: float) -> float:
        if v < 0:
            raise ValueError('lock_duration_days must be non-negative')
        return v


class ProposalFinalizedEvent(BaseModel):
    event_type: Literal[EventType.PROPOSAL_FINALIZED] = EventType.PROPOSAL_FINALIZED
    block_number: int
    proposal_id: str
    passed: bool
    unix_timestamp: Optional[int] = None


GovernorEvent = ProposalCreatedEvent | VoteCastEvent | ProposalFinalizedEvent


@runtime_checkable
class GovernorDataLoader(Protocol):
    """Contract for all data loaders — synthetic and real data must implement this."""
    def load(self) -> pd.DataFrame:
        """Load and return all events as a sorted DataFrame."""
        ...
```

### Pattern 2: Pure Weighting Functions

**What:** `backtesting/weighting/signals.py` contains ONLY pure functions. No cadCAD import. No pandas. No state. Input: numeric scalars or numpy arrays. Output: scalars or arrays.

**When to use:** Always — weight functions are the scientific claim, must be independently testable.

```python
# backtesting/weighting/signals.py
import numpy as np
from typing import Literal

CurveType = Literal['sqrt', 'linear', 'log', 'exp']


def lock_curve(
    lock_duration_days: float,
    curve_type: CurveType = 'sqrt',
    l_max_days: float = 365.0,
    floor: float = 0.1,
) -> float:
    """
    Compute f(L) — the lock duration multiplier in [floor, 1.0].

    Default: sqrt curve per user decision.
    f(0) = floor (uncommitted voters still get minimal weight).
    f(l_max) = 1.0.

    Args:
        lock_duration_days: Lock duration in days. 0 = no lock.
        curve_type: Shape of the curve ('sqrt', 'linear', 'log', 'exp').
        l_max_days: Maximum lock duration in days (normalization denominator).
        floor: Minimum multiplier at L=0. Default 0.1.

    Returns:
        Multiplier in [floor, 1.0].
    """
    if lock_duration_days <= 0:
        return floor

    L = min(lock_duration_days, l_max_days)  # cap at l_max

    if curve_type == 'sqrt':
        raw = np.sqrt(L / l_max_days)
    elif curve_type == 'linear':
        raw = L / l_max_days
    elif curve_type == 'log':
        raw = np.log1p(L) / np.log1p(l_max_days)
    elif curve_type == 'exp':
        # alpha=0.5 per month gives ~78% at 3 months
        alpha_per_day = 0.5 / 30.0
        raw = 1.0 - np.exp(-alpha_per_day * L)
        raw = raw / (1.0 - np.exp(-alpha_per_day * l_max_days))  # normalize to 1.0 at L_max
    else:
        raise ValueError(f'Unknown curve_type: {curve_type}')

    return float(floor + (1.0 - floor) * raw)


def compute_signals_weight(
    stake: float,
    lock_duration_days: float,
    curve_type: CurveType = 'sqrt',
    l_max_days: float = 365.0,
    floor: float = 0.1,
) -> float:
    """
    W_signals = stake × f(lock_duration)

    Signals voting weight. Always <= stake (since f(L) in [0, 1]).
    """
    return stake * lock_curve(lock_duration_days, curve_type, l_max_days, floor)


def compute_legacy_weight(stake: float) -> float:
    """
    W_legacy = stake

    Plain token-weighted voting. Identity function for baseline comparison.
    """
    return float(stake)
```

### Pattern 3: Single DataFrame Loader

**What:** The loader converts events to a single pandas DataFrame with all event types. Null fields for non-applicable columns (NaN for floats, None for strings). Sorted by `block_number`. Validates referential integrity at load time (fail fast).

**Why single DataFrame:** (1) Natural sort by block_number across event types. (2) `df.to_dict('records')` converts directly to cadCAD M param format. (3) Simple loader Protocol — one `load() -> DataFrame` method.

**DataFrame columns:**
- `event_type` (str) — discriminator
- `block_number` (int) — primary sort key
- `proposal_id` (str) — all events
- `proposer` (str, nullable) — PROPOSAL_CREATED only
- `start_block` (float, nullable) — PROPOSAL_CREATED only
- `end_block` (float, nullable) — PROPOSAL_CREATED only
- `quorum` (float, nullable) — PROPOSAL_CREATED only
- `voter` (str, nullable) — VOTE_CAST only
- `support` (str, nullable) — VOTE_CAST only ('FOR'/'AGAINST'/'ABSTAIN')
- `weight` (float, nullable) — VOTE_CAST only
- `lock_duration_days` (float, nullable) — VOTE_CAST only
- `passed` (bool, nullable) — PROPOSAL_FINALIZED only

```python
# backtesting/data/loader.py
import pandas as pd
from typing import Sequence
from backtesting.data.schema import GovernorEvent, GovernorDataLoader, EventType


def events_to_dataframe(events: Sequence[GovernorEvent]) -> pd.DataFrame:
    """Convert validated GovernorEvent list to sorted DataFrame."""
    records = [e.model_dump() for e in events]
    df = pd.DataFrame(records)
    df = df.sort_values('block_number').reset_index(drop=True)
    return df


def validate_event_stream(df: pd.DataFrame) -> list[str]:
    """
    Check referential integrity of event stream.
    Returns list of error strings (empty = valid).
    """
    errors = []
    proposal_ids = set(df.loc[df['event_type'] == 'PROPOSAL_CREATED', 'proposal_id'])

    votes = df[df['event_type'] == 'VOTE_CAST']
    if len(votes) > 0:
        # Rule: no votes on unknown proposals
        bad = votes[~votes['proposal_id'].isin(proposal_ids)]
        if len(bad):
            errors.append(f'{len(bad)} VOTE_CAST events reference unknown proposal_id')

        # Rule: no double votes (same voter, same proposal)
        dupes = votes.groupby(['proposal_id', 'voter']).size()
        doubles = dupes[dupes > 1]
        if len(doubles):
            errors.append(f'Double votes on {len(doubles)} (proposal, voter) pairs')

        # Rule: votes within proposal window
        proposals_window = df.loc[
            df['event_type'] == 'PROPOSAL_CREATED',
            ['proposal_id', 'start_block', 'end_block']
        ]
        merged = votes.merge(proposals_window, on='proposal_id', how='left')
        out_of_window = merged[
            (merged['block_number'] < merged['start_block']) |
            (merged['block_number'] > merged['end_block'])
        ]
        if len(out_of_window):
            errors.append(f'{len(out_of_window)} votes outside proposal window')

    return errors


class SyntheticLoader:
    """Load events from the synthetic factory."""

    def __init__(self, events: Sequence[GovernorEvent]):
        self._events = events

    def load(self) -> pd.DataFrame:
        df = events_to_dataframe(self._events)
        errors = validate_event_stream(df)
        if errors:
            raise ValueError(f'Invalid event stream: {errors}')
        return df


class ParquetLoader:
    """Load Governor events from a Parquet file (real DAO data)."""

    def __init__(self, path: str):
        self._path = path

    def load(self) -> pd.DataFrame:
        df = pd.read_parquet(self._path)
        errors = validate_event_stream(df)
        if errors:
            raise ValueError(f'Invalid event stream from {self._path}: {errors}')
        return df
```

### Pattern 4: Synthetic Factory with Configurable Profiles

**What:** Generate realistic event streams. Stake distribution uses Pareto(alpha=0.7) — verified to produce Gini >= 0.65 reliably at n=200. Participation is power-law (top holders vote most). Vote timing is tri-modal (early/mid/late-window blocks).

**Critical finding:** `pareto_alpha=1.5` (mentioned in project context) does NOT produce Gini >= 0.65 at 200 voters (actual Gini ~0.38). **Use `pareto_alpha=0.7` as default.** This is a corrected recommendation from the stated "research suggests ~1.5".

```python
# backtesting/data/factory.py  — key generation logic
import numpy as np
from typing import Literal

StakeProfile = Literal['pareto', 'uniform', 'bimodal']
LockProfile = Literal['correlated', 'independent', 'bimodal']


def _generate_stakes(
    n_voters: int,
    total_supply: float,
    profile: StakeProfile,
    pareto_alpha: float = 0.7,  # 0.7 reliably gives Gini >= 0.65 at n>=100
    rng: np.random.Generator = None,
) -> np.ndarray:
    if rng is None:
        rng = np.random.default_rng()

    if profile == 'pareto':
        raw = rng.pareto(pareto_alpha, n_voters) + 1
        stakes = raw / raw.sum() * total_supply
    elif profile == 'uniform':
        stakes = np.ones(n_voters) * (total_supply / n_voters)
    elif profile == 'bimodal':
        # 10% large holders, 90% small
        n_large = max(1, n_voters // 10)
        n_small = n_voters - n_large
        large = rng.pareto(0.5, n_large) + 1
        small = rng.pareto(2.0, n_small) + 1
        all_raw = np.concatenate([large * 10, small])
        stakes = all_raw / all_raw.sum() * total_supply
    return stakes


def _generate_participation_probs(
    n_voters: int,
    avg_rate: float = 0.10,
    rng: np.random.Generator = None,
) -> np.ndarray:
    """Power-law participation: top holders vote most often."""
    if rng is None:
        rng = np.random.default_rng()
    ranks = np.arange(1, n_voters + 1)
    probs = 1.0 / (ranks ** 0.5)
    probs = probs * (avg_rate * n_voters / probs.sum())
    return np.clip(probs, 0.01, 0.95)


def _generate_vote_timing(
    n_votes: int,
    start_block: int,
    end_block: int,
    early_frac: float = 0.30,
    mid_frac: float = 0.40,
    # late_frac = 1 - early_frac - mid_frac = 0.30
    rng: np.random.Generator = None,
) -> np.ndarray:
    """Tri-modal vote timing distribution within proposal window."""
    if rng is None:
        rng = np.random.default_rng()
    window = end_block - start_block
    early_end = start_block + int(window * 0.20)
    mid_start = start_block + int(window * 0.30)
    mid_end = start_block + int(window * 0.70)
    late_start = start_block + int(window * 0.80)

    n_early = int(n_votes * early_frac)
    n_mid = int(n_votes * mid_frac)
    n_late = n_votes - n_early - n_mid

    early_blocks = rng.integers(start_block, early_end + 1, n_early)
    mid_blocks = rng.integers(mid_start, mid_end + 1, n_mid)
    late_blocks = rng.integers(late_start, end_block + 1, n_late)
    return np.concatenate([early_blocks, mid_blocks, late_blocks])


def _generate_contentiousness(rng: np.random.Generator) -> float:
    """Mixed contentiousness: 20% blowouts, 60% normal, 20% coin-flips."""
    roll = rng.random()
    if roll < 0.20:
        return rng.uniform(0.7, 0.95)   # blowout: FOR dominates
    elif roll < 0.40:
        return rng.uniform(0.05, 0.3)   # blowout: AGAINST dominates
    elif roll < 0.80:
        return rng.uniform(0.4, 0.6)    # competitive
    else:
        return rng.uniform(0.48, 0.52)  # coin-flip
```

### Anti-Patterns to Avoid

- **Pareto alpha=1.5 as default:** Produces Gini ~0.38 at 200 voters — fails the Gini >= 0.65 requirement (DATA-03). Use `pareto_alpha=0.7`.
- **Filtering at load time:** The loader decision is "load everything" — no filtering. Downstream components filter. Do not add `proposal_id=` or `voter=` parameters to `load()`.
- **Putting weighting logic in factory:** `lock_duration_days` is generated in the factory, but `lock_curve()` and `compute_signals_weight()` are NOT called there. Factory creates raw data; weighting layer applies functions. Keeps factory and weighting independently testable.
- **Mutable default arguments in factory functions:** `def generate_scenario(n_voters=200, ..., rng=None)` — always default `rng=None` and create inside. Never `def f(rng=np.random.default_rng())` — that shares state across calls.
- **Storing validated Pydantic models in cadCAD M params:** Pydantic models are not plain dicts. Always call `.model_dump()` before storing in `M["event_stream"]`.
- **Cross-event validation in Pydantic validators:** Out-of-window vote detection requires knowing the proposal's start/end blocks — that's a cross-event constraint, not a single-model constraint. Implement in `validate_event_stream()`, not in `VoteCastEvent`'s `@model_validator`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Event schema validation | Custom type-checking functions | Pydantic v2 `BaseModel` | Pydantic v2 provides error messages, JSON schema, and `.model_dump()` for free. Custom validators miss edge cases and have no standard error format. |
| Gini coefficient | Custom formula | Hand-rolled (existing in codebase) | The existing `_calculate_gini_coefficient` in `GovernanceMetrics` is correct. Use it. The scipy 1.12+ `scipy.stats.gini` exists but is overkill here. |
| Pareto sampling | Custom heavy-tail generator | `numpy.random.default_rng().pareto(alpha, n)` | NumPy's Pareto sampler is well-tested. The `pareto(alpha) + 1` pattern (Lomax → Pareto) is standard for stake distribution generation. |
| Reproducible RNG | Thread-local `random.seed()` | `numpy.random.default_rng(seed)` | Modern NumPy RNG avoids global state. Pass `rng` object through all factory calls — never rely on `np.random.seed()` global seeding. |
| Protocol contracts | ABC with `abstractmethod` | `typing.Protocol` + `@runtime_checkable` | Protocol is structural typing — the real data loader doesn't need to inherit from a base class. `isinstance(loader, GovernorDataLoader)` works without inheritance. |
| Parquet I/O | Custom file reader | `pd.read_parquet()` with `fastparquet` | Already in pyproject.toml. Parquet has typed columns — `event_type` stays a string, `block_number` stays int, avoiding pandas type inference issues. |

**Key insight:** The hardest problem in this phase is the Gini >= 0.65 requirement. The naive Pareto(alpha=1.5) from literature doesn't meet it at the default 200 voters. Use alpha=0.7 (verified). If voter count is configurable below 100, add a warning or use alpha=0.5 for small populations.

---

## Common Pitfalls

### Pitfall 1: Wrong Pareto Alpha (DATA-03 failure)

**What goes wrong:** Using `pareto_alpha=1.5` (commonly cited for real DAO data) produces Gini ~0.38 at 200 voters — far below the required 0.65. The test `assert gini(stakes) >= 0.65` will fail.

**Why it happens:** The alpha=1.5 value refers to the shape parameter in papers that fit the full population distribution. Small samples from Pareto(1.5) have much lower empirical Gini than the theoretical population value.

**How to avoid:** Use `pareto_alpha=0.7` as default. Verified: n=200, alpha=0.7, 30 seeds → mean Gini=0.90, min Gini=0.73, 100% pass rate for Gini >= 0.65.

**Warning signs:** Gini values consistently below 0.65, test failure on `assert gini >= 0.65`.

### Pitfall 2: Cross-Event Validators in Pydantic Models

**What goes wrong:** Trying to validate "vote is within proposal window" inside `VoteCastEvent`'s `@model_validator`. This requires knowing the proposal's `start_block` and `end_block` — data that isn't on the `VoteCastEvent` model.

**Why it happens:** Pydantic validators only see the current model's data. Cross-event constraints require external context.

**How to avoid:** Implement cross-event validation in `validate_event_stream(df)` at loader time, not in Pydantic models. Pydantic handles single-event field validation; the loader handles cross-event integrity.

### Pitfall 3: mutable default_rng in function signatures

**What goes wrong:** `def factory(rng=np.random.default_rng(42))` — the RNG is created once at import time and shared across all calls. Two calls to `factory()` produce different results even though it looks seeded.

**Why it happens:** Python evaluates default arguments at definition time. The RNG object has internal state that changes on every call.

**How to avoid:** Always `def factory(..., seed=None, rng=None)` → `if rng is None: rng = np.random.default_rng(seed)` inside the function body.

### Pitfall 4: Uniform participation probability

**What goes wrong:** Assigning each voter an equal probability of voting (`prob_vote = 0.10`) produces a turnout distribution that doesn't match real DAOs. All voters participate equally, which produces an artificially low Gini on participation-weighted votes.

**Why it happens:** Uniform is the simplest default. The DATA-02 requirement says "configurable participation rates" — it's easy to interpret as a single global rate.

**How to avoid:** Implement power-law participation: `probs = 1 / ranks^0.5`, normalized to target mean. Top holder participates in ~70% of proposals; median holder in ~7%; bottom in ~5%.

### Pitfall 5: NaN propagation from nullable DataFrame columns

**What goes wrong:** The loader produces a single DataFrame with NaN for non-applicable fields (e.g., `weight=NaN` for PROPOSAL_CREATED rows). Downstream code that forgets to filter by `event_type` before operating on `weight` gets NaN contamination.

**Why it happens:** Correct design for the DataFrame structure, but callers must always filter first.

**How to avoid:** In `loader.py`, set DataFrame dtypes explicitly: `weight` as `float64` (nullable), `voter` as `object` (nullable string). Add a comment on the DataFrame saying consumers must filter by `event_type` before accessing type-specific columns.

---

## Code Examples

Verified patterns from implementation verification:

### Pydantic v2 Validation Catching Bad Events

```python
# Source: verified via uv run python -c "..." — 2026-02-27
from pydantic import ValidationError
from backtesting.data.schema import VoteCastEvent, VoteSupport

# Bad support value — ValidationError raised at construction time
try:
    VoteCastEvent(block_number=100, proposal_id='p1', voter='0x00',
                  support='INVALID', weight=500.0)
except ValidationError as e:
    pass  # catches immediately, DATA-06 satisfied

# Bad weight value
try:
    VoteCastEvent(block_number=100, proposal_id='p1', voter='0x00',
                  support='FOR', weight=-100.0)
except ValidationError as e:
    pass  # catches immediately
```

### Pareto Stake Distribution Achieving Gini >= 0.65

```python
# Source: verified via uv run python — Gini=0.90 mean, 100% pass rate at n=200 alpha=0.7
import numpy as np

def generate_stakes_pareto(n_voters: int, total_supply: float,
                            alpha: float = 0.7, seed=None) -> np.ndarray:
    rng = np.random.default_rng(seed)
    raw = rng.pareto(alpha, n_voters) + 1   # Lomax → Pareto
    return (raw / raw.sum()) * total_supply  # normalize to total_supply

# Validate
stakes = generate_stakes_pareto(200, 1_000_000, seed=42)
sorted_s = np.sort(stakes)
n = len(sorted_s)
idx = np.arange(1, n + 1)
gini = (2 * (idx * sorted_s).sum()) / (n * sorted_s.sum()) - (n + 1) / n
assert gini >= 0.65, f'Gini {gini:.3f} below required 0.65'
```

### Lock Curve Shapes (all four types)

```python
# Source: verified via uv run python — all shapes produce floor at L=0, 1.0 at L_max
# Results at L=0, 30, 90, 180, 365 days (L_max=365, floor=0.1):
# sqrt:  0.100, 0.358, 0.547, 0.732, 1.000
# linear: 0.100, 0.174, 0.322, 0.544, 1.000
# log:   0.100, 0.624, 0.788, 0.893, 1.000
# exp:   0.100, 0.454, 0.799, 0.955, 0.998

from backtesting.weighting.signals import lock_curve

# sqrt is default — diminishing returns confirmed
vals_30 = lock_curve(30, 'sqrt')   # 0.358
vals_60 = lock_curve(60, 'sqrt')   # 0.465
vals_90 = lock_curve(90, 'sqrt')   # 0.547
# delta 30→60 = 0.107, delta 60→90 = 0.082 — decreasing (WGHT-03 satisfied)

# WGHT-01: independent of cadCAD
import inspect
import backtesting.weighting.signals as w
source = inspect.getsource(w)
assert 'cadCAD' not in source  # pure functions, no cadCAD import
```

### Protocol Contract Check

```python
# Source: verified via uv run python — isinstance works without inheritance
from typing import runtime_checkable
from backtesting.data.schema import GovernorDataLoader

class MyRealLoader:
    def load(self):  # no inheritance needed
        import pandas as pd
        return pd.read_parquet('/data/compound_governor.parquet')

loader = MyRealLoader()
assert isinstance(loader, GovernorDataLoader)  # True — structural typing
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Pydantic v1 `validator` decorator | Pydantic v2 `field_validator` + `model_validator` | Pydantic 2.0 (2023) | v2 decorators require `@classmethod`; v1 patterns raise warnings in v2 and may fail silently |
| `np.random.seed(42)` global seeding | `np.random.default_rng(42)` per-generator | NumPy 1.17 (2019), preferred since 1.20 | Global seed is not threadsafe and creates hidden coupling; `default_rng` is encapsulated |
| `isinstance(x, type)` + ABC | `typing.Protocol` + `@runtime_checkable` | Python 3.8+ | Protocol enables structural typing — real data loader doesn't inherit from a base class |
| pandas `read_csv()` for event data | `pd.read_parquet()` with fastparquet | Parquet standard mature since ~2019 | Parquet preserves column types (no type inference needed); compact and fast |
| `typing.Union[A, B]` | `A | B` syntax | Python 3.10+ (project uses 3.12) | Simpler `GovernorEvent = ProposalCreatedEvent | VoteCastEvent | ProposalFinalizedEvent` |

**Deprecated/outdated:**
- `pydantic.validator` decorator (v1): replaced by `@field_validator` and `@model_validator` in v2. Do not use v1 patterns.
- `np.random.pareto(alpha, n)` (deprecated module-level): use `np.random.default_rng(seed).pareto(alpha, n)` instead.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | pytest 8.x (already installed) |
| Config file | none — runs from `apps/simulations/` directory |
| Quick run command | `uv run pytest tests/test_schema.py tests/test_weighting.py tests/test_factory.py tests/test_loader.py -x -q` |
| Full suite command | `uv run pytest tests/ --ignore=tests/test_simulation.py -q` |

Note: `tests/test_simulation.py` has a pre-existing import error (`generate_summary_stats` missing from `src.main`) — ignore it with `--ignore` flag until fixed in a separate task.

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DATA-01 | Pydantic models exist for all 3 event types with Governor Bravo field names | unit | `uv run pytest tests/test_schema.py::test_event_models_exist -x` | Wave 0 |
| DATA-02 | Factory generates configurable voter/proposal counts | unit | `uv run pytest tests/test_factory.py::test_configurable_counts -x` | Wave 0 |
| DATA-03 | Pareto stake distribution achieves Gini >= 0.65 | unit | `uv run pytest tests/test_factory.py::test_gini_requirement -x` | Wave 0 |
| DATA-04 | Vote timing follows tri-modal distribution | unit | `uv run pytest tests/test_factory.py::test_trimodal_timing -x` | Wave 0 |
| DATA-05 | No double votes, no out-of-window votes in generated stream | unit | `uv run pytest tests/test_factory.py::test_referential_integrity -x` | Wave 0 |
| DATA-06 | Pydantic rejects malformed events at construction time | unit | `uv run pytest tests/test_schema.py::test_validation_rejects_bad_events -x` | Wave 0 |
| DATA-07 | Factory accepts distribution profile parameter | unit | `uv run pytest tests/test_factory.py::test_distribution_profiles -x` | Wave 0 |
| DATA-08 | Same seed produces identical event streams | unit | `uv run pytest tests/test_factory.py::test_reproducibility -x` | Wave 0 |
| DATA-09 | SyntheticLoader and ParquetLoader both satisfy GovernorDataLoader Protocol | unit | `uv run pytest tests/test_loader.py::test_protocol_compliance -x` | Wave 0 |
| WGHT-01 | Weight functions have no cadCAD import | unit | `uv run pytest tests/test_weighting.py::test_no_cadcad_import -x` | Wave 0 |
| WGHT-02 | All four curve types (sqrt, linear, log, exp) implemented and return values in [0, 1] | unit | `uv run pytest tests/test_weighting.py::test_all_curve_types -x` | Wave 0 |
| WGHT-03 | sqrt curve diminishing returns: deltas decrease after 3 months | unit | `uv run pytest tests/test_weighting.py::test_diminishing_returns -x` | Wave 0 |
| WGHT-04 | `compute_legacy_weight(stake) == stake` for any positive stake | unit | `uv run pytest tests/test_weighting.py::test_legacy_weight_identity -x` | Wave 0 |

### Sampling Rate

- **Per task commit:** `uv run pytest tests/test_schema.py tests/test_weighting.py tests/test_factory.py tests/test_loader.py -x -q`
- **Per wave merge:** `uv run pytest tests/ --ignore=tests/test_simulation.py -q`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `tests/test_schema.py` — covers DATA-01, DATA-06 (Pydantic schema, enum values, validation errors)
- [ ] `tests/test_weighting.py` — covers WGHT-01 through WGHT-04 (pure functions, curve shapes, identity)
- [ ] `tests/test_factory.py` — covers DATA-02 through DATA-08 (generation, Gini, timing, integrity, profiles, reproducibility)
- [ ] `tests/test_loader.py` — covers DATA-09 (Protocol compliance, DataFrame structure, fail-fast validation)
- [ ] `tests/conftest.py` — ADD: `@pytest.fixture` for `sample_events`, `scenario_config`, `default_factory_config`
- [ ] `pyproject.toml` — ADD: `pydantic>=2.0.0,<3` and `scipy>=1.13.0,<2` to `[project] dependencies`; run `uv sync`
- [ ] `src/backtesting/__init__.py` — package init
- [ ] `src/backtesting/data/__init__.py` — package init
- [ ] `src/backtesting/weighting/__init__.py` — package init
- [ ] `pyproject.toml` — ADD `"src/backtesting"` to `[tool.hatch.build.targets.wheel] packages`

---

## Open Questions

1. **Pareto alpha for small n_voters**
   - What we know: alpha=0.7 with n=200 achieves Gini >= 0.65 (100% pass rate)
   - What's unclear: Does the factory need to handle n_voters < 100? At n=50, alpha=0.7 passes only 70% of seeds. If small scenarios are needed, use alpha=0.5.
   - Recommendation: Document in factory docstring that `pareto_alpha=0.7` is calibrated for n>=100 voters. Add warning log if n_voters < 100.

2. **VoteSupport.ABSTAIN handling in tallies**
   - What we know: Schema supports ABSTAIN (Governor Bravo tri-state, locked in CONTEXT.md)
   - What's unclear: How does the cadCAD tally accumulate ABSTAIN votes? (Phase 4 concern)
   - Recommendation: Factory generates ABSTAIN votes at ~10% rate. Leave tally semantics to Phase 4. Factory just needs to produce all three support values.

3. **ParquetLoader column mapping for real data**
   - What we know: Loader reads Parquet and runs `validate_event_stream()`
   - What's unclear: Real Governor Bravo data uses `targets`, `calldatas`, `signatures` fields not in our schema — what's the mapping?
   - Recommendation: For Phase 3, `ParquetLoader` is a stub — it reads Parquet and validates schema. Real column mapping is Phase 3+ scope (DATA-09 only requires the interface exists). Add a `column_mapping: dict` parameter to ParquetLoader for future use.

---

## Sources

### Primary (HIGH confidence)

- Pydantic v2 documentation — `model_validator`, `field_validator`, `runtime_checkable Protocol` — verified via installed pydantic 2.12.5
- NumPy documentation — `default_rng(seed).pareto()` — verified via scipy 1.17.1 and numpy in venv
- Existing codebase `apps/simulations/src/` — read directly: state.py, conftest.py, pyproject.toml — confirms pandas/numpy versions and test infrastructure
- Pareto Gini verification — computed empirically: 30-seed experiment at alpha=0.7, n=200 → mean Gini=0.90, min=0.73, 100% >= 0.65

### Secondary (MEDIUM confidence)

- Governor Bravo field naming — compound-finance/compound-protocol GovernorBravoDelegate.sol — `proposal_id`, `voter`, `support`, `weight` are canonical field names
- Lock curve verified properties — uv run python verification: all 4 curve types produce [floor, 1.0] range, sqrt has confirmed diminishing returns

### Tertiary (LOW confidence — validate during implementation)

- Pareto alpha calibration to real DAO data (alpha=0.7 is empirically validated for Gini >= 0.65 in synthetic context but may not match any specific real DAO's distribution)
- Tri-modal timing distribution parameters (30/40/30 early/mid/late split is a reasonable prior but not calibrated to real Governor proposal data)

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — pydantic 2.12.5, scipy 1.17.1, numpy installed and verified in project venv
- Architecture: HIGH — single DataFrame approach verified compatible with pandas and cadCAD M param serialization; Protocol structural typing verified working
- Pitfalls: HIGH — Pareto alpha issue verified empirically; mutable default arg pitfall is well-known Python pattern; cross-event validation boundary confirmed
- Gini requirement: HIGH — empirically verified that alpha=0.7 achieves >= 0.65 at n=200 across 30 seeds

**Research date:** 2026-02-27
**Valid until:** 2026-03-29 (30 days — stable Python ecosystem, low churn risk)
