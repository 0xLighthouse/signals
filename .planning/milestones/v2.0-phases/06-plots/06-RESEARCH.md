# Phase 6: Plots - Research

**Researched:** 2026-02-27
**Domain:** matplotlib OO API, publication-grade figure design, governance metric visualization
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Visual style & theme**
- Color palette: Blue for legacy/status-quo, orange for Signals/new-regime — colorblind-safe, high contrast
- Font: Serif (Times-like) for all text — traditional academic/journal look
- Grid: Light gray horizontal grid lines only — helps read values without clutter
- rcParams set once at module import for consistency across all 11 chart types

**Comparison layout**
- Bar charts (flip rate, Gini, ENP, top-k): Grouped bars — legacy and Signals side-by-side per category
- Lorenz curve (PLOT-09): Both distributions overlaid on same axes with 45-degree equality line and shaded Gini area
- Margin shift histogram (PLOT-02): Per-proposal bars — x-axis = (Signals margin - Legacy margin), positive means Signals made result closer/flipped
- Every dual-regime chart includes its own legend — figures are self-contained for individual extraction

**Output format & saving**
- Each plot function returns a `matplotlib.figure.Figure` object — caller decides where/how to save
- Output formats: PDF (vector, publication) + PNG (preview, web) — both generated per plot by pipeline
- PNG at 300 DPI — standard print quality
- File naming: descriptive slugs (e.g., `flip_rate_summary.pdf`, `lorenz_curve.png`, `margin_shift_histogram.pdf`)

**Proposal story plots (PLOT-10)**
- One proposal per figure — caller loops for multiple proposals
- Y-axis: net margin over time = (FOR - AGAINST) / (FOR + AGAINST) running over votes
- Two lines per plot: legacy margin (blue) and Signals margin (orange)
- Annotate key moments: vertical dashed line at lock-in point, marker where outcome flips between regimes

**Cumulative vote curve (PLOT-07)**
- Y-axis: raw cumulative FOR votes (not net margin — distinct from PLOT-10)
- Two lines: legacy cumulative and Signals cumulative
- X-axis: vote order within the proposal

### Claude's Discretion
- Figure size per chart type (single-column vs wide as appropriate)
- Exact subplot arrangements for multi-panel figures
- Annotation positioning and styling details
- Color shading intensity for Lorenz area fills
- Lock duration histogram (PLOT-11) styling details

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PLOT-01 | Flip rate summary bar chart | Grouped bar via `ax.bar()` with `x - offset` / `x + offset` pattern; input: `FlipRateResult.aggregate` scalar + per-proposal booleans |
| PLOT-02 | Margin shift histogram (per-proposal bars) | Per-proposal horizontal bar chart `ax.barh()` with zero-line; input: `MarginShiftResult.per_proposal` dict |
| PLOT-03 | Outcome transition matrix visualization | `ax.imshow()` with text annotations in cells; input: `TransitionMatrix.counts` 2x2 tuple |
| PLOT-04 | Gini before vs after comparison | Two-bar grouped bar (single category pair); input: `GiniResult.legacy`, `GiniResult.signals` |
| PLOT-05 | Top-k share comparison chart | Grouped bars for k in {1,5,10} per proposal or aggregated; input: `TopKConcentrationResult` |
| PLOT-06 | ENP comparison visualization | Per-proposal grouped bars or line chart; input: `ENPResult.legacy`, `ENPResult.signals` dicts |
| PLOT-07 | Cumulative vote curve per proposal (legacy + Signals overlaid) | `ax.plot()` with two lines; needs cumulative FOR votes by vote order from results_df |
| PLOT-08 | Late-vote share comparison | Per-proposal or aggregated grouped bars; input: `LateVoteShareResult.legacy`, `.signals` |
| PLOT-09 | Lorenz curve (legacy vs Signals distributions) | `ax.plot()` + `ax.fill_between()` for shaded Gini area; equality line at 45deg; sorted cumulative weights |
| PLOT-10 | Proposal story plots — net margin over time | `ax.plot()` two lines with `ax.axvline()` lock-in marker; needs running margin from results_df |
| PLOT-11 | Lock duration histogram with Signals weight overlay | `ax.hist()` + `ax.twinx()` for weight curve; input: lock_duration_days column from results_df |
| PLOT-12 | All plots use matplotlib OO API, publication rcParams, consistent styling | Module-level `matplotlib.rcParams.update({})` + `matplotlib.use('Agg')` before any other import |
</phase_requirements>

