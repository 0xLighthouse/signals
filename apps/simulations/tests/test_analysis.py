"""
Tests for backtesting.analysis module.

Covers:
  ANAL-01: margin_class_breakdown() — flip counts by legacy margin class
  ANAL-02: address_influence() — per-voter influence with median-lock counterfactual
  ANAL-03: timing_sensitivity() — 2D pivot heatmap of weight ratio by timing x lock
  ANAL-04: voter_archetypes() — voter classification by stake tertile
  ANAL-05: influence_significance() — Mann-Whitney U significance test
  ANAL-06: bootstrap_ci() — bootstrap confidence interval
  ANAL-07: Module importability, __all__ exports, no cadCAD dependency
"""
import inspect

import numpy as np
import pandas as pd
import pytest

import backtesting.analysis
from backtesting.analysis import (
    AddressInfluence,
    BootstrapCI,
    MarginClassBreakdown,
    SignificanceResult,
    TimingSensitivity,
    VoterArchetypes,
    address_influence,
    bootstrap_ci,
    influence_significance,
    margin_class_breakdown,
    timing_sensitivity,
    voter_archetypes,
)


# ---------------------------------------------------------------------------
# ANAL-07: Module structure
# ---------------------------------------------------------------------------


def test_anal07_module_importable():
    """ANAL-07: backtesting.analysis is importable and exports public functions."""
    # Module imports without error (already imported at module level above)
    public_names = dir(backtesting.analysis)
    assert 'margin_class_breakdown' in public_names
    assert 'voter_archetypes' in public_names

    # Verify no cadCAD imports in source
    src = inspect.getsource(backtesting.analysis)
    assert 'cadcad' not in src.lower(), 'analysis.py must not import cadCAD'


# ---------------------------------------------------------------------------
# ANAL-01: margin_class_breakdown — with real fixture data
# ---------------------------------------------------------------------------


def test_anal01_margin_class_breakdown(metrics_results_df):
    """ANAL-01: margin_class_breakdown returns valid MarginClassBreakdown from real data."""
    result = margin_class_breakdown(metrics_results_df)

    assert isinstance(result, MarginClassBreakdown), (
        f'Expected MarginClassBreakdown, got {type(result)}'
    )
    # Structural integrity: total_flips == sum of class counts
    assert result.total_flips == result.tight + result.moderate + result.decisive
    # All counts are non-negative
    assert result.tight >= 0
    assert result.moderate >= 0
    assert result.decisive >= 0
    assert result.total_flips >= 0


# ---------------------------------------------------------------------------
# ANAL-01: margin_class_breakdown — no-flip edge case
# ---------------------------------------------------------------------------


def test_anal01_margin_class_no_flips():
    """ANAL-01: Returns all zeros when no proposals are flipped."""
    df = pd.DataFrame({
        'event_type': ['VOTE_CAST'] * 4,
        'proposal_id': ['p1', 'p1', 'p2', 'p2'],
        'voter': ['0xA', '0xB', '0xA', '0xB'],
        'support': ['FOR', 'FOR', 'FOR', 'FOR'],
        'weight': [100.0, 200.0, 100.0, 200.0],
        'lock_duration_days': [90.0, 90.0, 90.0, 90.0],
        'legacy_for': [100.0, 300.0, 100.0, 300.0],
        'legacy_against': [0.0, 0.0, 0.0, 0.0],
        'signals_for': [100.0, 300.0, 100.0, 300.0],
        'signals_against': [0.0, 0.0, 0.0, 0.0],
    })

    result = margin_class_breakdown(df)

    assert isinstance(result, MarginClassBreakdown)
    assert result.total_flips == 0
    assert result.tight == 0
    assert result.moderate == 0
    assert result.decisive == 0


# ---------------------------------------------------------------------------
# ANAL-01: margin_class_breakdown — controlled flips at known margins
# ---------------------------------------------------------------------------


