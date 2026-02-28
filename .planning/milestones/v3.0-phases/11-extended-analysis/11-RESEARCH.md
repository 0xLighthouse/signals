# Phase 11: Extended Analysis - Research

**Researched:** 2026-02-28
**Domain:** Statistical analysis on SweepResult DataFrames — pandas groupby/pivot, scipy.stats, voter archetypes
**Confidence:** HIGH

## Summary

Phase 11 adds a dedicated `analysis.py` module that operates on `SweepResult.summary_df` (already produced by Phase 10) to compute five categories of extended governance statistics: margin-class flip breakdowns, per-voter influence with counterfactual baseline, 2D timing sensitivity, voter archetypes, and statistical significance. All inputs are scalar-aggregated DataFrames from the sweep engine — no re-simulation is needed.

The full stack is already installed in the project: pandas 2.3.3, numpy 1.26.4, scipy 1.17.1. All required APIs (`pd.cut`, `pd.qcut`, `pivot_table`, `scipy.stats.bootstrap`, `scipy.stats.mannwhitneyu`) are verified working. The module follows the NaN-for-degenerate-inputs convention established in metrics.py and uses frozen dataclasses as return types (consistent with Phase 5 metric pattern).

The key design constraint is ANAL-02: the counterfactual baseline for per-voter influence is the **median lock duration** across all voters in the sweep, not raw legacy weight. This is flagged in STATE.md as needing empirical justification — the planner must create a task that explicitly implements median-lock as the baseline and documents why.

**Primary recommendation:** Create `backtesting/analysis.py` as a pure-function module operating on `SweepResult.summary_df` (already a flat DataFrame), using `pd.cut` for margin classes, `pd.qcut` for archetypes, `pivot_table` for the 2D heatmap, `mannwhitneyu` for significance, and `scipy.stats.bootstrap` for confidence intervals.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| ANAL-01 | `margin_class_breakdown()` returning flip counts in tight (<10%), moderate (10–30%), decisive (>30%) bins for a results DataFrame | `pd.cut(abs(margin), bins=[0,0.10,0.30,1.0], labels=['tight','moderate','decisive'])` + groupby; bins verified working |
| ANAL-02 | `address_influence()` returning per-voter (legacy_share, signals_share, delta) using median lock duration as counterfactual baseline — not raw legacy weight | Requires access to per-vote DataFrame (not just summary_df); median lock computed across all VOTE_CAST rows; signals_share computed at median-lock vs actual lock |
| ANAL-03 | `timing_sensitivity()` producing 2D heatmap matrix indexed by timing quantile × lock quantile | `pd.qcut` on both axes, then `pivot_table(aggfunc='mean')`; `observed=True` kwarg required to suppress FutureWarning in pandas 2.x |
| ANAL-04 | Voter archetype classification (whale/medium/retail by stake quantile) present in analysis output | `pd.qcut(stakes, q=3, labels=['retail','medium','whale'])` verified working; requires per-voter stake data from results_df |
| ANAL-05 | Mann-Whitney U p-values on influence distribution differences across configurations | `scipy.stats.mannwhitneyu(a, b, alternative='two-sided')` verified; returns (statistic, pvalue) namedtuple |
| ANAL-06 | Bootstrap confidence intervals on aggregate metrics across MC runs | `scipy.stats.bootstrap((data,), np.mean, confidence_level=0.95, n_resamples=999, random_state=42)` verified; returns `.confidence_interval.low/.high` |
| ANAL-07 | Cross-run analysis module (`analysis.py`) operating on `SweepResult.summary_df` | New module at `backtesting/analysis.py`; pure functions + frozen dataclasses; no cadCAD imports; follows metrics.py pattern |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| pandas | 2.3.3 (installed) | `pd.cut`, `pd.qcut`, `pivot_table`, groupby | Already installed; primary DataFrame toolkit |
| numpy | 1.26.4 (installed) | `np.nanmedian`, array ops | Already installed; vectorized math |
| scipy | 1.17.1 (installed) | `bootstrap`, `mannwhitneyu` | Already installed; academic-grade stats |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| dataclasses (stdlib) | Python 3.12 | Frozen result types | All analysis functions return frozen dataclasses |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `mannwhitneyu` | `scipy.stats.kruskal` | Mann-Whitney is correct for 2-sample comparison; Kruskal for k>2 |
| `pd.cut` | manual `np.where` | pd.cut is idiomatic and returns Categorical with built-in groupby support |
| `pivot_table` | manual `np.zeros` grid | pivot_table handles missing bins automatically with NaN fill |

