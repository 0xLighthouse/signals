"""
Publication-grade matplotlib figures for backtesting metrics.

All functions use the OO API exclusively (no pyplot state).
rcParams are set once at module import for consistent styling.
Each function returns a matplotlib.figure.Figure — caller saves to disk.
"""
import matplotlib
matplotlib.use('Agg')  # Must be FIRST matplotlib call — before any Figure import

import matplotlib.figure               # noqa: E402
import matplotlib.backends.backend_agg  # noqa: E402  (registers Agg backend)
import numpy as np                      # noqa: E402
import pandas as pd                     # noqa: E402

from backtesting.metrics import (       # noqa: E402
    FlipRateResult,
    GiniResult,
    ENPResult,
    MarginShiftResult,
    TransitionMatrix,
    LateVoteShareResult,
    LockinTimingResult,
    TopKConcentrationResult,
)

# PLOT-12: Publication-grade rcParams — set once at module import
matplotlib.rcParams.update({
    'font.family': 'serif',        # DejaVu Serif on Linux (Times-like fallback — expected)
    'font.size': 11,
    'axes.titlesize': 13,
    'axes.titleweight': 'bold',
    'axes.labelsize': 11,
    'xtick.labelsize': 9,
    'ytick.labelsize': 9,
    'axes.spines.top': False,
    'axes.spines.right': False,
    'axes.grid': True,
    'axes.grid.axis': 'y',         # Horizontal gridlines only
    'grid.color': '#DDDDDD',
    'grid.linewidth': 0.6,
    'legend.frameon': False,
    'legend.fontsize': 9,
    'figure.facecolor': 'white',
    'axes.facecolor': 'white',
    'savefig.dpi': 300,
    'savefig.bbox': 'tight',
})

# Color constants — locked in CONTEXT.md
BLUE = '#2196F3'    # Legacy / status-quo regime
ORANGE = '#FF9800'  # Signals / new-regime

# ---------------------------------------------------------------------------
# Convenience alias for return type
# ---------------------------------------------------------------------------
from matplotlib.figure import Figure  # noqa: E402


# ---------------------------------------------------------------------------
# PLOT-01: Flip Rate Summary
# ---------------------------------------------------------------------------

def plot_flip_rate_summary(flip_result: FlipRateResult) -> Figure:
    """PLOT-01: Grouped bar chart showing legacy-unchanged vs Signals-flipped fraction."""
    fig = Figure(figsize=(5, 4))
    ax = fig.add_subplot(1, 1, 1)

    labels = ['Voting regime comparison']
    x = np.arange(len(labels))
    w = 0.35

    ax.bar(x - w / 2, [1 - flip_result.aggregate], width=w,
           color=BLUE, label='Legacy unchanged', zorder=3)
    ax.bar(x + w / 2, [flip_result.aggregate], width=w,
           color=ORANGE, label='Signals flipped', zorder=3)

    ax.set_xticks(x)
    ax.set_xticklabels(labels)
    ax.set_xlabel('Voting regime comparison')
    ax.set_ylabel('Fraction of proposals')
    ax.set_title('Flip Rate Summary')
    ax.set_ylim(bottom=0)
    ax.legend()

    return fig


# ---------------------------------------------------------------------------
# PLOT-02: Margin Shift Histogram (per-proposal horizontal bars)
# ---------------------------------------------------------------------------

def plot_margin_shift_histogram(shift_result: MarginShiftResult) -> Figure:
    """PLOT-02: Per-proposal horizontal bar chart of Signals margin minus Legacy margin."""
    per_proposal = {
        pid: v for pid, v in shift_result.per_proposal.items()
        if not (isinstance(v, float) and np.isnan(v))
    }

    if not per_proposal:
        fig = Figure(figsize=(8, 4))
        ax = fig.add_subplot(1, 1, 1)
        ax.set_title('Margin Shift per Proposal')
        ax.set_xlabel('Signals margin − Legacy margin')
        ax.set_ylabel('Proposal')
        return fig

    sorted_items = sorted(per_proposal.items(), key=lambda kv: kv[1], reverse=True)
    proposals = [item[0] for item in sorted_items]
    shifts = [item[1] for item in sorted_items]
    colors = [ORANGE if s >= 0 else BLUE for s in shifts]

    height = max(4, len(proposals) * 0.4 + 1)
    fig = Figure(figsize=(8, height))
    ax = fig.add_subplot(1, 1, 1)

    ax.barh(proposals, shifts, color=colors, zorder=3)
    ax.axvline(x=0, color='black', linewidth=0.8, zorder=4)

    ax.set_xlabel('Signals margin − Legacy margin')
    ax.set_ylabel('Proposal')
    ax.set_title('Margin Shift per Proposal')

    return fig