## Summary

Phase 6 implements 11 publication-grade matplotlib figures as pure functions that each return a `matplotlib.figure.Figure` object. The OO API constraint (`Figure` → `add_subplot` → `ax.method()` — never `plt.*`) is verifiably satisfied with matplotlib 3.10.8 which is already installed in the project venv. The Agg backend supports headless rendering and `fig.savefig()` for both PDF and PNG at 300 DPI.

The metrics layer from Phase 5 supplies all data. Each of the 10 metric result dataclasses (`FlipRateResult`, `GiniResult`, etc.) maps directly to one or more plot functions. Two plots (`PLOT-07` cumulative curve, `PLOT-10` story plot) require intermediate computation from `results_df` columns rather than a pre-computed metric object. The `lock_duration_days` and `weight` columns on vote rows are already available in `results_df` for `PLOT-11`.

Serif font resolution falls back to DejaVu Serif on this Linux system (Times New Roman is not installed). Setting `rcParams['font.family'] = 'serif'` resolves to DejaVu Serif automatically — this is publication-acceptable. The plan should note this as expected behavior, not a bug.

**Primary recommendation:** Implement all 11 plot functions in a single `backtesting/plots.py` module with rcParams set at module import. Each function takes the relevant metric result dataclass (or `results_df` directly) and returns a `Figure`. Tests use `matplotlib.use('Agg')` and assert `isinstance(fig, Figure)` plus axes structure checks — no pixel-level assertions.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| matplotlib | 3.10.8 (installed) | All plot rendering | Required by PLOT-12; OO API is the professional pattern |
| numpy | 1.26.4 (installed) | Array math for Lorenz, cumulative sums | Already used throughout project |
| pandas | 2.2.3 (installed) | DataFrame slicing for plot data | Already used throughout project |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| matplotlib.backends.backend_agg | bundled | Headless rendering without display | Required for `fig.savefig()` in CI/pipeline context |
| scipy | 1.13.0 (installed) | Not needed for plots — skip | Don't use for any plot computation |
| seaborn | 0.13.2 (installed) | NOT used — stick to pure matplotlib OO | Seaborn wraps pyplot state, violates PLOT-12 |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| matplotlib imshow (transition matrix) | seaborn heatmap | seaborn uses pyplot state; imshow is pure OO |
| Custom Lorenz curve | scipy.stats.gini | scipy has no Lorenz curve; numpy cumsum is correct |
| twinx() for PLOT-11 | two separate subplots | twinx shares x-axis which is semantically correct for overlaid histogram+line |

**Installation:** No new packages needed — all dependencies already in pyproject.toml and venv.

## Architecture Patterns

### Recommended Project Structure

```
src/backtesting/
├── metrics.py           # Existing Phase 5 — result dataclasses as inputs to plots
└── plots.py             # NEW Phase 6 — all 11 plot functions + rcParams

tests/
└── test_plots.py        # NEW Phase 6 — 12 requirement-traced tests
```

### Pattern 1: Module-Level rcParams (PLOT-12)

**What:** Set `matplotlib.rcParams.update({...})` once at module import, before any function definitions.

**When to use:** Required — ensures all 11 functions share identical styling without per-function boilerplate.

**Example:**
```python
# src/backtesting/plots.py
import matplotlib
matplotlib.use('Agg')  # Must be BEFORE any other matplotlib import
import matplotlib.figure
import matplotlib.backends.backend_agg  # noqa: F401  (registers backend)
import numpy as np
import pandas as pd

# PLOT-12: Publication-grade rcParams — set once at module import
matplotlib.rcParams.update({
    'font.family': 'serif',           # DejaVu Serif on Linux (Times-like fallback)
    'font.size': 11,
    'axes.titlesize': 13,
    'axes.labelsize': 11,
    'xtick.labelsize': 9,
    'ytick.labelsize': 9,
    'axes.spines.top': False,
    'axes.spines.right': False,
    'axes.grid': True,
    'axes.grid.axis': 'y',            # Horizontal gridlines only
    'grid.color': '#DDDDDD',
    'grid.linewidth': 0.6,
    'legend.frameon': False,
    'figure.dpi': 150,
    'savefig.dpi': 300,
    'savefig.bbox': 'tight',
})

BLUE = '#2196F3'    # Legacy / status-quo
ORANGE = '#FF9800'  # Signals / new-regime
```