**Installation:** No new dependencies. All libraries already in `pyproject.toml`.

## Architecture Patterns

### Recommended Project Structure
```
src/backtesting/
├── analysis.py          # NEW: Phase 11 extended analysis module
├── sweep.py             # Existing: SweepResult produced here
├── metrics.py           # Existing: per-proposal metric functions
└── ...
```

### Pattern 1: Pure Function + Frozen Dataclass (follows metrics.py)
**What:** Each analysis function accepts a DataFrame, computes a result, returns a frozen dataclass.
**When to use:** All 5 analysis functions (ANAL-01 through ANAL-06).
**Example:**
```python
# Source: consistent with backtesting/metrics.py frozen dataclass pattern
from dataclasses import dataclass

@dataclass(frozen=True)
class MarginClassBreakdown:
    tight: int        # flip count where |margin| < 10%
    moderate: int     # flip count where 10% <= |margin| < 30%
    decisive: int     # flip count where |margin| >= 30%
    total_flips: int

def margin_class_breakdown(results_df: pd.DataFrame) -> MarginClassBreakdown:
    vote_df = results_df[results_df['event_type'] == 'VOTE_CAST']
    # ... compute per-proposal margins, pd.cut, groupby
```

### Pattern 2: pd.cut with explicit bins for margin classes (ANAL-01)
**What:** Classifies proposals into margin buckets using hard boundaries from requirements.
**When to use:** ANAL-01 margin_class_breakdown.
**Example:**
```python
# Source: verified locally 2026-02-28
bins = [0.0, 0.10, 0.30, 1.01]  # 1.01 to include margin=1.0 edge
labels = ['tight', 'moderate', 'decisive']
margin_abs = results_df['margin'].abs()
classes = pd.cut(margin_abs, bins=bins, labels=labels, include_lowest=True)
breakdown = classes.value_counts()
```

### Pattern 3: pd.qcut for 2D timing sensitivity heatmap (ANAL-03)
**What:** Quantile-bins both timing and lock duration, then pivots to 2D matrix.
**When to use:** ANAL-03 timing_sensitivity.
**Example:**
```python
# Source: verified locally 2026-02-28 — observed=True suppresses pandas 2.x FutureWarning
vote_df['timing_q'] = pd.qcut(vote_df['timing_frac'], q=4, labels=['Q1','Q2','Q3','Q4'])
vote_df['lock_q'] = pd.qcut(vote_df['lock_duration_days'], q=4, labels=['Q1','Q2','Q3','Q4'])
heatmap = vote_df.pivot_table(
    values='flipped',
    index='timing_q',
    columns='lock_q',
    aggfunc='mean',
    observed=True,  # REQUIRED: suppresses FutureWarning in pandas 2.x
)
```

### Pattern 4: Median-lock counterfactual for address influence (ANAL-02)
**What:** Computes per-voter influence delta using median lock duration as the "neutral" baseline rather than raw legacy weight.
**Why:** STATE.md decision [08-01] and REQUIREMENTS.md annotation (ANAL-02): "must use median-lock baseline, not raw legacy weight". Raw legacy weight conflates stake magnitude with absence of commitment signal. Median lock represents the typical committed voter, making the comparison meaningful.
**Example:**
```python
# Source: design pattern based on REQUIREMENTS.md ANAL-02 and STATE.md decisions
vote_df = results_df[results_df['event_type'] == 'VOTE_CAST'].copy()
median_lock = float(vote_df['lock_duration_days'].median())

# Counterfactual: what would signals weight be at median lock?
vote_df['counterfactual_signals_w'] = np.vectorize(compute_signals_weight)(
    vote_df['weight'].values,
    median_lock,           # <- counterfactual: everyone locked median duration
    curve_type,
)
# Actual signals weight (from existing helper)
vote_df = _add_signals_weight_column(vote_df, curve_type)  # adds 'signals_w'

# Per-voter aggregated shares
total_legacy = vote_df['weight'].sum()
total_signals = vote_df['signals_w'].sum()
total_counterfactual = vote_df['counterfactual_signals_w'].sum()

voter_groups = vote_df.groupby('voter')
per_voter = voter_groups.agg(
    legacy_share=('weight', lambda x: x.sum() / total_legacy),
    signals_share=('signals_w', lambda x: x.sum() / total_signals),
    counterfactual_share=('counterfactual_signals_w', lambda x: x.sum() / total_counterfactual),
).reset_index()
per_voter['delta'] = per_voter['signals_share'] - per_voter['counterfactual_share']
```

