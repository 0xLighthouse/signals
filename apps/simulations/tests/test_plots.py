"""
Plot tests — PLOT-01 through PLOT-12.

Each test asserts:
1. The function returns isinstance(fig, Figure)
2. The figure has at least one axes
3. Spot-check title or axes label to confirm correct content

PLOT-12 compliance test additionally verifies matplotlib.pyplot is not in sys.modules.
"""
import sys
import os
import warnings

import matplotlib
matplotlib.use('Agg')  # Must be before any Figure import

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

import pytest
from matplotlib.figure import Figure

from backtesting.plots import (
    plot_flip_rate_summary,
    plot_margin_shift_histogram,
    plot_transition_matrix,
    plot_gini_comparison,
    plot_top_k_comparison,
    plot_enp_comparison,
    plot_cumulative_vote_curve,
    plot_late_vote_share,
    plot_lorenz_curve,
    plot_proposal_story,
    plot_lock_duration_histogram,
)
from backtesting.metrics import (
    compute_flip_rate,
    compute_gini,
    compute_enp,
    compute_margin_shift,
    compute_transition_matrix,
    compute_late_vote_share,
    compute_lockin_timing,
    compute_top_k_concentration,
)


def test_plot_01_flip_rate_returns_figure(metrics_results_df):
    """PLOT-01: Flip rate summary bar chart returns a Figure."""
    result = compute_flip_rate(metrics_results_df)
    fig = plot_flip_rate_summary(result)
    assert isinstance(fig, Figure)
    assert len(fig.get_axes()) >= 1
    ax = fig.get_axes()[0]
    assert 'Flip Rate' in ax.get_title()


def test_plot_02_margin_shift_returns_figure(metrics_results_df):
    """PLOT-02: Margin shift histogram returns a Figure."""
    result = compute_margin_shift(metrics_results_df)
    fig = plot_margin_shift_histogram(result)
    assert isinstance(fig, Figure)
    assert len(fig.get_axes()) >= 1
    ax = fig.get_axes()[0]
    assert 'Margin' in ax.get_title()


def test_plot_03_transition_matrix_returns_figure(metrics_results_df):
    """PLOT-03: Outcome transition matrix heatmap returns a Figure."""
    result = compute_transition_matrix(metrics_results_df)
    fig = plot_transition_matrix(result)
    assert isinstance(fig, Figure)
    assert len(fig.get_axes()) >= 1
    ax = fig.get_axes()[0]
    assert 'Transition' in ax.get_title()


def test_plot_04_gini_comparison_returns_figure(metrics_results_df):
    """PLOT-04: Gini comparison bar chart returns a Figure."""
    result = compute_gini(metrics_results_df)
    fig = plot_gini_comparison(result)
    assert isinstance(fig, Figure)
    assert len(fig.get_axes()) >= 1
    ax = fig.get_axes()[0]
    assert 'Gini' in ax.get_title()


def test_plot_05_top_k_comparison_returns_figure(metrics_results_df):
    """PLOT-05: Top-k share comparison chart returns a Figure."""
    result = compute_top_k_concentration(metrics_results_df)
    fig = plot_top_k_comparison(result)
    assert isinstance(fig, Figure)
    assert len(fig.get_axes()) >= 1
    ax = fig.get_axes()[0]
    assert 'Top' in ax.get_title() or 'Concentration' in ax.get_title()


def test_plot_06_enp_comparison_returns_figure(metrics_results_df):
    """PLOT-06: ENP comparison visualization returns a Figure."""
    result = compute_enp(metrics_results_df)
    fig = plot_enp_comparison(result)
    assert isinstance(fig, Figure)
    assert len(fig.get_axes()) >= 1
    ax = fig.get_axes()[0]
    assert 'ENP' in ax.get_title()


def test_plot_07_cumulative_vote_curve_returns_figure(metrics_results_df):
    """PLOT-07: Cumulative vote curve returns a Figure for a given proposal."""
    vote_rows = metrics_results_df[metrics_results_df['event_type'] == 'VOTE_CAST']
    proposal_id = vote_rows['proposal_id'].iloc[0]
    fig = plot_cumulative_vote_curve(metrics_results_df, proposal_id)
    assert isinstance(fig, Figure)
    assert len(fig.get_axes()) >= 1
    ax = fig.get_axes()[0]
    assert 'Cumulative' in ax.get_title()


def test_plot_08_late_vote_share_returns_figure(metrics_results_df, metrics_windows_df):
    """PLOT-08: Late-vote share comparison returns a Figure."""
    result = compute_late_vote_share(metrics_results_df, metrics_windows_df)
    fig = plot_late_vote_share(result)
    assert isinstance(fig, Figure)
    assert len(fig.get_axes()) >= 1
    ax = fig.get_axes()[0]
    assert 'Late' in ax.get_title()


def test_plot_09_lorenz_curve_returns_figure(metrics_results_df):
    """PLOT-09: Lorenz curve returns a Figure with equality line."""
    fig = plot_lorenz_curve(metrics_results_df)
    assert isinstance(fig, Figure)
    assert len(fig.get_axes()) >= 1
    ax = fig.get_axes()[0]
    assert 'Lorenz' in ax.get_title()
    # At least 3 lines: legacy, signals, equality line
    assert len(ax.get_lines()) >= 3


def test_plot_10_proposal_story_returns_figure(metrics_results_df, metrics_windows_df):
    """PLOT-10: Proposal story plot returns a Figure with two margin lines."""
    from backtesting.metrics import compute_lockin_timing
    lockin = compute_lockin_timing(metrics_results_df, metrics_windows_df)
    vote_rows = metrics_results_df[metrics_results_df['event_type'] == 'VOTE_CAST']
    proposal_id = vote_rows['proposal_id'].iloc[0]
    fig = plot_proposal_story(metrics_results_df, proposal_id, lockin)
    assert isinstance(fig, Figure)
    assert len(fig.get_axes()) >= 1
    ax = fig.get_axes()[0]
    assert 'Story' in ax.get_title() or 'story' in ax.get_title().lower()
    # Two margin lines minimum (legacy + signals)
    assert len(ax.get_lines()) >= 2


def test_plot_11_lock_duration_histogram_returns_figure(metrics_results_df):
    """PLOT-11: Lock duration histogram with Signals weight overlay returns a Figure."""
    fig = plot_lock_duration_histogram(metrics_results_df)
    assert isinstance(fig, Figure)
    # twinx creates 2 axes
    assert len(fig.get_axes()) >= 1
    ax = fig.get_axes()[0]
    assert 'Lock' in ax.get_title() or 'Duration' in ax.get_title()


def test_plot_12_no_pyplot_state():
    """PLOT-12: backtesting.plots must not import matplotlib.pyplot."""
    # Remove cached module to test fresh import
    modules_to_remove = [k for k in sys.modules if k.startswith('backtesting.plots')]
    for mod in modules_to_remove:
        del sys.modules[mod]
    # Also remove pyplot so we can detect if plots.py re-imports it
    pyplot_was_present = 'matplotlib.pyplot' in sys.modules
    if 'matplotlib.pyplot' in sys.modules:
        del sys.modules['matplotlib.pyplot']

    import backtesting.plots  # noqa: F401

    assert 'matplotlib.pyplot' not in sys.modules, (
        'backtesting.plots imported matplotlib.pyplot — violates PLOT-12 OO API requirement. '
        'Remove any "import matplotlib.pyplot" from plots.py.'
    )
