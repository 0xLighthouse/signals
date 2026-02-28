"""
Simulation A — Whale-dominated DAO: Does commitment-weighting reduce plutocracy?

Generates a 200-voter, 30-proposal scenario with Pareto stake distribution
(80/20 power law) and independent lock durations, then compares Legacy
(stake-only) vs Signals (commitment-weighted) governance across key fairness
metrics.

Usage:
    cd apps/simulations
    uv run python experiments/sim_a/sim_a.py
"""
import warnings
import os

import matplotlib
matplotlib.use('Agg')

import matplotlib.figure
import matplotlib.backends.backend_agg
import numpy as np

from backtesting.data import generate_scenario
from backtesting.simulation import run_backtest, build_results_dataframe
from backtesting.data.loader import events_to_dataframe
from backtesting.metrics import (
    compute_flip_rate,
    compute_gini,
    compute_enp,
    compute_nakamoto_coefficient,
    compute_top_k_concentration,
    compute_margin_shift,
    compute_transition_matrix,
)
from backtesting.plots import (
    BLUE, ORANGE,
    plot_gini_comparison,
    plot_lorenz_curve,
    plot_top_k_comparison,
    plot_transition_matrix,
    plot_margin_shift_histogram,
    plot_flip_rate_summary,
)

# ── Configuration ────────────────────────────────────────────────────────────

SCENARIO = dict(
    n_voters=200,
    n_proposals=30,
    total_supply=1_000_000.0,
    avg_participation_rate=0.10,
    stake_profile='pareto',
    lock_profile='bimodal',
    seed=42,
    budget_enabled=True,
)

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), '..', '..', 'output')
OUTPUT_FILE = os.path.join(OUTPUT_DIR, 'sim_a.png')

# ── Run simulation ───────────────────────────────────────────────────────────


def main():
    print('Generating scenario...', flush=True)
    with warnings.catch_warnings():
        warnings.simplefilter('ignore')
        events = generate_scenario(**SCENARIO)

    print(f'  {len(events)} events generated')
    print('Running backtest...', flush=True)
    with warnings.catch_warnings():
        warnings.simplefilter('ignore')
        raw = run_backtest(events)
    results_df = build_results_dataframe(raw, events)
    print(f'  {len(results_df)} result rows')

    # ── Compute metrics ──────────────────────────────────────────────────────

    flip = compute_flip_rate(results_df)
    gini = compute_gini(results_df)
    enp = compute_enp(results_df)
    nakamoto = compute_nakamoto_coefficient(results_df)
    topk = compute_top_k_concentration(results_df)
    margin = compute_margin_shift(results_df)
    transition = compute_transition_matrix(results_df)

    # ── Print summary ────────────────────────────────────────────────────────

    print('\n' + '=' * 60)
    print('  SIM A — Whale-dominated DAO (Pareto stakes)')
    print('=' * 60)

    print(f'\n  Flip rate:          {flip.aggregate:.1%} of proposals changed outcome')
    print(f'  Gini (Legacy):      {gini.legacy:.3f}')
    print(f'  Gini (Signals):     {gini.signals:.3f}  ({_delta(gini.signals, gini.legacy)})')

    leg_enp = np.mean(list(enp.legacy.values()))
    sig_enp = np.mean(list(enp.signals.values()))
    print(f'  ENP (Legacy):       {leg_enp:.1f}')
    print(f'  ENP (Signals):      {sig_enp:.1f}  ({_delta(sig_enp, leg_enp)})')

    leg_nak = np.mean(list(nakamoto.legacy.values()))
    sig_nak = np.mean(list(nakamoto.signals.values()))
    print(f'  Nakamoto (Legacy):  {leg_nak:.1f}')
    print(f'  Nakamoto (Signals): {sig_nak:.1f}  ({_delta(sig_nak, leg_nak)})')

    leg_top1 = np.nanmean(list(topk.legacy[1].values()))
    sig_top1 = np.nanmean(list(topk.signals[1].values()))
    print(f'  Top-1 share (Leg):  {leg_top1:.1%}')
    print(f'  Top-1 share (Sig):  {sig_top1:.1%}  ({_delta(sig_top1, leg_top1)})')

    print(f'  Margin shift (avg): {margin.aggregate_mean:+.3f} (std {margin.aggregate_std:.3f})')

    pp, pf = transition.counts[0]
    fp, ff = transition.counts[1]
    print(f'  Transition matrix:  PP={pp} PF={pf} FP={fp} FF={ff}')
    print()

    # ── Build composite figure ───────────────────────────────────────────────

    fig = matplotlib.figure.Figure(figsize=(18, 12))

    panels = [
        (plot_gini_comparison, [gini], 'Voting Power Inequality'),
        (plot_lorenz_curve, [results_df], 'Power Distribution'),
        (plot_top_k_comparison, [topk], 'Whale Concentration'),
        (plot_flip_rate_summary, [flip], 'Outcome Flips'),
        (plot_margin_shift_histogram, [margin], 'Margin Shifts'),
        (plot_transition_matrix, [transition], 'Outcome Transitions'),
    ]

    for idx, (plot_fn, args, title) in enumerate(panels):
        panel_fig = plot_fn(*args)
        src_ax = panel_fig.axes[0]
        dest_ax = fig.add_subplot(2, 3, idx + 1)

        # Replay the artists from the source panel into our composite
        _copy_ax(src_ax, dest_ax)
        dest_ax.set_title(title, fontsize=12, fontweight='bold')

    fig.suptitle(
        'Simulation A — Whale-dominated DAO: Legacy vs Signals Governance',
        fontsize=16, fontweight='bold', y=0.98,
    )
    fig.tight_layout(rect=[0, 0, 1, 0.94])

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    fig.savefig(OUTPUT_FILE, dpi=200, bbox_inches='tight', facecolor='white')
    print(f'  Saved: {OUTPUT_FILE}')


def _delta(new: float, old: float) -> str:
    diff = new - old
    if diff > 0:
        return f'+{diff:.3f}'
    return f'{diff:.3f}'


def _copy_ax(src, dest):
    """Copy basic bar/line/patch data from src axes to dest axes."""
    for container in src.containers:
        heights = [bar.get_height() for bar in container]
        xs = [bar.get_x() for bar in container]
        widths = [bar.get_width() for bar in container]
        color = container[0].get_facecolor() if len(container) > 0 else BLUE
        label = container.get_label()
        dest.bar(xs, heights, width=widths[0] if widths else 0.35,
                 color=color, label=label, zorder=3, align='edge')

    for line in src.get_lines():
        dest.plot(line.get_xdata(), line.get_ydata(),
                  color=line.get_color(), linewidth=line.get_linewidth(),
                  linestyle=line.get_linestyle(), label=line.get_label())

    for img in src.get_images():
        dest.imshow(img.get_array(), cmap=img.get_cmap(), aspect='auto')

    dest.set_xlabel(src.get_xlabel(), fontsize=9)
    dest.set_ylabel(src.get_ylabel(), fontsize=9)
    dest.set_xlim(src.get_xlim())
    dest.set_ylim(src.get_ylim())
    dest.set_xticks(src.get_xticks())
    if src.get_xticklabels():
        labels = [t.get_text() for t in src.get_xticklabels()]
        if any(labels):
            dest.set_xticklabels(labels, fontsize=8, rotation=45, ha='right')
    if src.get_legend_handles_labels()[1]:
        dest.legend(fontsize=8)


if __name__ == '__main__':
    main()