# ---------------------------------------------------------------------------
# PLOT-03: Outcome Transition Matrix
# ---------------------------------------------------------------------------

def plot_transition_matrix(transition: TransitionMatrix) -> Figure:
    """PLOT-03: 2x2 heatmap of outcome transitions between Legacy and Signals regimes."""
    data = np.array(transition.counts, dtype=float)

    fig = Figure(figsize=(5, 4))
    ax = fig.add_subplot(1, 1, 1)

    im = ax.imshow(data, cmap='Blues', aspect='auto')

    max_val = data.max() if data.max() > 0 else 1.0
    for i in range(2):
        for j in range(2):
            count = int(data[i, j])
            pct = transition.proportions[i][j] * 100
            text_color = 'white' if data[i, j] > max_val * 0.6 else 'black'
            ax.text(j, i, f'{count}\n({pct:.0f}%)',
                    ha='center', va='center', fontsize=12,
                    color=text_color)

    ax.set_xticks([0, 1])
    ax.set_yticks([0, 1])
    ax.set_xticklabels(['Signals Pass', 'Signals Fail'])
    ax.set_yticklabels(['Legacy Pass', 'Legacy Fail'])
    ax.set_title('Outcome Transition Matrix')

    fig.colorbar(im, ax=ax, label='Proposal count')

    return fig


# ---------------------------------------------------------------------------
# PLOT-04: Gini Coefficient Comparison
# ---------------------------------------------------------------------------

def plot_gini_comparison(gini_result: GiniResult) -> Figure:
    """PLOT-04: Grouped bars comparing Legacy and Signals Gini coefficients."""
    fig = Figure(figsize=(5, 4))
    ax = fig.add_subplot(1, 1, 1)

    labels = ['Voting Power']
    x = np.arange(len(labels))
    w = 0.35

    ax.bar(x - w / 2, [gini_result.legacy], width=w,
           color=BLUE, label='Legacy', zorder=3)
    ax.bar(x + w / 2, [gini_result.signals], width=w,
           color=ORANGE, label='Signals', zorder=3)

    ax.set_xticks(x)
    ax.set_xticklabels(labels)
    ax.set_ylabel('Gini coefficient')
    ax.set_title('Gini Coefficient: Legacy vs Signals')
    ax.set_ylim(0, 1)
    ax.legend()

    return fig


# ---------------------------------------------------------------------------
# PLOT-05: Top-k Concentration Comparison
# ---------------------------------------------------------------------------

def plot_top_k_comparison(topk_result: TopKConcentrationResult) -> Figure:
    """PLOT-05: Grouped bars for k=1,5,10 showing mean top-k share across proposals."""
    ks = [1, 5, 10]
    k_labels = ['Top-1', 'Top-5', 'Top-10']

    legacy_means = [
        np.nanmean(list(topk_result.legacy[k].values())) if k in topk_result.legacy else 0.0
        for k in ks
    ]
    signals_means = [
        np.nanmean(list(topk_result.signals[k].values())) if k in topk_result.signals else 0.0
        for k in ks
    ]

    x = np.arange(len(ks))
    w = 0.35

    fig = Figure(figsize=(7, 4))
    ax = fig.add_subplot(1, 1, 1)

    ax.bar(x - w / 2, legacy_means, width=w, color=BLUE, label='Legacy', zorder=3)
    ax.bar(x + w / 2, signals_means, width=w, color=ORANGE, label='Signals', zorder=3)

    ax.set_xticks(x)
    ax.set_xticklabels(k_labels)
    ax.set_ylabel('Mean share of voting power')
    ax.set_title('Top-k Concentration: Legacy vs Signals')
    ax.set_ylim(bottom=0)
    ax.legend()

    return fig


# ---------------------------------------------------------------------------
# PLOT-06: ENP Comparison
# ---------------------------------------------------------------------------

def plot_enp_comparison(enp_result: ENPResult) -> Figure:
    """PLOT-06: Single grouped bar pair showing mean Legacy ENP vs mean Signals ENP."""
    legacy_mean = np.nanmean(list(enp_result.legacy.values())) if enp_result.legacy else 0.0
    signals_mean = np.nanmean(list(enp_result.signals.values())) if enp_result.signals else 0.0

    labels = ['Effective Number of Participants']
    x = np.arange(len(labels))
    w = 0.35

    fig = Figure(figsize=(5, 4))
    ax = fig.add_subplot(1, 1, 1)

    ax.bar(x - w / 2, [legacy_mean], width=w, color=BLUE, label='Legacy', zorder=3)
    ax.bar(x + w / 2, [signals_mean], width=w, color=ORANGE, label='Signals', zorder=3)

    ax.set_xticks(x)
    ax.set_xticklabels(labels)
    ax.set_xlabel('Effective Number of Participants')
    ax.set_ylabel('ENP (mean across proposals)')
    ax.set_title('ENP Comparison: Legacy vs Signals')
    ax.set_ylim(bottom=0)
    ax.legend()

    return fig