### Pattern 2: OO API Grouped Bar Chart

**What:** All bar-chart plots use `fig = Figure(...)` → `ax = fig.add_subplot(1,1,1)` → `ax.bar(x - offset, ...)` / `ax.bar(x + offset, ...)`.

**When to use:** PLOT-01, PLOT-04, PLOT-05, PLOT-06, PLOT-08.

**Example:**
```python
# Verified: works headless with Agg backend
from matplotlib.figure import Figure
import numpy as np

def plot_flip_rate_summary(flip_result) -> Figure:
    fig = Figure(figsize=(5, 4))
    ax = fig.add_subplot(1, 1, 1)
    labels = ['Flip Rate']
    x = np.arange(len(labels))
    w = 0.35
    ax.bar(x - w/2, [1 - flip_result.aggregate], width=w,
           color=BLUE, label='Legacy', zorder=3)
    ax.bar(x + w/2, [flip_result.aggregate], width=w,
           color=ORANGE, label='Signals flipped', zorder=3)
    ax.set_xticks(x)
    ax.set_xticklabels(labels)
    ax.set_ylabel('Fraction of proposals')
    ax.set_title('Flip Rate Summary')
    ax.legend()
    return fig
```

### Pattern 3: OO API Line Plot with Annotations

**What:** `ax.plot()` for time-series lines, `ax.axvline()` for lock-in marker, `ax.annotate()` for flip marker.

**When to use:** PLOT-07 (cumulative vote curve), PLOT-10 (proposal story).

**Example:**
```python
def plot_proposal_story(results_df: pd.DataFrame, proposal_id: str,
                        lockin_timing: LockinTimingResult) -> Figure:
    fig = Figure(figsize=(10, 5))
    ax = fig.add_subplot(1, 1, 1)
    pdf = results_df[
        (results_df['event_type'] == 'VOTE_CAST') &
        (results_df['proposal_id'] == proposal_id)
    ].sort_values('block_number').reset_index(drop=True)

    # Running net margin = (cumulative_for - cumulative_against) / (cumulative_for + cumulative_against)
    # Uses results_df cumulative tally columns (legacy_for, legacy_against, etc.)
    denom_l = pdf['legacy_for'] + pdf['legacy_against']
    denom_s = pdf['signals_for'] + pdf['signals_against']
    legacy_margin = np.where(denom_l == 0, np.nan, (pdf['legacy_for'] - pdf['legacy_against']) / denom_l)
    signals_margin = np.where(denom_s == 0, np.nan, (pdf['signals_for'] - pdf['signals_against']) / denom_s)

    vote_order = np.arange(len(pdf))
    ax.plot(vote_order, legacy_margin, color=BLUE, linewidth=2, label='Legacy margin')
    ax.plot(vote_order, signals_margin, color=ORANGE, linewidth=2, label='Signals margin')
    ax.axhline(y=0, color='black', linewidth=0.5, alpha=0.4)

    # Lock-in annotation
    lockin_frac = lockin_timing.legacy.get(proposal_id)
    if lockin_frac is not None and not np.isnan(lockin_frac):
        lockin_idx = int(lockin_frac * len(pdf))
        ax.axvline(x=lockin_idx, linestyle='--', color='gray', linewidth=1, label='Lock-in (legacy)')

    ax.set_xlabel('Vote order')
    ax.set_ylabel('Net margin (FOR−AGAINST)/(FOR+AGAINST)')
    ax.set_title(f'Proposal story: {proposal_id}')
    ax.legend()
    return fig
```

### Pattern 4: Lorenz Curve with fill_between

**What:** Sort weights, compute cumulative share, `ax.fill_between()` for Gini area, equality line at y=x.

**When to use:** PLOT-09 only.