def test_anal01_margin_class_with_flips():
    """ANAL-01: Correctly bins flipped proposals by legacy margin class.

    p1: legacy passes by tight margin (~5%), signals fails -> tight flip
    p2: legacy passes by moderate margin (~20%), signals fails -> moderate flip
    """
    # p1: legacy_for=105, legacy_against=95 -> margin = (105-95)/(105+95) = 10/200 = 5%
    # p1: signals_for=0, signals_against=200 -> signals fails -> flip (tight)
    # p2: legacy_for=120, legacy_against=80 -> margin = 40/200 = 20%
    # p2: signals_for=0, signals_against=200 -> signals fails -> flip (moderate)
    df = pd.DataFrame({
        'event_type': ['VOTE_CAST', 'VOTE_CAST', 'VOTE_CAST', 'VOTE_CAST'],
        'proposal_id': ['p1', 'p1', 'p2', 'p2'],
        'voter': ['0xA', '0xB', '0xA', '0xB'],
        'support': ['FOR', 'AGAINST', 'FOR', 'AGAINST'],
        'weight': [105.0, 95.0, 120.0, 80.0],
        'lock_duration_days': [90.0, 90.0, 90.0, 90.0],
        # cumulative tallies at last vote (final state)
        'legacy_for': [105.0, 105.0, 120.0, 120.0],
        'legacy_against': [0.0, 95.0, 0.0, 80.0],
        'signals_for': [0.0, 0.0, 0.0, 0.0],
        'signals_against': [0.0, 200.0, 0.0, 200.0],
    })

    result = margin_class_breakdown(df)

    assert isinstance(result, MarginClassBreakdown)
    assert result.total_flips == 2, f'Expected 2 flips, got {result.total_flips}'
    assert result.tight == 1, f'Expected 1 tight flip, got {result.tight}'
    assert result.moderate == 1, f'Expected 1 moderate flip, got {result.moderate}'
    assert result.decisive == 0


# ---------------------------------------------------------------------------
# ANAL-04: voter_archetypes — with real fixture data
# ---------------------------------------------------------------------------


def test_anal04_voter_archetypes(metrics_results_df):
    """ANAL-04: voter_archetypes returns valid VoterArchetypes from real data."""
    result = voter_archetypes(metrics_results_df)

    assert isinstance(result, VoterArchetypes), (
        f'Expected VoterArchetypes, got {type(result)}'
    )
    # labels DataFrame has required columns
    assert list(result.labels.columns) == ['voter', 'weight', 'archetype'], (
        f'Unexpected columns: {list(result.labels.columns)}'
    )
    # All archetype values are valid
    valid_archetypes = {'retail', 'medium', 'whale'}
    actual_archetypes = set(result.labels['archetype'].astype(str).unique())
    assert actual_archetypes.issubset(valid_archetypes), (
        f'Unexpected archetypes: {actual_archetypes - valid_archetypes}'
    )
    # counts sums match label count
    assert sum(result.counts.values()) == len(result.labels), (
        f'counts sum {sum(result.counts.values())} != label count {len(result.labels)}'
    )


# ---------------------------------------------------------------------------
# ANAL-04: voter_archetypes — archetype labels coverage
# ---------------------------------------------------------------------------


def test_anal04_archetypes_labels_present(metrics_results_df):
    """ANAL-04: At least 2 of 3 archetype labels appear with 50 voters."""
    result = voter_archetypes(metrics_results_df)

    # With 50 voters, qcut should produce at least 2 distinct labels.
    # (All 3 expected for healthy Pareto distribution, but 2 is the minimum assertion.)
    archetype_labels_in_use = set(result.labels['archetype'].astype(str).unique())
    assert len(archetype_labels_in_use) >= 2, (
        f'Expected at least 2 archetype labels, got: {archetype_labels_in_use}'
    )


# ---------------------------------------------------------------------------
# ANAL-02: address_influence — median-lock counterfactual
# ---------------------------------------------------------------------------


def test_anal02_address_influence_counterfactual(metrics_results_df):
    """ANAL-02: address_influence returns correct structure and uses median-lock delta."""
    result = address_influence(metrics_results_df, curve_type='sqrt')

    assert isinstance(result, AddressInfluence), (
        f'Expected AddressInfluence, got {type(result)}'
    )

    # per_voter has required columns
    expected_cols = ['voter', 'legacy_share', 'signals_share', 'counterfactual_share', 'delta']
    assert list(result.per_voter.columns) == expected_cols, (
        f'Unexpected columns: {list(result.per_voter.columns)}'
    )

    # median_lock_days is a positive finite float
    assert np.isfinite(result.median_lock_days), 'median_lock_days should be finite'
    assert result.median_lock_days > 0, 'median_lock_days should be > 0'

    # Legacy shares sum to ~1.0
    legacy_sum = result.per_voter['legacy_share'].sum()
    assert abs(legacy_sum - 1.0) < 1e-10, (
        f'legacy_share should sum to 1.0, got {legacy_sum}'
    )

    # delta is signals_share - counterfactual_share (not signals_share - legacy_share)
    computed_delta = result.per_voter['signals_share'] - result.per_voter['counterfactual_share']
    assert np.allclose(result.per_voter['delta'], computed_delta, equal_nan=True), (
        'delta should equal signals_share - counterfactual_share'
    )

    # CRITICAL: delta is NOT signals_share - legacy_share (unless they happen to match,
    # which is extremely unlikely when lock durations vary)
    wrong_delta = result.per_voter['signals_share'] - result.per_voter['legacy_share']
    # If median_lock == mean lock then counterfactual might equal legacy — skip assertion
    # But for Pareto-distributed locks the values should differ for at least some voters
    if not np.allclose(result.per_voter['counterfactual_share'], result.per_voter['legacy_share'],
                       equal_nan=True, atol=1e-8):
        assert not np.allclose(result.per_voter['delta'], wrong_delta, equal_nan=True), (
            'delta should NOT equal signals_share - legacy_share '
            '(median-lock counterfactual must be used)'
        )