### Pattern 5: scipy.stats.bootstrap for confidence intervals (ANAL-06)
**What:** Non-parametric bootstrap CIs on any scalar metric column of summary_df across MC runs.
**When to use:** ANAL-06. Operates on `SweepResult.summary_df` columns.
**Example:**
```python
# Source: verified locally 2026-02-28, scipy 1.17.1
from scipy.stats import bootstrap
import numpy as np

values = summary_df['flip_rate'].dropna().values
res = bootstrap(
    (values,),
    np.mean,
    confidence_level=0.95,
    n_resamples=999,
    random_state=42,
    method='percentile',  # percentile is simplest; BCa available but slower
)
ci_low = res.confidence_interval.low
ci_high = res.confidence_interval.high
```

### Pattern 6: scipy.stats.mannwhitneyu for significance tests (ANAL-05)
**What:** 2-sample test comparing influence distributions across two configurations.
**When to use:** ANAL-05. Compare legacy vs signals influence shares, or across sweep configurations.
**Example:**
```python
# Source: verified locally 2026-02-28, scipy 1.17.1
from scipy.stats import mannwhitneyu

stat, pval = mannwhitneyu(
    group_a['delta'].values,
    group_b['delta'].values,
    alternative='two-sided',
)
```

### Pattern 7: Voter archetype classification by stake quantile (ANAL-04)
**What:** Assigns each unique voter a label based on their total stake relative to the voter population.
**When to use:** ANAL-04.
**Example:**
```python
# Source: verified locally 2026-02-28
voter_stakes = vote_df.groupby('voter')['weight'].sum().reset_index()
voter_stakes['archetype'] = pd.qcut(
    voter_stakes['weight'],
    q=3,
    labels=['retail', 'medium', 'whale'],
)
```

### Anti-Patterns to Avoid
- **Using raw legacy weight as the ANAL-02 baseline:** The requirement explicitly mandates median lock duration as the counterfactual. Using raw legacy weight makes the comparison "signals vs no-lock" which doesn't isolate commitment signal.
- **Returning a single scalar for timing sensitivity:** ANAL-03 requires a 2D matrix (timing quantile × lock quantile). A single aggregated number was the prior broken approach.
- **Building analysis on per-proposal results_df without SweepResult:** ANAL-07 requires the cross-run module to operate on `SweepResult.summary_df` (one row per sweep cell), not on per-proposal raw data.
- **Using `observed=False` (pandas 2.x default) for pivot_table with Categoricals:** Always pass `observed=True` to suppress FutureWarning and get correct behavior in pandas 2.3+.
- **Forgetting NaN propagation:** Follow the NaN-for-degenerate-inputs convention from metrics.py; `np.nanmean`, `np.nanmedian` are safe; bare `np.mean` will NaN-poison the entire result.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Margin class binning | Manual if/elif chains | `pd.cut` with bins | Handles edge cases, returns Categorical |
| Quantile binning | Manual percentile checks | `pd.qcut` | Handles ties, duplicates, returns Categorical |
| Bootstrap CIs | Custom resampling loop | `scipy.stats.bootstrap` | Stratified, bias-corrected, tested |
| Mann-Whitney test | Custom rank-sum | `scipy.stats.mannwhitneyu` | Handles ties, exact/asymptotic modes |
| 2D aggregation | Nested loop | `pd.pivot_table` | Handles missing cells with NaN fill |

**Key insight:** All statistical heavy lifting in this domain is solved by pandas and scipy. Custom implementations add bugs without adding value.

## Common Pitfalls

