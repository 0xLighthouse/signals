"""
Tests for backtesting.analysis module.

Covers:
  ANAL-01: margin_class_breakdown() — flip counts by legacy margin class
  ANAL-04: voter_archetypes() — voter classification by stake tertile
  ANAL-07: Module importability, __all__ exports, no cadCAD dependency
"""
import inspect

import pandas as pd
import pytest

import backtesting.analysis
from backtesting.analysis import (
    MarginClassBreakdown,
    VoterArchetypes,
    margin_class_breakdown,
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