# ---------------------------------------------------------------------------
# PLOT-07: Cumulative Vote Curve
# ---------------------------------------------------------------------------

def plot_cumulative_vote_curve(results_df: pd.DataFrame, proposal_id: str) -> Figure:
    """PLOT-07: Cumulative FOR votes over vote order for one proposal."""
    mask = (
        (results_df['event_type'] == 'VOTE_CAST') &
        (results_df['proposal_id'] == proposal_id)
    )
    pdf = results_df[mask].sort_values('block_number').reset_index(drop=True)

    fig = Figure(figsize=(8, 4))
    ax = fig.add_subplot(1, 1, 1)

    if not pdf.empty:
        vote_order = np.arange(len(pdf))
        # legacy_for and signals_for are already cumulative — do NOT apply np.cumsum
        ax.plot(vote_order, pdf['legacy_for'].values,
                color=BLUE, linewidth=2, label='Legacy')
        ax.plot(vote_order, pdf['signals_for'].values,
                color=ORANGE, linewidth=2, label='Signals')

    ax.set_xlabel('Vote order')
    ax.set_ylabel('Cumulative FOR votes')
    ax.set_title(f'Cumulative Vote Curve: {proposal_id}')
    ax.legend()

    return fig


# ---------------------------------------------------------------------------
# PLOT-08: Late-Vote Share Comparison
# ---------------------------------------------------------------------------

def plot_late_vote_share(late_result: LateVoteShareResult) -> Figure:
    """PLOT-08: Per-proposal grouped bars of late-vote share for Legacy and Signals."""
    proposals = sorted(set(late_result.legacy.keys()) | set(late_result.signals.keys()))

    legacy_vals = [np.nan_to_num(late_result.legacy.get(p, 0.0)) for p in proposals]
    signals_vals = [np.nan_to_num(late_result.signals.get(p, 0.0)) for p in proposals]

    width = max(8, len(proposals) * 0.5 + 2)
    fig = Figure(figsize=(width, 4))
    ax = fig.add_subplot(1, 1, 1)

    x = np.arange(len(proposals))
    w = 0.35

    ax.bar(x - w / 2, legacy_vals, width=w, color=BLUE, label='Legacy', zorder=3)
    ax.bar(x + w / 2, signals_vals, width=w, color=ORANGE, label='Signals', zorder=3)

    ax.set_xticks(x)
    ax.set_xticklabels(proposals, rotation=45, ha='right')
    ax.set_xlabel('Proposal')
    ax.set_ylabel('Late-vote share (final third)')
    ax.set_title('Late-Vote Share: Legacy vs Signals')
    ax.set_ylim(0, 1)
    ax.legend()

    return fig


# ---------------------------------------------------------------------------
# PLOT-09: Lorenz Curve
# ---------------------------------------------------------------------------

def plot_lorenz_curve(results_df: pd.DataFrame) -> Figure:
    """PLOT-09: Lorenz curves for Legacy and Signals voting power distributions."""
    from backtesting.weighting.signals import compute_signals_weight as _cw  # noqa: E402

    vote_df = results_df[results_df['event_type'] == 'VOTE_CAST'].copy()

    if vote_df.empty:
        fig = Figure(figsize=(6, 6))
        ax = fig.add_subplot(1, 1, 1)
        ax.plot([0, 1], [0, 1], 'k--', linewidth=1, label='Perfect equality')
        ax.set_xlabel('Cumulative share of voters')
        ax.set_ylabel('Cumulative share of voting power')
        ax.set_title('Lorenz Curve: Voting Power Distribution')
        ax.legend()
        return fig

    vote_df['signals_w'] = np.vectorize(_cw)(
        vote_df['weight'].values,
        vote_df['lock_duration_days'].fillna(0).values,
    )

    fig = Figure(figsize=(6, 6))
    ax = fig.add_subplot(1, 1, 1)

    for weights, color, label in [
        (vote_df['weight'].values, BLUE, 'Legacy'),
        (vote_df['signals_w'].values, ORANGE, 'Signals'),
    ]:
        weights = np.asarray(weights, dtype=float)
        weights = weights[~np.isnan(weights)]
        if len(weights) == 0 or weights.sum() == 0:
            continue
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


# ---------------------------------------------------------------------------
# PLOT-10: Proposal Story
# ---------------------------------------------------------------------------