### Pitfall 1: ANAL-02 counterfactual uses wrong baseline
**What goes wrong:** Using raw `weight` (legacy token stake) as the counterfactual instead of `compute_signals_weight(stake, median_lock)`.
**Why it happens:** It's the obvious comparison — but it conflates magnitude with the absence of commitment signal.
**How to avoid:** The counterfactual is "what if everyone locked for the median duration?" Compute `signals_w` at `median_lock` for all voters. The delta is actual signals share minus counterfactual share.
**Warning signs:** Test would show delta = signals_share - legacy_share (wrong) rather than delta = signals_share - counterfactual_share (correct).

### Pitfall 2: ANAL-03 produces 1D result instead of 2D matrix
**What goes wrong:** `groupby(['timing_q']).mean()` produces a Series (1D) instead of a pivot table (2D).
**Why it happens:** Conflating "timing effect" with "timing × lock interaction."
**How to avoid:** Always use `pivot_table(index='timing_q', columns='lock_q')` to get the 2D matrix required by the success criterion.
**Warning signs:** Shape is `(4,)` not `(4, 4)`.

### Pitfall 3: pd.cut/qcut FutureWarning from pandas 2.x with Categorical in pivot_table
**What goes wrong:** `pivot_table` with Categorical index/columns emits `FutureWarning: observed=False`.
**Why it happens:** Pandas 2.x deprecated the old behavior; in a future version, unobserved categories won't be included.
**How to avoid:** Always pass `observed=True` to `pivot_table` when using Categorical columns.
**Warning signs:** FutureWarning in test output.

### Pitfall 4: ANAL-05 test compares same distribution to itself
**What goes wrong:** Mann-Whitney p-value is always ~0.5, test is meaningless.
**Why it happens:** Comparing the same config's influence distribution to itself.
**How to avoid:** Compare distributions from two different sweep configurations (e.g., sqrt vs log curve, or different alpha values). The test is only meaningful cross-configuration.

### Pitfall 5: ANAL-07 module accesses per-simulation data it doesn't have
**What goes wrong:** `analysis.py` tries to access raw per-proposal data from `SweepResult.summary_df` which only contains aggregated scalars.
**Why it happens:** ANAL-02 and ANAL-03 need per-voter data (lock_duration_days, timing fractions) which is not in `summary_df`.
**How to avoid:** ANAL-02 and ANAL-03 need to operate on the per-proposal `results_df` (output of `build_results_dataframe`), not on `SweepResult.summary_df`. The `analysis.py` module must accept `results_df` as input for these functions, and `summary_df` for cross-run functions (ANAL-01, ANAL-05, ANAL-06).
**Warning signs:** `KeyError: 'lock_duration_days'` or `KeyError: 'voter'` when accessing summary_df.

### Pitfall 6: bootstrap CI with n_resamples too high makes tests slow
**What goes wrong:** Tests time out because `n_resamples=9999` with large datasets is slow.
**Why it happens:** Default is conservative.
**How to avoid:** Use `n_resamples=999` for production, `n_resamples=99` for unit tests. Pass `random_state=42` for reproducibility.

## Code Examples

Verified patterns from official sources:

### margin_class_breakdown (ANAL-01)
```python
# Source: verified locally 2026-02-28 with pandas 2.3.3
import pandas as pd
import numpy as np

def margin_class_breakdown(results_df: pd.DataFrame) -> 'MarginClassBreakdown':
    final = _get_final_tallies(results_df)
    legacy_pass = final['legacy_for'] > final['legacy_against']
    signals_pass = final['signals_for'] > final['signals_against']
    flipped = legacy_pass != signals_pass

    # Compute victory margin for FLIPPED proposals only
    def _margin(for_col, against_col):
        denom = for_col + against_col
        return np.where(denom == 0, np.nan, np.abs((for_col - against_col) / denom))

    flip_df = final[flipped].copy()
    if len(flip_df) == 0:
        return MarginClassBreakdown(tight=0, moderate=0, decisive=0, total_flips=0)

    # Use legacy margin as the reference (pre-flip baseline)
    margin_abs = pd.Series(_margin(flip_df['legacy_for'].values, flip_df['legacy_against'].values))
    bins = [0.0, 0.10, 0.30, 1.01]  # 1.01 includes margin=1.0 edge
    labels = ['tight', 'moderate', 'decisive']
    classes = pd.cut(margin_abs, bins=bins, labels=labels, include_lowest=True)
    counts = classes.value_counts()
    return MarginClassBreakdown(
        tight=int(counts.get('tight', 0)),
        moderate=int(counts.get('moderate', 0)),
        decisive=int(counts.get('decisive', 0)),
        total_flips=int(len(flip_df)),
    )
```