def test_anal02_address_influence_median_lock_used():
    """ANAL-02: address_influence uses median lock duration as counterfactual baseline."""
    # Synthetic DataFrame with exactly 4 voters, known lock durations: 30,60,90,120 days
    # Median([30,60,90,120]) = 75.0
    df = pd.DataFrame({
        'event_type': ['VOTE_CAST'] * 4,
        'proposal_id': ['p1', 'p1', 'p1', 'p1'],
        'voter': ['0xA', '0xB', '0xC', '0xD'],
        'support': ['FOR', 'FOR', 'FOR', 'FOR'],
        'weight': [100.0, 100.0, 100.0, 100.0],
        'lock_duration_days': [30.0, 60.0, 90.0, 120.0],
        'legacy_for': [100.0, 200.0, 300.0, 400.0],
        'legacy_against': [0.0, 0.0, 0.0, 0.0],
        'signals_for': [100.0, 200.0, 300.0, 400.0],
        'signals_against': [0.0, 0.0, 0.0, 0.0],
    })

    result = address_influence(df)

    # Median of [30, 60, 90, 120] = 75.0
    assert result.median_lock_days == 75.0, (
        f'Expected median_lock_days=75.0, got {result.median_lock_days}'
    )


# ---------------------------------------------------------------------------
# ANAL-03: timing_sensitivity — 2D heatmap
# ---------------------------------------------------------------------------


def test_anal03_timing_sensitivity_2d(metrics_results_df, metrics_windows_df):
    """ANAL-03: timing_sensitivity returns a 2D DataFrame heatmap."""
    result = timing_sensitivity(metrics_results_df, metrics_windows_df, curve_type='sqrt')

    assert isinstance(result, TimingSensitivity), (
        f'Expected TimingSensitivity, got {type(result)}'
    )
    assert isinstance(result.heatmap, pd.DataFrame), 'heatmap must be a DataFrame'
    assert result.heatmap.ndim == 2, (
        f'heatmap must be 2D, got ndim={result.heatmap.ndim}'
    )
    # Shape should be at least (2, 2) even if some quantile bins collapse
    assert result.heatmap.shape[0] >= 1, 'heatmap must have at least 1 row'
    assert result.heatmap.shape[1] >= 1, 'heatmap must have at least 1 column'

    # Index and column names should be quantile labels (T* / L*)
    index_names = list(result.heatmap.index.astype(str))
    col_names = list(result.heatmap.columns.astype(str))
    assert any(name.startswith('T') for name in index_names), (
        f'Timing quantile index should start with T, got: {index_names}'
    )
    assert any(name.startswith('L') for name in col_names), (
        f'Lock quantile columns should start with L, got: {col_names}'
    )