**Example:**
```python
def plot_lorenz_curve(results_df: pd.DataFrame) -> Figure:
    from backtesting.weighting.signals import compute_signals_weight as _cw
    vote_df = results_df[results_df['event_type'] == 'VOTE_CAST'].copy()
    vote_df['signals_w'] = np.vectorize(_cw)(
        vote_df['weight'].values,
        vote_df['lock_duration_days'].fillna(0).values,
    )

    fig = Figure(figsize=(6, 6))
    ax = fig.add_subplot(1, 1, 1)
    p = np.linspace(0, 1, 200)

    for weights, color, label in [
        (vote_df['weight'].values, BLUE, 'Legacy'),
        (vote_df['signals_w'].values, ORANGE, 'Signals'),
    ]:
        sorted_w = np.sort(weights)
        lorenz = np.concatenate([[0], np.cumsum(sorted_w) / sorted_w.sum()])
        p_full = np.linspace(0, 1, len(lorenz))
        ax.plot(p_full, lorenz, color=color, linewidth=2, label=label)
        ax.fill_between(p_full, lorenz, p_full, alpha=0.15, color=color)

    ax.plot([0, 1], [0, 1], 'k--', linewidth=1, label='Perfect equality')
    ax.set_xlabel('Cumulative share of voters')
    ax.set_ylabel('Cumulative share of voting power')
    ax.set_title('Lorenz Curve: Voting Power Distribution')
    ax.legend()
    return fig
```

### Pattern 5: Transition Matrix Heatmap

**What:** `ax.imshow()` with `cmap='Blues'`, then `ax.text()` for cell annotations. No seaborn.

**When to use:** PLOT-03 only.

**Example:**
```python
def plot_transition_matrix(transition: TransitionMatrix) -> Figure:
    data = np.array(transition.counts)  # shape (2,2)
    fig = Figure(figsize=(5, 4))
    ax = fig.add_subplot(1, 1, 1)
    im = ax.imshow(data, cmap='Blues', aspect='auto')
    for i in range(2):
        for j in range(2):
            count = data[i, j]
            pct = transition.proportions[i][j] * 100
            ax.text(j, i, f'{count}\n({pct:.0f}%)',
                    ha='center', va='center', fontsize=12,
                    color='white' if data[i, j] > data.max() * 0.6 else 'black')
    ax.set_xticks([0, 1])
    ax.set_yticks([0, 1])
    ax.set_xticklabels(['Signals Pass', 'Signals Fail'])
    ax.set_yticklabels(['Legacy Pass', 'Legacy Fail'])
    ax.set_title('Outcome Transition Matrix')
    fig.colorbar(im, ax=ax, label='Proposal count')
    return fig
```

### Pattern 6: Twin-Axis for PLOT-11

**What:** `ax1.hist()` for lock duration distribution, `ax2 = ax1.twinx()` for Signals weight curve overlaid.

**When to use:** PLOT-11 only.

**Example:**
```python
def plot_lock_duration_histogram(results_df: pd.DataFrame) -> Figure:
    from backtesting.weighting.signals import compute_signals_weight as _cw
    vote_df = results_df[results_df['event_type'] == 'VOTE_CAST'].copy()
    vote_df['signals_w'] = np.vectorize(_cw)(
        vote_df['weight'].values,
        vote_df['lock_duration_days'].fillna(0).values,
    )
    ld = vote_df['lock_duration_days'].values
    sw = vote_df['signals_w'].values

    fig = Figure(figsize=(8, 5))
    ax1 = fig.add_subplot(1, 1, 1)
    ax2 = ax1.twinx()

    counts, bins, _ = ax1.hist(ld, bins=20, color=BLUE, alpha=0.6, label='Vote count')
    bin_centers = 0.5 * (bins[:-1] + bins[1:])
    bin_means = [
        sw[(ld >= bins[i]) & (ld < bins[i+1])].mean()
        if any((ld >= bins[i]) & (ld < bins[i+1])) else 0.0
        for i in range(len(bins) - 1)
    ]
    ax2.plot(bin_centers, bin_means, color=ORANGE, linewidth=2, marker='o',
             markersize=4, label='Avg Signals weight')

    ax1.set_xlabel('Lock duration (days)')
    ax1.set_ylabel('Vote count', color=BLUE)
    ax2.set_ylabel('Avg Signals weight', color=ORANGE)
    ax1.set_title('Lock Duration Distribution with Signals Weight Overlay')
    return fig
```

### Anti-Patterns to Avoid

