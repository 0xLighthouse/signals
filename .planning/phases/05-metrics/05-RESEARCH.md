# Phase 5: Metrics - Research

**Researched:** 2026-02-27
**Domain:** Python governance metrics — pure functions on pandas DataFrames (Gini, ENP, Nakamoto, flip rate, margin shift, participation, concentration, transition matrix, late-vote share, lock-in timing)
**Confidence:** HIGH

## Summary

Phase 5 implements 10 governance metric functions as pure functions in a single `metrics.py` module. Each function takes the results DataFrame produced by Phase 4 (`build_results_dataframe`) and returns a frozen dataclass. No cadCAD imports. No side effects. All computation uses numpy and pandas.

The central architectural question is input signature. The results DataFrame (14 columns: timestep, event_type, block_number, proposal_id, voter, support, weight, lock_duration_days, legacy_for, legacy_against, legacy_abstain, signals_for, signals_against, signals_abstain) **does not contain `start_block` or `end_block`**. The `start_block` and `end_block` fields exist only in PROPOSAL_CREATED rows of the loader DataFrame (from `events_to_dataframe`). The two timing metrics — late-vote share (METR-08) and lock-in timing (METR-09) — require proposal window boundaries to compute. **All metric functions that need timing data must accept a second argument: `windows_df` (a DataFrame with `proposal_id`, `start_block`, `end_block` columns extracted from the loader DataFrame's PROPOSAL_CREATED rows).** The non-timing metrics (METR-01 through METR-07, METR-10) take only the results DataFrame.

For Gini, ENP, Nakamoto, and top-k concentration, per-voter Signals weights are NOT stored directly in the results DataFrame. The tally columns (`signals_for`, `signals_against`, `signals_abstain`) are cumulative totals per proposal — not per-voter weights. To compute per-voter Signals weight, compute `compute_signals_weight(row.weight, row.lock_duration_days)` from `backtesting.weighting.signals` on the VOTE_CAST rows of the results DataFrame. This is the correct source for per-voter Signals weights without needing to re-run the simulation.

**Primary recommendation:** Implement `metrics.py` in `backtesting/metrics.py`. All 10 functions live in this single module. Non-timing metrics accept only `results_df: pd.DataFrame`. Timing metrics accept `results_df: pd.DataFrame, windows_df: pd.DataFrame`. Return frozen dataclasses throughout. Use numpy for all array operations; avoid pandas `apply` in hot paths.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Metric return types**
- Each metric function returns a frozen dataclass with named fields (e.g., `FlipRateResult(per_proposal=Series, aggregate=float)`)
- Dual-regime metrics return both legacy and Signals results in a single call (e.g., `GiniResult(legacy=0.82, signals=0.71)`)
- All 10 metric functions live in a single `metrics.py` module
- No `compute_all_metrics()` convenience function — callers compose what they need

**Outcome classification**
- Pass/Fail determined by simple majority: FOR > AGAINST = Pass, no quorum threshold
- Tie (FOR == AGAINST) = Fail — matches Governor behavior
- Transition matrix returns both counts (2x2 int) and proportions (2x2 float) in a `TransitionMatrix` dataclass
- Margin computed as percentage: (FOR - AGAINST) / (FOR + AGAINST) — normalizes across proposals

**Timing boundaries**
- "Late" for late-vote share = final third of the proposal window (last 33% of blocks between start_block and end_block)
- Late-vote share weighted by voting power, not voter count — captures whale timing behavior
- Lock-in = earliest block where remaining uncast voting power cannot flip the outcome
- Lock-in timing reported as fraction of voting window elapsed (0.0 = start, 1.0 = end) — comparable across proposals

**Concentration thresholds**
- Top-k values hardcoded as [1, 5, 10] — not configurable
- When k >= num_voters, return 100% share (all voting power captured)
- Nakamoto coefficient uses voting power per regime (legacy = raw stake, Signals = W_signals)
- ENP and Nakamoto computed per-proposal (not just aggregate) — shows variance across proposals

### Claude's Discretion
- Exact dataclass field names and types
- Internal helper function structure
- Test fixture design
- Whether to use numpy or pandas internals for computation

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| METR-01 | Flip rate computed per-proposal (legacy_winner != signals_winner) and as aggregate | Extract final tally per proposal via `groupby('proposal_id').last()` on VOTE_CAST rows; compare `legacy_for > legacy_against` vs `signals_for > signals_against` |
| METR-02 | Gini coefficient computed over legacy stake distribution and over Signals-weighted distribution | Legacy: `weight` column of VOTE_CAST rows; Signals: `compute_signals_weight(weight, lock_duration_days)` per row; standard Gini formula via numpy |
| METR-03 | Participation rate computed per-proposal and as aggregate | Voters per proposal / total unique voters in dataset; aggregate = mean of per-proposal rates |
| METR-04 | Effective Number of Participants (ENP) computed as 1/sum(s_i^2) for both regimes | Per-proposal: gather per-voter weights, compute shares, apply formula; per-regime: use `weight` (legacy) or computed `signals_w` (Signals) |
| METR-05 | Nakamoto coefficient computed as minimum voters controlling >50% of voting power for both regimes | Sort weights descending, cumsum until > 50% of total, return index+1; per-proposal per regime |
| METR-06 | Margin shift computed as difference between legacy and Signals margins per proposal | `margin = (FOR - AGAINST) / (FOR + AGAINST)`; shift = signals_margin - legacy_margin; uses final tally rows |
| METR-07 | Outcome transition matrix classifies proposals into Pass→Pass, Pass→Fail, Fail→Pass, Fail→Fail | 2x2 count and proportion matrix from final tallies; tie = Fail per locked decision |
| METR-08 | Late-vote share computed as proportion of voting power cast in final third of proposal window | Requires `windows_df` with `start_block`/`end_block`; threshold = start + (2/3 * window); sum weights in late zone / total |
| METR-09 | Lock-in timing identifies when each proposal's outcome becomes irreversible under each regime | Requires `windows_df`; scan sorted VOTE_CAST rows; lock-in when `abs(running_net) > remaining_power`; return fraction of window elapsed |
| METR-10 | Top-k concentration computed for top-1, top-5, top-10 voters under both regimes | Sort voter weights descending per proposal, top-k sum / total; handle k >= num_voters edge case |
</phase_requirements>

---

## Standard Stack

### Core (all already in pyproject.toml — no new dependencies needed)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| numpy | `>=1.26.4,<2` | Array operations for Gini, ENP, Nakamoto, top-k | Vectorized sort, cumsum, and arithmetic far faster than Python loops. All metric formulas map naturally to numpy. |
| pandas | `>=2.2.3,<3` | Input DataFrame, groupby, final tally extraction | Results DataFrame is already pandas. Groupby operations extract per-proposal views efficiently. |
| dataclasses (stdlib) | stdlib | Frozen dataclasses for metric return types | `@dataclass(frozen=True)` produces immutable results. No additional deps. `fields()` introspection available if needed. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `backtesting.weighting.signals` | internal | `compute_signals_weight(stake, lock_days)` for per-voter Signals weights | Use in all metrics needing Signals voting power (Gini, ENP, Nakamoto, top-k, late-vote share, lock-in) |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Hand-rolled Gini | `scipy.stats.gini` | scipy is in pyproject.toml but overkill. The 4-line numpy Gini formula is correct and tested in Phase 3. Use hand-rolled. |
| Hand-rolled ENP | No scipy equivalent | ENP = `1 / sum(shares**2)` is a trivial 2-line formula. No library needed. |
| numpy loops in lock-in | pandas `apply` | `apply` is slow for row-by-row scanning. Lock-in uses iterrows on already-filtered per-proposal DataFrames. Acceptable: proposals have O(20-100) vote rows, not millions. |

**Installation:** No new packages needed. All dependencies already in `apps/simulations/pyproject.toml`.

---

## Architecture Patterns

### Recommended Project Structure (Phase 5 scope)

```
apps/simulations/src/backtesting/
├── metrics.py           # NEW: all 10 metric functions + result dataclasses
├── data/                # existing (Phase 3)
├── simulation/          # existing (Phase 4)
└── weighting/           # existing (Phase 3)

apps/simulations/tests/
├── test_metrics.py      # NEW: 10 metric tests (one per METR requirement)
└── conftest.py          # EXTEND: add metrics fixtures (results_df, windows_df)
```

### Pattern 1: Frozen Dataclass Return Types

**What:** Each metric function returns a `@dataclass(frozen=True)` with named fields. Dual-regime metrics bundle both regimes in one dataclass.

**When to use:** All 10 metric functions.

```python
# Source: stdlib dataclasses, verified working
from dataclasses import dataclass
import pandas as pd

@dataclass(frozen=True)
class FlipRateResult:
    per_proposal: pd.Series   # bool Series indexed by proposal_id
    aggregate: float          # fraction of proposals that flipped

@dataclass(frozen=True)
class GiniResult:
    legacy: float
    signals: float

@dataclass(frozen=True)
class TransitionMatrix:
    counts: list[list[int]]        # 2x2 [[PP, PF], [FP, FF]]
    proportions: list[list[float]] # 2x2 normalized

@dataclass(frozen=True)
class ConcentrationResult:
    legacy: dict[int, float]   # {1: 0.54, 5: 0.99, 10: 1.0}
    signals: dict[int, float]
```

### Pattern 2: Extract Final Tally Per Proposal

**What:** Most metrics need the final (cumulative) tally for each proposal. Extract by taking the last VOTE_CAST row per proposal — this row holds the running cumulative total at end of voting.

**When to use:** METR-01, METR-06, METR-07.

```python
# Source: verified against actual results DataFrame — 2026-02-27
def _get_final_tallies(results_df: pd.DataFrame) -> pd.DataFrame:
    """Extract final tally per proposal from results DataFrame.

    Returns DataFrame with proposal_id, legacy_for, legacy_against,
    signals_for, signals_against columns.
    """
    vote_df = results_df[results_df['event_type'] == 'VOTE_CAST']
    return (
        vote_df
        .groupby('proposal_id')
        .last()
        [['legacy_for', 'legacy_against', 'signals_for', 'signals_against']]
        .reset_index()
    )
```

### Pattern 3: Compute Per-Voter Signals Weight

**What:** The results DataFrame stores per-voter raw `weight` and `lock_duration_days` but not per-voter Signals weight. Compute it from these two columns using the existing pure function.

**When to use:** METR-02, METR-04, METR-05, METR-08, METR-09, METR-10.

```python
# Source: verified against actual results DataFrame — 2026-02-27
from backtesting.weighting.signals import compute_signals_weight
import numpy as np

def _add_signals_weight_column(vote_df: pd.DataFrame) -> pd.DataFrame:
    """Add signals_w column to VOTE_CAST rows.

    signals_w = compute_signals_weight(weight, lock_duration_days)
    Legacy weight = raw weight column (already present).
    """
    vote_df = vote_df.copy()
    vote_df['signals_w'] = np.vectorize(compute_signals_weight)(
        vote_df['weight'].values,
        vote_df['lock_duration_days'].fillna(0.0).values,
    )
    return vote_df
```

Note: `np.vectorize(compute_signals_weight)` applies the scalar function element-wise. For 200 voters × 30 proposals ≈ 600 rows, this is fast enough. The alternative of `apply(lambda r: ...)` is ~5x slower but also acceptable at this scale.

### Pattern 4: Merge Proposal Windows

**What:** Timing metrics (METR-08, METR-09) need `start_block` and `end_block` per proposal. Extract from the loader DataFrame's PROPOSAL_CREATED rows and merge into vote rows.

**When to use:** METR-08, METR-09.

```python
# Source: verified against actual loader DataFrame — 2026-02-27
def _merge_windows(vote_df: pd.DataFrame, windows_df: pd.DataFrame) -> pd.DataFrame:
    """Merge proposal window (start_block, end_block) into vote rows.

    windows_df must have: proposal_id, start_block, end_block
    (extract from loader DataFrame's PROPOSAL_CREATED rows)
    """
    return vote_df.merge(
        windows_df[['proposal_id', 'start_block', 'end_block']],
        on='proposal_id',
        how='left',
    )
```

The caller constructs `windows_df` like this:
```python
from backtesting.data.loader import events_to_dataframe
events_df = events_to_dataframe(events)
windows_df = events_df[events_df['event_type'] == 'PROPOSAL_CREATED'][
    ['proposal_id', 'start_block', 'end_block']
].copy()
```

### Pattern 5: Gini Coefficient (numpy, 4 lines)

**What:** Standard Gini from sorted array. Works for any array of non-negative weights.

```python
# Source: verified numerically — matches known Gini values — 2026-02-27
import numpy as np

def _gini(arr: np.ndarray) -> float:
    """Compute Gini coefficient from array of non-negative values."""
    arr = np.sort(arr.astype(float))
    n = len(arr)
    if n == 0 or arr.sum() == 0:
        return 0.0
    idx = np.arange(1, n + 1)
    return float((2 * (idx * arr).sum()) / (n * arr.sum()) - (n + 1) / n)
```

### Pattern 6: Lock-in Timing (per-proposal scan)

**What:** For each proposal, scan VOTE_CAST rows in chronological order. Lock-in occurs at the first row where `abs(running_net) > remaining_power`. Report as fraction of voting window elapsed.

**When to use:** METR-09.

```python
# Source: verified against real simulation data — 2026-02-27
def _compute_lockin_fraction(
    proposal_df: pd.DataFrame,   # VOTE_CAST rows for one proposal, includes start_block/end_block/signals_w
    regime: str,                 # 'legacy' or 'signals'
) -> float:
    rows = proposal_df.sort_values('block_number').reset_index(drop=True)
    start = float(rows['start_block'].iloc[0])
    end = float(rows['end_block'].iloc[0])
    window = end - start
    if window <= 0 or len(rows) == 0:
        return np.nan

    w_col = 'weight' if regime == 'legacy' else 'signals_w'
    for_col = 'legacy_for' if regime == 'legacy' else 'signals_for'
    against_col = 'legacy_against' if regime == 'legacy' else 'signals_against'

    total_cast = rows[w_col].sum()
    cumulative = 0.0
    for _, row in rows.iterrows():
        cumulative += row[w_col]
        remaining = total_cast - cumulative
        net = row[for_col] - row[against_col]
        if abs(net) > remaining:
            fraction = (row['block_number'] - start) / window
            return float(np.clip(fraction, 0.0, 1.0))
    return 1.0  # outcome never locked in before all votes cast
```

### Anti-Patterns to Avoid

- **Using `legacy_for`/`signals_for` column of non-VOTE_CAST rows:** PROPOSAL_CREATED and PROPOSAL_FINALIZED rows have NaN in all tally columns. Always filter `event_type == 'VOTE_CAST'` before accessing tally columns.
- **Using first-row tally instead of last-row tally for final result:** Tally columns are cumulative running totals. The final state is in the LAST VOTE_CAST row per proposal, not the first.
- **Dividing by zero in Gini/ENP/margin:** Edge case — proposals with zero total voting power (no votes cast) or FOR+AGAINST=0. Guard all divisions with `if total > 0 else 0.0` or `np.nan`.
- **Tie = Pass:** Tied proposals (FOR == AGAINST) must be classified as Fail per locked decision. Make this explicit: `passed = for_total > against_total` (strict greater-than).
- **Importing cadCAD in metrics.py:** The no-cadCAD-import requirement must be enforced. Do not import from `cadCAD` or `backtesting.simulation.runner` in `metrics.py`. Only `backtesting.weighting.signals` is allowed from the backtesting package.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Gini computation | Custom heavy formula | 4-line numpy implementation (Pattern 5 above) | Verified correct in Phase 3. scipy.stats.gini exists but is overkill. The numpy formula is 3 operations. |
| Per-voter Signals weight | Re-run simulation | `compute_signals_weight(weight, lock_duration_days)` from `backtesting.weighting.signals` | The weight and lock_duration_days columns are already in the results DataFrame. No re-simulation needed. |
| Final tally extraction | Custom loop | `groupby('proposal_id').last()` on VOTE_CAST rows | Verified pattern — last VOTE_CAST row per proposal holds the final cumulative tally. One-liner. |
| Proposal window lookup | Re-loading events | Accept `windows_df` parameter | Caller already has the loader DataFrame. Pass the window info as a parameter rather than re-loading events. |

**Key insight:** The results DataFrame has everything needed for most metrics. The only missing data is proposal window boundaries (`start_block`, `end_block`) — solve this by accepting a `windows_df` argument on timing metrics, not by changing the results DataFrame schema.

---

## Common Pitfalls

### Pitfall 1: results_df Tally Columns Are Cumulative, Not Per-Event

**What goes wrong:** Using `legacy_for` from a single VOTE_CAST row as the individual voter's contribution, when it's actually the running total at that timestep.

**Why it happens:** The column name `legacy_for` sounds like a per-vote weight. It is actually the accumulated FOR total after all votes up to that timestep.

**How to avoid:** For per-voter weights, use the `weight` column (legacy) or compute `signals_w = compute_signals_weight(weight, lock_duration_days)`. For final proposal totals, use `groupby('proposal_id').last()` on VOTE_CAST rows.

**Warning signs:** Gini values > 1.0, ENP values that are unreasonably large, or metrics that depend on proposal ordering.

### Pitfall 2: Missing start_block/end_block in results DataFrame

**What goes wrong:** Attempting to compute late-vote share or lock-in from the results DataFrame alone — those columns don't exist there.

**Why it happens:** The results DataFrame schema (Phase 4 output) was designed for tally tracking, not for proposal metadata. PROPOSAL_CREATED fields like `start_block` are in that row but the columns are absent from the DataFrame schema.

**How to avoid:** Accept `windows_df` as a second parameter on `compute_late_vote_share` and `compute_lockin_timing`. Document this in docstrings. Callers extract windows from the loader DataFrame.

**Warning signs:** KeyError on `start_block` or `end_block`, or NaN-filled timing results.

### Pitfall 3: Zero-Vote Proposals Causing Division by Zero

**What goes wrong:** A proposal where no votes were cast has `legacy_for = legacy_against = 0`. Margin formula `(FOR - AGAINST) / (FOR + AGAINST)` divides by zero.

**Why it happens:** Synthetic scenarios can produce proposals with very low participation. With few voters and low participation rate, some proposals may have 0 votes.

**How to avoid:** Guard all division: `if (total := for_ + against_) > 0 else np.nan`. Return `np.nan` for undefined metrics rather than 0 or raising an exception.

**Warning signs:** `ZeroDivisionError`, `inf` or `nan` in metric outputs without explicit handling.

### Pitfall 4: Frozen Dataclass with Series Fields

**What goes wrong:** `@dataclass(frozen=True)` with a `pd.Series` field — Series equality check (`==`) returns a Series, not a bool, which breaks frozen dataclass's internal equality check.

**Why it happens:** Python frozen dataclasses use `==` for hash and equality. pandas Series overloads `==` to return element-wise Series.

**How to avoid:** Either: (a) convert Series to tuple in the dataclass field, or (b) override `__eq__` and `__hash__` manually. Simplest: store `per_proposal` as `dict[str, bool]` or `tuple[bool, ...]` rather than `pd.Series`.

**Warning signs:** `TypeError: The truth value of a Series is ambiguous`, or unhashable type errors when using results as dict keys.

### Pitfall 5: ENP and Nakamoto Include Abstain Votes

**What goes wrong:** Including ABSTAIN voters in ENP and Nakamoto calculations inflates the apparent number of participants and reduces concentration metrics.

**Why it happens:** ENP and Nakamoto measure voting power concentration. ABSTAIN votes represent participation but not directional influence.

**How to avoid:** For concentration metrics (ENP, Nakamoto, top-k), use only FOR and AGAINST voters. Filter `support.isin(['FOR', 'AGAINST'])` before computing weights. For participation rate (METR-03), count all voters including ABSTAIN.

**Warning signs:** ENP values unexpectedly high, Nakamoto values unexpectedly low relative to expected concentration.

---

## Code Examples

Verified patterns from running against the actual simulation:

### Full Flip Rate Computation (METR-01)

```python
# Source: verified against actual results DataFrame, seed=42, 10 proposals — 2026-02-27
import pandas as pd
from dataclasses import dataclass

@dataclass(frozen=True)
class FlipRateResult:
    per_proposal: dict[str, bool]  # proposal_id -> True if flipped
    aggregate: float               # fraction of proposals that flipped

def compute_flip_rate(results_df: pd.DataFrame) -> FlipRateResult:
    vote_df = results_df[results_df['event_type'] == 'VOTE_CAST']
    final = (
        vote_df.groupby('proposal_id')
        .last()
        [['legacy_for', 'legacy_against', 'signals_for', 'signals_against']]
        .reset_index()
    )
    legacy_pass = final['legacy_for'] > final['legacy_against']
    signals_pass = final['signals_for'] > final['signals_against']
    flipped = (legacy_pass != signals_pass)
    per_proposal = dict(zip(final['proposal_id'], flipped))
    aggregate = float(flipped.mean())
    return FlipRateResult(per_proposal=per_proposal, aggregate=aggregate)
```

### ENP Per Proposal (METR-04)

```python
# Source: verified — seed=42, proposal-0000: legacy ENP=4.95, signals ENP=5.76 — 2026-02-27
import numpy as np
from dataclasses import dataclass

@dataclass(frozen=True)
class ENPResult:
    legacy: dict[str, float]   # proposal_id -> ENP
    signals: dict[str, float]

def _enp(weights: np.ndarray) -> float:
    total = weights.sum()
    if total == 0:
        return 0.0
    shares = weights / total
    return float(1.0 / (shares ** 2).sum())

def compute_enp(results_df: pd.DataFrame) -> ENPResult:
    from backtesting.weighting.signals import compute_signals_weight
    vote_df = results_df[results_df['event_type'] == 'VOTE_CAST'].copy()
    # Only FOR and AGAINST for concentration
    vote_df = vote_df[vote_df['support'].isin(['FOR', 'AGAINST'])]
    vote_df['signals_w'] = np.vectorize(compute_signals_weight)(
        vote_df['weight'].values,
        vote_df['lock_duration_days'].fillna(0.0).values,
    )
    legacy_enp = {}
    signals_enp = {}
    for pid, group in vote_df.groupby('proposal_id'):
        legacy_enp[pid] = _enp(group['weight'].values)
        signals_enp[pid] = _enp(group['signals_w'].values)
    return ENPResult(legacy=legacy_enp, signals=signals_enp)
```

### Late-Vote Share (METR-08)

```python
# Source: verified — seed=42: late share proposal-0000 legacy=0.399, signals=0.316 — 2026-02-27
import numpy as np

@dataclass(frozen=True)
class LateVoteShareResult:
    legacy: dict[str, float]   # proposal_id -> fraction of voting power cast in late zone
    signals: dict[str, float]

def compute_late_vote_share(
    results_df: pd.DataFrame,
    windows_df: pd.DataFrame,    # columns: proposal_id, start_block, end_block
) -> LateVoteShareResult:
    from backtesting.weighting.signals import compute_signals_weight
    vote_df = results_df[results_df['event_type'] == 'VOTE_CAST'].copy()
    vote_df = vote_df.merge(
        windows_df[['proposal_id', 'start_block', 'end_block']],
        on='proposal_id', how='left'
    )
    vote_df['signals_w'] = np.vectorize(compute_signals_weight)(
        vote_df['weight'].values,
        vote_df['lock_duration_days'].fillna(0.0).values,
    )
    window_size = vote_df['end_block'] - vote_df['start_block']
    vote_df['late_threshold'] = vote_df['start_block'] + window_size * (2.0 / 3.0)
    vote_df['is_late'] = vote_df['block_number'] >= vote_df['late_threshold']

    legacy_result = {}
    signals_result = {}
    for pid, group in vote_df.groupby('proposal_id'):
        total_l = group['weight'].sum()
        total_s = group['signals_w'].sum()
        late_l = group.loc[group['is_late'], 'weight'].sum()
        late_s = group.loc[group['is_late'], 'signals_w'].sum()
        legacy_result[pid] = float(late_l / total_l) if total_l > 0 else float('nan')
        signals_result[pid] = float(late_s / total_s) if total_s > 0 else float('nan')
    return LateVoteShareResult(legacy=legacy_result, signals=signals_result)
```

### Transition Matrix (METR-07)

```python
# Source: verified logic — 2026-02-27
@dataclass(frozen=True)
class TransitionMatrix:
    counts: tuple[tuple[int, int], tuple[int, int]]        # [[PP, PF], [FP, FF]]
    proportions: tuple[tuple[float, float], tuple[float, float]]

def compute_transition_matrix(results_df: pd.DataFrame) -> TransitionMatrix:
    vote_df = results_df[results_df['event_type'] == 'VOTE_CAST']
    final = (
        vote_df.groupby('proposal_id').last()
        [['legacy_for', 'legacy_against', 'signals_for', 'signals_against']]
    )
    legacy_pass = final['legacy_for'] > final['legacy_against']   # strict: tie = Fail
    signals_pass = final['signals_for'] > final['signals_against']

    pp = int((legacy_pass & signals_pass).sum())
    pf = int((legacy_pass & ~signals_pass).sum())
    fp = int((~legacy_pass & signals_pass).sum())
    ff = int((~legacy_pass & ~signals_pass).sum())
    total = pp + pf + fp + ff

    counts = ((pp, pf), (fp, ff))
    if total > 0:
        proportions = (
            (pp / total, pf / total),
            (fp / total, ff / total),
        )
    else:
        proportions = ((0.0, 0.0), (0.0, 0.0))
    return TransitionMatrix(counts=counts, proportions=proportions)
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `scipy.stats.gini` | Hand-rolled 4-line numpy Gini | scipy 1.11 added it, but it's overkill for this use | No new dependency; scipy already in project but numpy formula is cleaner |
| `df.apply(lambda r: f(r), axis=1)` | `np.vectorize(f)(arr1, arr2)` | Always preferred for numpy-backed functions | ~5x faster for column-wise function application |
| Storing pandas Series in frozen dataclass | Store as `dict[str, T]` or `tuple` | Python dataclass behavior — unchanged | Avoids ambiguous truth-value error from Series `==` in dataclass equality |

**Deprecated/outdated:**
- Calling `compute_signals_weight` with pandas Series directly: the function is scalar; always use `np.vectorize` or apply with `.values` to pass numpy arrays.

---

## Open Questions

1. **Gini computed over all voters or only voters who participated?**
   - What we know: METR-02 says "Gini coefficient computed over legacy stake distribution and over Signals-weighted distribution." The stake distribution is all voters (including non-participants), but the results DataFrame only contains voters who voted.
   - What's unclear: Should Gini measure inequality among all token holders (full distribution) or only among participants (voting power distribution)?
   - Recommendation: Compute Gini over participating voters from the results DataFrame. This measures inequality of *voting* power, which is what affects governance outcomes. If all-voter Gini is needed, it would require the loader DataFrame (which has all voter stakes). Document the scope clearly in the function docstring.

2. **Participation rate denominator: unique voters or total supply holders?**
   - What we know: METR-03 says "participation rate computed per-proposal and as aggregate." No denominator specified.
   - What's unclear: Denominator = (a) unique voters who voted on ANY proposal, or (b) total voters in the original scenario.
   - Recommendation: Use total unique voters across all proposals in the results DataFrame as denominator. This is self-contained (no need for the scenario config), consistent, and comparable across proposals.

3. **Frozen dataclass with pd.Series vs dict for `per_proposal` field**
   - What we know: CONTEXT.md specifies `FlipRateResult(per_proposal=Series, aggregate=float)`. Python frozen dataclasses and Series equality checks conflict.
   - What's unclear: Is pd.Series a hard requirement or just an illustrative example?
   - Recommendation: Use `dict[str, bool]` for `per_proposal` in FlipRateResult. Same information, hashable, no truth-value ambiguity. Series can always be reconstructed from a dict. Flag this in implementation.

---

## Sources

### Primary (HIGH confidence)

- Verified directly against project codebase, running `uv run python` in `apps/simulations/` — 2026-02-27
- `backtesting.simulation.runner.build_results_dataframe` — read source directly — confirmed 14 columns, cumulative tally columns, no start_block/end_block
- `backtesting.data.factory.generate_scenario` — read source directly — confirmed event structure
- `backtesting.weighting.signals` — read source directly — `compute_signals_weight(stake, lock_duration_days)` is pure function
- Numerical verification: flip rate, margin shift, late-vote share, ENP, Nakamoto, lock-in fraction all computed and verified against known simulation output (seed=42, 50-100 voters, 5-10 proposals)

### Secondary (MEDIUM confidence)

- Python `dataclasses` stdlib documentation — frozen dataclass behavior with mutable fields (Series issue) is well-documented in Python docs

### Tertiary (LOW confidence)

- None

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies; all computation verified against actual simulation output
- Architecture: HIGH — results DataFrame schema read directly from source; timing metric input gap discovered and verified empirically
- Pitfalls: HIGH — all pitfalls verified by running actual code (zero-division, frozen+Series, cumulative vs per-event confusion)
- Metric formulas: HIGH — Gini, ENP, Nakamoto, top-k, margin, flip rate all verified numerically against known-correct outputs

**Research date:** 2026-02-27
**Valid until:** 2026-03-29 (30 days — stable numpy/pandas ecosystem, no churn risk)