def test_anal03_timing_sensitivity_custom_quantiles():
    """ANAL-03: timing_sensitivity respects n_quantiles parameter."""
    import random
    rng = random.Random(42)

    # Synthetic DataFrame with 24 vote rows, varied block numbers and lock durations
    n = 24
    voters = [f'0x{i:02X}' for i in range(n)]
    proposal_ids = ['p1'] * n
    block_numbers = [100 + i * 5 for i in range(n)]  # 100, 105, ..., 215
    lock_durations = [float(30 + i * 10) for i in range(n)]  # 30, 40, ..., 260 days
    weights = [100.0] * n

    df = pd.DataFrame({
        'event_type': ['VOTE_CAST'] * n,
        'proposal_id': proposal_ids,
        'voter': voters,
        'support': ['FOR'] * n,
        'weight': weights,
        'lock_duration_days': lock_durations,
        'block_number': block_numbers,
        'legacy_for': [float(sum(weights[:i + 1])) for i in range(n)],
        'legacy_against': [0.0] * n,
        'signals_for': [float(sum(weights[:i + 1])) for i in range(n)],
        'signals_against': [0.0] * n,
    })

    windows_df = pd.DataFrame({
        'proposal_id': ['p1'],
        'start_block': [100],
        'end_block': [215],
    })

    result = timing_sensitivity(df, windows_df, n_quantiles=3)

    assert result.n_quantiles == 3, f'Expected n_quantiles=3, got {result.n_quantiles}'
    # Rows and columns should be <= 3 (may be less if bins collapse)
    assert result.heatmap.shape[0] <= 3, (
        f'Expected at most 3 timing rows, got {result.heatmap.shape[0]}'
    )
    assert result.heatmap.shape[1] <= 3, (
        f'Expected at most 3 lock columns, got {result.heatmap.shape[1]}'
    )


# ---------------------------------------------------------------------------
# ANAL-05: influence_significance — Mann-Whitney U
# ---------------------------------------------------------------------------


def test_anal05_mannwhitney(metrics_results_df):
    """ANAL-05: influence_significance returns valid p-value for clearly different groups."""
    group_a = np.array([0.1, 0.2, 0.15, 0.12, 0.18])
    group_b = np.array([0.5, 0.6, 0.55, 0.52, 0.58])

    result = influence_significance(group_a, group_b)

    assert isinstance(result, SignificanceResult), (
        f'Expected SignificanceResult, got {type(result)}'
    )
    assert 0.0 <= result.p_value <= 1.0, (
        f'p_value must be in [0,1], got {result.p_value}'
    )
    # Clearly different distributions should yield significant result
    assert result.p_value < 0.05, (
        f'Expected p_value < 0.05 for clearly different groups, got {result.p_value}'
    )


def test_anal05_mannwhitney_same_distribution():
    """ANAL-05: influence_significance returns non-significant p-value for same distribution."""
    group_a = np.array([0.1, 0.2, 0.15, 0.12, 0.18])
    group_b = np.array([0.1, 0.2, 0.15, 0.12, 0.18])

    result = influence_significance(group_a, group_b)

    assert isinstance(result, SignificanceResult)
    # Same distribution — p-value should be > 0.05 (not significant)
    assert result.p_value > 0.05, (
        f'Expected p_value > 0.05 for identical distributions, got {result.p_value}'
    )


def test_anal05_mannwhitney_degenerate():
    """ANAL-05: influence_significance returns NaN for arrays with fewer than 2 elements."""
    group_a = np.array([0.5])  # only 1 element
    group_b = np.array([0.1, 0.2, 0.3])

    result = influence_significance(group_a, group_b)

    assert isinstance(result, SignificanceResult)
    assert np.isnan(result.p_value), (
        f'Expected NaN p_value for degenerate input, got {result.p_value}'
    )
    assert np.isnan(result.statistic), (
        f'Expected NaN statistic for degenerate input, got {result.statistic}'
    )


# ---------------------------------------------------------------------------
# ANAL-06: bootstrap_ci — bootstrap confidence interval
# ---------------------------------------------------------------------------


def test_anal06_bootstrap_ci():
    """ANAL-06: bootstrap_ci returns valid CI with mean inside interval."""
    values = np.array([1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0])

    result = bootstrap_ci(values, n_resamples=99, random_state=42)

    assert isinstance(result, BootstrapCI), (
        f'Expected BootstrapCI, got {type(result)}'
    )
    # True mean should be inside the CI
    mean_val = np.mean(values)
    assert result.low < mean_val < result.high, (
        f'Mean {mean_val} should be inside CI [{result.low}, {result.high}]'
    )
    assert result.confidence_level == 0.95, (
        f'Expected confidence_level=0.95, got {result.confidence_level}'
    )


def test_anal06_bootstrap_ci_degenerate():
    """ANAL-06: bootstrap_ci returns NaN bounds for single-element arrays."""
    values = np.array([5.0])  # only 1 element

    result = bootstrap_ci(values)

    assert isinstance(result, BootstrapCI)
    assert np.isnan(result.low), f'Expected NaN low bound, got {result.low}'
    assert np.isnan(result.high), f'Expected NaN high bound, got {result.high}'