- **Using `plt.*` anywhere:** Any `plt.figure()`, `plt.show()`, `plt.subplots()`, `plt.savefig()` call violates PLOT-12. Always use `Figure()` directly.
- **Importing pyplot at module level:** `import matplotlib.pyplot as plt` creates global state even if plt.* is never called. Omit it entirely.
- **Seaborn heatmaps:** `sns.heatmap()` calls pyplot internally. Use `ax.imshow()` instead.
- **Setting rcParams inside each function:** Wastes execution time and creates inconsistency risk. Set once at module import only.
- **`fig.savefig()` inside plot functions:** The caller handles saving. Return the Figure, nothing more.
- **`matplotlib.use('Agg')` after any Figure import:** Backend must be set before matplotlib.figure is imported. Place it at the very top of plots.py.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Gini area shading | Custom polygon patch | `ax.fill_between(p, lorenz, p, ...)` | fill_between handles edge cases cleanly |
| Running net margin | Custom loop | `results_df` cumulative tally columns (`legacy_for`, `legacy_against`) already track running totals | Data is already computed by simulation — use it |
| Lorenz curve values | Custom Gini derivation | `np.cumsum(np.sort(weights)) / weights.sum()` | Standard O(n log n) implementation |
| Color validation | Custom colorblind check | Blue `#2196F3` + Orange `#FF9800` are locked decisions — use constants | Already validated in CONTEXT.md |
| Backend detection | Environment checks | `matplotlib.use('Agg')` unconditionally in plots.py | Agg is always correct for file output |

**Key insight:** The data pipeline (Phase 3–5) already computes everything needed. Plot functions are thin wrappers that translate frozen dataclasses and DataFrames into Figure objects. Resist any temptation to re-derive metrics inside plot functions.

## Common Pitfalls

### Pitfall 1: `matplotlib.use()` Called Too Late

**What goes wrong:** `UserWarning: Cannot load backend 'Agg' after first Figure creation` — figure renders to wrong backend or raises.
**Why it happens:** Any `Figure()` call or `import matplotlib.figure` before `matplotlib.use('Agg')` locks the backend.
**How to avoid:** First two lines of `plots.py` must be `import matplotlib` then `matplotlib.use('Agg')`. All other matplotlib imports follow.
**Warning signs:** Any import ordering that puts `from matplotlib.figure import Figure` before `matplotlib.use('Agg')`.

### Pitfall 2: pyplot State Leaking Through Dependencies

**What goes wrong:** A dependency (e.g., seaborn, old matplotlib style helpers) calls `plt.figure()` internally, creating global state.
**Why it happens:** `seaborn.set_theme()` calls pyplot. `matplotlib.pyplot` auto-creates a global figure manager.
**How to avoid:** Do not import seaborn in `plots.py`. Verify no transitive imports call `plt.*`.
**Warning signs:** `import seaborn` anywhere in plots.py or its imports.

### Pitfall 3: NaN Values in Plot Data

**What goes wrong:** `ax.bar()` or `ax.plot()` silently drops NaN values, producing gaps or misaligned bars.
**Why it happens:** `LockinTimingResult` and `LateVoteShareResult` legitimately return `float('nan')` when lock-in never occurred or no votes exist.
**How to avoid:** Filter or replace NaN before plotting. Use `np.nanmean()` for aggregations in plot functions. For per-proposal bars, consider showing NaN as zero with a visual indicator (lighter bar, asterisk annotation).
**Warning signs:** Per-proposal bar counts not matching expected proposal count.

### Pitfall 4: Cumulative Tally Columns vs Raw Weights

**What goes wrong:** PLOT-07 (cumulative FOR votes) and PLOT-10 (net margin over time) look flat or wrong.
**Why it happens:** The `results_df` carries cumulative tallies at each row (not incremental per-vote weights). For PLOT-07 the y-value is directly `legacy_for` (already cumulative). For PLOT-10 the running net margin is `(legacy_for - legacy_against) / (legacy_for + legacy_against)` per row.
**How to avoid:** Do NOT `np.cumsum()` on `legacy_for` — it's already cumulative. Just plot the column values in `block_number` order.
**Warning signs:** Cumulative curves that accelerate exponentially instead of leveling off.

### Pitfall 5: rcParams Not Applied to Saved Figure

**What goes wrong:** PDF/PNG looks different from in-memory figure — different font, missing grid, wrong DPI.
**Why it happens:** `savefig.dpi` in rcParams is honored by `fig.savefig()` but only if no explicit `dpi=` kwarg overrides it.
**How to avoid:** Set `savefig.dpi: 300` and `savefig.bbox: tight` in module-level rcParams. Caller uses `fig.savefig(path)` with no kwargs, inheriting rcParams.
**Warning signs:** PNG files smaller than ~100KB at 300 DPI for a typical 8x5 figure.