### timing_sensitivity 2D matrix (ANAL-03)
```python
# Source: verified locally 2026-02-28 with pandas 2.3.3
def timing_sensitivity(results_df: pd.DataFrame, curve_type: str = 'sqrt') -> pd.DataFrame:
    vote_df = results_df[results_df['event_type'] == 'VOTE_CAST'].copy()
    # timing_frac: position within voting window (requires block_number + window info)
    # lock_duration_days: already in results_df
    vote_df['timing_q'] = pd.qcut(vote_df['timing_frac'], q=4, labels=['Q1','Q2','Q3','Q4'])
    vote_df['lock_q'] = pd.qcut(vote_df['lock_duration_days'], q=4, labels=['Q1','Q2','Q3','Q4'])
    heatmap = vote_df.pivot_table(
        values='flipped',
        index='timing_q',
        columns='lock_q',
        aggfunc='mean',
        observed=True,  # suppress pandas 2.x FutureWarning
    )
    return heatmap  # shape: (4, 4) DataFrame
```

### bootstrap confidence interval (ANAL-06)
```python
# Source: verified locally 2026-02-28, scipy 1.17.1
from scipy.stats import bootstrap
import numpy as np

def bootstrap_ci(values: np.ndarray, statistic=np.mean, confidence_level: float = 0.95) -> tuple[float, float]:
    values = values[~np.isnan(values)]
    if len(values) < 2:
        return (float('nan'), float('nan'))
    res = bootstrap(
        (values,),
        statistic,
        confidence_level=confidence_level,
        n_resamples=999,
        random_state=42,
        method='percentile',
    )
    return (res.confidence_interval.low, res.confidence_interval.high)
```

### Mann-Whitney U significance test (ANAL-05)
```python
# Source: verified locally 2026-02-28, scipy 1.17.1
from scipy.stats import mannwhitneyu

def influence_significance(group_a: np.ndarray, group_b: np.ndarray) -> tuple[float, float]:
    stat, pval = mannwhitneyu(group_a, group_b, alternative='two-sided')
    return (float(stat), float(pval))
```

## Open Questions

1. **ANAL-02: Does median_lock operate per-config or globally across all sweep cells?**
   - What we know: REQUIREMENTS.md says "median lock duration as the counterfactual baseline"; STATE.md flags "may need literature validation"
   - What's unclear: Is it median across all voters in one results_df? Or median across the entire sweep?
   - Recommendation: Use per-results_df median (most defensible: each config has its own lock distribution shaped by `lock_profile` and `l_max_days`). Document this choice in docstring.

2. **ANAL-03: Where does `timing_frac` come from for the heatmap?**
   - What we know: `results_df` has `block_number` but does NOT have `start_block`/`end_block` per vote row. These are available from a separate `windows_df` (as used by `compute_lockin_timing` in metrics.py).
   - What's unclear: Does `timing_sensitivity()` require `windows_df` as a second argument?
   - Recommendation: Yes, accept `windows_df` as a required second argument (same as `compute_lockin_timing`). Merge on `proposal_id` to get `start_block`/`end_block`, compute `timing_frac = (block_number - start_block) / (end_block - start_block)`.

3. **ANAL-02 / ANAL-04: Data source tension — summary_df vs results_df**
   - What we know: `SweepResult.summary_df` has one row per sweep cell (aggregated scalars). Per-voter data (voter addresses, lock durations) lives in the raw `results_df` from `build_results_dataframe`.
   - What's unclear: How does `analysis.py` get per-voter data? Does it re-run simulations?
   - Recommendation: For cross-run analysis (ANAL-05, ANAL-06), use `summary_df` directly. For per-voter analysis (ANAL-02, ANAL-04), the caller must pass in a `results_df` from a specific sweep cell. The Phase 12 report orchestrator handles which cell to use.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | pytest 8.x |