def plot_proposal_story(
    results_df: pd.DataFrame,
    proposal_id: str,
    lockin_timing: LockinTimingResult,
) -> Figure:
    """PLOT-10: Running net margin over vote order for one proposal."""
    mask = (
        (results_df['event_type'] == 'VOTE_CAST') &
        (results_df['proposal_id'] == proposal_id)
    )
    pdf = results_df[mask].sort_values('block_number').reset_index(drop=True)

    fig = Figure(figsize=(10, 5))
    ax = fig.add_subplot(1, 1, 1)

    if not pdf.empty:
        denom_l = pdf['legacy_for'] + pdf['legacy_against']
        denom_s = pdf['signals_for'] + pdf['signals_against']

        legacy_margin = np.where(
            denom_l == 0, np.nan,
            (pdf['legacy_for'] - pdf['legacy_against']) / denom_l
        )
        signals_margin = np.where(
            denom_s == 0, np.nan,
            (pdf['signals_for'] - pdf['signals_against']) / denom_s
        )

        vote_order = np.arange(len(pdf))
        ax.plot(vote_order, legacy_margin, color=BLUE, linewidth=2, label='Legacy margin')
        ax.plot(vote_order, signals_margin, color=ORANGE, linewidth=2, label='Signals margin')
        ax.axhline(y=0, color='black', lw=0.5, alpha=0.4)

        # Lock-in annotation
        lockin_frac = lockin_timing.legacy.get(proposal_id)
        if lockin_frac is not None and not np.isnan(float(lockin_frac)):
            lockin_idx = int(float(lockin_frac) * len(pdf))
            ax.axvline(x=lockin_idx, ls='--', color='gray', lw=1, label='Lock-in (legacy)')

        # Flip detection: first index where sign differs (both non-NaN)
        valid_mask = ~np.isnan(legacy_margin) & ~np.isnan(signals_margin)
        if valid_mask.any():
            l_sign = np.sign(legacy_margin[valid_mask])
            s_sign = np.sign(signals_margin[valid_mask])
            valid_indices = np.where(valid_mask)[0]
            flip_positions = valid_indices[l_sign != s_sign]
            if len(flip_positions) > 0:
                ax.axvline(x=flip_positions[0], ls=':', color='red', lw=1.5,
                           label='Outcome divergence')

    ax.set_xlabel('Vote order')
    ax.set_ylabel('Net margin (FOR−AGAINST)/(FOR+AGAINST)')
    ax.set_title(f'Proposal Story: {proposal_id}')
    ax.legend()

    return fig


# ---------------------------------------------------------------------------
# PLOT-11: Lock Duration Histogram with Signals Weight Overlay
# ---------------------------------------------------------------------------

def plot_lock_duration_histogram(results_df: pd.DataFrame) -> Figure:
    """PLOT-11: Lock duration histogram (blue) with Signals weight curve overlay (orange)."""
    from backtesting.weighting.signals import compute_signals_weight as _cw  # noqa: E402

    vote_df = results_df[results_df['event_type'] == 'VOTE_CAST'].copy()
    vote_df['signals_w'] = np.vectorize(_cw)(
        vote_df['weight'].values,
        vote_df['lock_duration_days'].fillna(0).values,
    )

    ld = vote_df['lock_duration_days'].fillna(0).values
    sw = vote_df['signals_w'].values

    fig = Figure(figsize=(8, 5))
    ax1 = fig.add_subplot(1, 1, 1)
    ax2 = ax1.twinx()

    if len(ld) > 0:
        counts, bins, _ = ax1.hist(ld, bins=20, color=BLUE, alpha=0.6,
                                   label='Vote count', zorder=2)
        bin_centers = 0.5 * (bins[:-1] + bins[1:])
        bin_means = []
        for i in range(len(bins) - 1):
            mask = (ld >= bins[i]) & (ld < bins[i + 1])
            if i == len(bins) - 2:
                # Include right edge on last bin
                mask = (ld >= bins[i]) & (ld <= bins[i + 1])
            bin_means.append(float(sw[mask].mean()) if mask.any() else 0.0)

        ax2.plot(bin_centers, bin_means, color=ORANGE, linewidth=2,
                 marker='o', markersize=4, label='Avg Signals weight')

    ax1.set_xlabel('Lock duration (days)')
    ax1.set_ylabel('Vote count', color=BLUE)
    ax2.set_ylabel('Avg Signals weight', color=ORANGE)
    ax1.set_title('Lock Duration Distribution with Signals Weight Overlay')

    lines1, labels1 = ax1.get_legend_handles_labels()
    lines2, labels2 = ax2.get_legend_handles_labels()
    ax1.legend(lines1 + lines2, labels1 + labels2)

    return fig