### Pitfall 6: Font Warning on Save

**What goes wrong:** `findfont: Font family 'Times New Roman' not found. Falling back to DejaVu Serif.` — warning in logs but figure renders correctly.
**Why it happens:** Times New Roman is not installed on the Linux system. `font.family: serif` resolves to DejaVu Serif automatically.
**How to avoid:** Accept DejaVu Serif as the serif font. Do not install system fonts in the venv. Suppress the warning if noisy, or document it as expected.
**Warning signs:** Repeated findfont warnings in test output.

## Code Examples

### Module Header (plots.py)

```python
# src/backtesting/plots.py
"""
Publication-grade matplotlib figures for backtesting metrics.

All functions use the OO API exclusively (no pyplot state).
rcParams are set once at module import for consistent styling.
Each function returns a matplotlib.figure.Figure — caller saves to disk.
"""
import matplotlib
matplotlib.use('Agg')                          # Must be first matplotlib call

import matplotlib.figure                       # noqa: E402
import matplotlib.backends.backend_agg        # noqa: E402  (registers Agg)
import numpy as np                             # noqa: E402
import pandas as pd                            # noqa: E402

from backtesting.metrics import (              # noqa: E402
    FlipRateResult,
    GiniResult,
    ENPResult,
    MarginShiftResult,
    TransitionMatrix,
    LateVoteShareResult,
    LockinTimingResult,
    TopKConcentrationResult,
)
from backtesting.weighting.signals import compute_signals_weight as _cw  # noqa: E402

# ---------------------------------------------------------------------------
# PLOT-12: Publication rcParams — set once at module import
# ---------------------------------------------------------------------------
matplotlib.rcParams.update({
    'font.family': 'serif',
    'font.size': 11,
    'axes.titlesize': 13,
    'axes.titleweight': 'bold',
    'axes.labelsize': 11,
    'xtick.labelsize': 9,
    'ytick.labelsize': 9,
    'axes.spines.top': False,
    'axes.spines.right': False,
    'axes.grid': True,
    'axes.grid.axis': 'y',
    'grid.color': '#DDDDDD',
    'grid.linewidth': 0.6,
    'legend.frameon': False,
    'legend.fontsize': 9,
    'figure.facecolor': 'white',
    'axes.facecolor': 'white',
    'savefig.dpi': 300,
    'savefig.bbox': 'tight',
    'savefig.format': 'pdf',
})

# Color constants — locked in CONTEXT.md
BLUE = '#2196F3'    # Legacy / status-quo regime
ORANGE = '#FF9800'  # Signals / new-regime
```

### Test Pattern (test_plots.py)

```python
# tests/test_plots.py
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

import matplotlib
matplotlib.use('Agg')
from matplotlib.figure import Figure
import pytest
from backtesting.plots import (
    plot_flip_rate_summary,
    plot_lorenz_curve,
    # ... all 11 functions
)

def test_plot_01_flip_rate_returns_figure(metrics_results_df):
    """PLOT-01: Flip rate plot returns a Figure with one axes."""
    from backtesting.metrics import compute_flip_rate
    result = compute_flip_rate(metrics_results_df)
    fig = plot_flip_rate_summary(result)
    assert isinstance(fig, Figure)
    assert len(fig.get_axes()) >= 1

def test_plot_12_no_pyplot_state():
    """PLOT-12: plots module does not import pyplot."""
    import importlib, sys
    # Reload to test fresh import
    if 'backtesting.plots' in sys.modules:
        del sys.modules['backtesting.plots']
    import backtesting.plots
    assert 'matplotlib.pyplot' not in sys.modules, \
        "plots.py must not import pyplot — violates PLOT-12 OO API requirement"
```

### Cumulative Vote Curve Data Extraction (for PLOT-07)