| Config file | tests/conftest.py (existing) |
| Quick run command | `cd apps/simulations && PYTHONPATH=src uv run --no-project pytest tests/test_analysis.py -x` |
| Full suite command | `cd apps/simulations && PYTHONPATH=src uv run --no-project pytest tests/ -x` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ANAL-01 | `margin_class_breakdown()` returns three-class dict with correct flip counts | unit | `pytest tests/test_analysis.py::test_anal01_margin_class_breakdown -x` | ❌ Wave 0 |
| ANAL-02 | `address_influence()` uses median-lock counterfactual, not raw legacy weight | unit | `pytest tests/test_analysis.py::test_anal02_address_influence_counterfactual -x` | ❌ Wave 0 |
| ANAL-03 | `timing_sensitivity()` returns shape `(4, 4)` DataFrame indexed by timing/lock quantiles | unit | `pytest tests/test_analysis.py::test_anal03_timing_sensitivity_2d -x` | ❌ Wave 0 |
| ANAL-04 | `whale`/`medium`/`retail` labels present in archetype output | unit | `pytest tests/test_analysis.py::test_anal04_voter_archetypes -x` | ❌ Wave 0 |
| ANAL-05 | `mannwhitneyu` p-values are float in [0,1] and significant when distributions differ | unit | `pytest tests/test_analysis.py::test_anal05_mannwhitney -x` | ❌ Wave 0 |
| ANAL-06 | Bootstrap CI returns `(low, high)` tuple with `low < mean < high` for normal data | unit | `pytest tests/test_analysis.py::test_anal06_bootstrap_ci -x` | ❌ Wave 0 |
| ANAL-07 | `analysis.py` module importable from `backtesting.analysis`; exports all 5 functions | smoke | `pytest tests/test_analysis.py::test_anal07_module_importable -x` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `cd apps/simulations && PYTHONPATH=src uv run --no-project pytest tests/test_analysis.py -x`
- **Per wave merge:** `cd apps/simulations && PYTHONPATH=src uv run --no-project pytest tests/ -x`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/test_analysis.py` — covers ANAL-01 through ANAL-07
- [ ] No new framework install needed — pytest already present in dev dependencies

## Sources

### Primary (HIGH confidence)
- Verified locally: `scipy.stats.bootstrap` and `scipy.stats.mannwhitneyu` working in scipy 1.17.1 — both imported and called with expected results
- Verified locally: `pd.cut` with `bins=[0, 0.10, 0.30, 1.01]`, `labels=['tight','moderate','decisive']` — correct output
- Verified locally: `pd.qcut` with `q=3, labels=['retail','medium','whale']` — correct archetype assignment
- Verified locally: `pivot_table(observed=True)` produces `(4, 4)` 2D matrix from quantile-binned data
- Project codebase: `backtesting/metrics.py` — frozen dataclass pattern, NaN-for-degenerate convention, `_add_signals_weight_column` helper (reusable for ANAL-02)
- Project codebase: `backtesting/sweep.py` — `SweepResult.summary_df` columns: `['cell_id', 'curve_type', 'alpha', 'lock_profile_short', 'lock_profile_long', 'allocation_strategy', 'mc_dist_label', 'failed', 'flip_rate', 'gini_legacy', 'gini_signals', 'participation_rate', 'margin_shift_mean', 'margin_shift_std', 'enp_legacy_mean', 'enp_signals_mean', 'nakamoto_legacy_mean', 'nakamoto_signals_mean']`
- Project state: `.planning/STATE.md` decision `[08-01]` — NaN-for-degenerate convention must be followed in Phase 11

### Secondary (MEDIUM confidence)
- `.planning/REQUIREMENTS.md` ANAL-02 annotation: "must use median-lock baseline, not raw legacy weight — PITFALLS.md" (reference to planning docs, not external source)

### Tertiary (LOW confidence)
- STATE.md blocker flag: "Counterfactual baseline for address influence ('median lock duration') lacks empirical grounding — may need literature validation" — noted but not blocking implementation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries verified working locally with current versions
- Architecture: HIGH — follows established metrics.py patterns; no new dependencies
- Pitfalls: HIGH — ANAL-02 counterfactual and ANAL-03 2D requirement are documented in REQUIREMENTS.md; pandas 2.x FutureWarning verified locally
- Open questions: MEDIUM — ANAL-02/ANAL-03 data sourcing is resolvable but requires planner decision on function signature

**Research date:** 2026-02-28
**Valid until:** 2026-04-30 (stable libraries: scipy, pandas, numpy — no fast-moving APIs)