```python
# Source: verified against results_df column structure (Phase 4 output)
def _get_proposal_vote_sequence(results_df: pd.DataFrame, proposal_id: str) -> pd.DataFrame:
    """Return vote rows for one proposal sorted by block_number.

    The legacy_for / signals_for columns are already cumulative tallies —
    do NOT apply np.cumsum(). Plot directly as y-values against vote_order index.
    """
    mask = (
        (results_df['event_type'] == 'VOTE_CAST') &
        (results_df['proposal_id'] == proposal_id)
    )
    return results_df[mask].sort_values('block_number').reset_index(drop=True)

# In plot_cumulative_vote_curve:
# x = np.arange(len(pdf))            # vote order 0, 1, 2, ...
# y_legacy = pdf['legacy_for']       # already cumulative — plot directly
# y_signals = pdf['signals_for']     # already cumulative — plot directly
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `plt.figure()` + `plt.subplot()` | `Figure()` + `fig.add_subplot()` | Always possible; now explicit | No global state, thread-safe, testable |
| `plt.savefig()` | `fig.savefig()` | Always possible | Figure-scoped, no pyplot dependency |
| seaborn for heatmaps | `ax.imshow()` + `ax.text()` | matplotlib 2.x+ | OO API compliant, no seaborn dependency |
| `plt.rcParams` | `matplotlib.rcParams.update()` | Always the same | Both valid; explicit module reference is clearer |
| `plt.tight_layout()` | `savefig.bbox: 'tight'` in rcParams | matplotlib 3.x | Automatic at save time, no pyplot call |

**Deprecated/outdated:**
- `plt.subplots()`: Creates pyplot-managed figure — do not use in plots.py
- `seaborn.heatmap()`: Wraps pyplot internally — do not use
- `plt.show()`: Interactive display — never call in pipeline code

## Open Questions

1. **Figure sizing for multi-proposal bar charts**
   - What we know: With 5 proposals, standard (8, 5) works. With 30 proposals, bars become too narrow.
   - What's unclear: Whether to use `figsize=(max(8, n_proposals * 0.5), 5)` dynamic sizing or fixed wide format.
   - Recommendation: Implement dynamic width `figsize=(max(8, n_proposals * 0.4 + 2), 5)` — natural extension of single-panel pattern.

2. **Per-proposal vs aggregate for PLOT-05 (top-k) and PLOT-06 (ENP)**
   - What we know: Both metrics return per-proposal dicts. With 30 proposals, per-proposal bars are dense.
   - What's unclear: Whether to show mean ± std across proposals (single grouped bar) or per-proposal bars.
   - Recommendation: Default to mean ± std (single grouped bar per k-value for PLOT-05, single pair for PLOT-06) — more readable and publication-appropriate for aggregated reporting.

3. **Outcome flip marker in PLOT-10**
   - What we know: A flip occurs when `legacy_margin` and `signals_margin` have different signs at final vote.
   - What's unclear: The exact vote index where they cross zero on opposite sides — needs scanning the running margins.
   - Recommendation: Detect first index where `sign(legacy_margin) != sign(signals_margin)` and mark with vertical dotted line in a third color (red).

## Validation Architecture

> nyquist_validation not set to true in config.json — skipping this section.

## Sources

### Primary (HIGH confidence)

- matplotlib 3.10.8 installed at `/home/biscii/src/signals/apps/simulations/.venv/lib/python3.12/site-packages/matplotlib/` — verified OO API (`Figure`, `add_subplot`, `axvline`, `twinx`, `fill_between`, `imshow`, `savefig`) all work headless with Agg backend
- `backtesting/metrics.py` — Phase 5 implementation inspected; all dataclass fields and types confirmed as plot function inputs
- `tests/conftest.py` — existing fixtures (`metrics_results_df`, `metrics_windows_df`, `sample_events`) reusable as-is for plot tests
- `pyproject.toml` — matplotlib>=3.9.2, numpy>=1.26.4, pandas>=2.2.3 confirmed as existing dependencies

### Secondary (MEDIUM confidence)

- `src/figs/charts.py` — existing project plotting code confirms pattern of rcParams at module level and OO-style axis calls; note it uses pyplot which is not permitted in Phase 6
- Font check via `font_manager.fontManager.ttflist` — DejaVu Serif confirmed as available serif fallback on this system

### Tertiary (LOW confidence)

- None — all claims verified against installed environment.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries installed and verified against real code
- Architecture: HIGH — OO API patterns tested in venv, data shapes confirmed from live metric computation
- Pitfalls: HIGH — each pitfall tested or directly derived from verifiable behavior (NaN in data, cumulative tally columns, font fallback)

**Research date:** 2026-02-27
**Valid until:** 2026-09-01 (matplotlib stable; rcParams API unchanged across minor versions)
