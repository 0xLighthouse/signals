"""
Tests for backtesting.metrics — governance metric pure functions.

Each test corresponds to one METR requirement (METR-01 through METR-10).
All tests use metrics_results_df and metrics_windows_df fixtures from conftest.
"""
import math

import numpy as np
import pytest

from backtesting.metrics import (
    FlipRateResult,
    GiniResult,
    ENPResult,
    LateVoteShareResult,
    LockinTimingResult,
    MarginShiftResult,
    NakamotoResult,
    ParticipationResult,
    TopKConcentrationResult,
    TransitionMatrix,
    compute_enp,
    compute_flip_rate,
    compute_gini,
    compute_late_vote_share,
    compute_lockin_timing,
    compute_margin_shift,
    compute_nakamoto_coefficient,
    compute_participation_rate,
    compute_top_k_concentration,
    compute_transition_matrix,
)


# ---------------------------------------------------------------------------
# METR-01: Flip rate
# ---------------------------------------------------------------------------

def test_flip_rate(metrics_results_df):
    """METR-01: compute_flip_rate returns FlipRateResult with correct types and value ranges."""
    result = compute_flip_rate(metrics_results_df)

    assert isinstance(result, FlipRateResult)
    assert isinstance(result.per_proposal, dict)
    assert isinstance(result.aggregate, float)
    assert 0.0 <= result.aggregate <= 1.0

    # All per-proposal values must be bool
    for pid, flipped in result.per_proposal.items():
        assert isinstance(flipped, bool), f"per_proposal[{pid}] is {type(flipped)}, expected bool"

    # One entry per proposal in VOTE_CAST rows
    vote_df = metrics_results_df[metrics_results_df['event_type'] == 'VOTE_CAST']
    n_proposals = vote_df['proposal_id'].nunique()
    assert len(result.per_proposal) == n_proposals


# ---------------------------------------------------------------------------
# METR-02: Gini coefficient
# ---------------------------------------------------------------------------

def test_gini(metrics_results_df):
    """METR-02: compute_gini returns GiniResult with values in [0, 1]."""
    result = compute_gini(metrics_results_df)

    assert isinstance(result, GiniResult)
    assert isinstance(result.legacy, float)
    assert isinstance(result.signals, float)
    assert 0.0 <= result.legacy <= 1.0, f"legacy Gini out of range: {result.legacy}"
    assert 0.0 <= result.signals <= 1.0, f"signals Gini out of range: {result.signals}"
    # Pareto stake distribution produces positive inequality
    assert result.legacy >= 0.0


# ---------------------------------------------------------------------------
# METR-03: Participation rate
# ---------------------------------------------------------------------------

def test_participation_rate(metrics_results_df):
    """METR-03: compute_participation_rate returns ParticipationResult with correct structure."""
    result = compute_participation_rate(metrics_results_df)

    assert isinstance(result, ParticipationResult)
    assert isinstance(result.per_proposal, dict)
    assert isinstance(result.aggregate, float)
    assert 0.0 <= result.aggregate <= 1.0

    for pid, rate in result.per_proposal.items():
        assert 0.0 <= rate <= 1.0, f"per_proposal[{pid}] = {rate} out of [0, 1]"

    vote_df = metrics_results_df[metrics_results_df['event_type'] == 'VOTE_CAST']
    n_proposals = vote_df['proposal_id'].nunique()
    assert len(result.per_proposal) == n_proposals


# ---------------------------------------------------------------------------
# METR-04: Effective Number of Parties
# ---------------------------------------------------------------------------

def test_enp(metrics_results_df):
    """METR-04: compute_enp returns ENPResult with ENP >= 1 per proposal."""
    result = compute_enp(metrics_results_df)

    assert isinstance(result, ENPResult)
    assert isinstance(result.legacy, dict)
    assert isinstance(result.signals, dict)

    # Same proposal IDs in both regimes
    assert set(result.legacy.keys()) == set(result.signals.keys())

    # ENP >= 1 when votes exist (single voter has ENP = 1)
    for pid, enp_val in result.legacy.items():
        assert enp_val >= 1.0, f"legacy ENP[{pid}] = {enp_val} < 1.0"
    for pid, enp_val in result.signals.items():
        assert enp_val >= 1.0, f"signals ENP[{pid}] = {enp_val} < 1.0"

    vote_df = metrics_results_df[metrics_results_df['event_type'] == 'VOTE_CAST']
    n_proposals = vote_df['proposal_id'].nunique()
    assert len(result.legacy) == n_proposals


# ---------------------------------------------------------------------------
# METR-05: Nakamoto coefficient
# ---------------------------------------------------------------------------

def test_nakamoto_coefficient(metrics_results_df):
    """METR-05: compute_nakamoto_coefficient returns NakamotoResult with positive ints."""
    result = compute_nakamoto_coefficient(metrics_results_df)

    assert isinstance(result, NakamotoResult)
    assert isinstance(result.legacy, dict)
    assert isinstance(result.signals, dict)
    assert set(result.legacy.keys()) == set(result.signals.keys())

    vote_df = metrics_results_df[metrics_results_df['event_type'] == 'VOTE_CAST']
    vote_df = vote_df[vote_df['support'].isin(['FOR', 'AGAINST'])]
    n_unique_voters = vote_df['voter'].nunique()

    for pid, coeff in result.legacy.items():
        assert isinstance(coeff, int), f"legacy Nakamoto[{pid}] is {type(coeff)}, expected int"
        assert coeff >= 1, f"legacy Nakamoto[{pid}] = {coeff} < 1"
        assert coeff <= n_unique_voters, (
            f"legacy Nakamoto[{pid}] = {coeff} > total voters {n_unique_voters}"
        )

    for pid, coeff in result.signals.items():
        assert isinstance(coeff, int), f"signals Nakamoto[{pid}] is {type(coeff)}, expected int"
        assert coeff >= 1, f"signals Nakamoto[{pid}] = {coeff} < 1"
        assert coeff <= n_unique_voters, (
            f"signals Nakamoto[{pid}] = {coeff} > total voters {n_unique_voters}"
        )


# ---------------------------------------------------------------------------
# METR-06: Margin shift
# ---------------------------------------------------------------------------

def test_margin_shift(metrics_results_df):
    """METR-06: compute_margin_shift returns MarginShiftResult with correct structure."""
    result = compute_margin_shift(metrics_results_df)

    assert isinstance(result, MarginShiftResult)
    assert isinstance(result.per_proposal, dict)
    assert isinstance(result.aggregate_mean, float)
    assert isinstance(result.aggregate_std, float)
    # std is always non-negative
    assert result.aggregate_std >= 0.0

    vote_df = metrics_results_df[metrics_results_df['event_type'] == 'VOTE_CAST']
    n_proposals = vote_df['proposal_id'].nunique()
    assert len(result.per_proposal) == n_proposals

    # Each per-proposal value is a float (can be any sign; margins range -1 to 1)
    for pid, shift in result.per_proposal.items():
        assert isinstance(shift, float), f"per_proposal[{pid}] is {type(shift)}"


# ---------------------------------------------------------------------------
# METR-07: Transition matrix
# ---------------------------------------------------------------------------

def test_transition_matrix(metrics_results_df):
    """METR-07: compute_transition_matrix returns TransitionMatrix with valid counts and proportions."""
    result = compute_transition_matrix(metrics_results_df)

    assert isinstance(result, TransitionMatrix)

    # counts is 2x2 tuple of ints
    assert len(result.counts) == 2
    assert len(result.counts[0]) == 2
    assert len(result.counts[1]) == 2

    pp = result.counts[0][0]
    pf = result.counts[0][1]
    fp = result.counts[1][0]
    ff = result.counts[1][1]

    vote_df = metrics_results_df[metrics_results_df['event_type'] == 'VOTE_CAST']
    n_proposals = vote_df['proposal_id'].nunique()

    # All proposals classified
    assert pp + pf + fp + ff == n_proposals

    # All proportions in [0, 1]
    for row in result.proportions:
        for val in row:
            assert 0.0 <= val <= 1.0, f"Proportion {val} out of [0, 1]"

    # Proportions sum to 1.0 (or 0.0 if no proposals)
    total_proportion = sum(v for row in result.proportions for v in row)
    if n_proposals > 0:
        assert abs(total_proportion - 1.0) < 1e-9, (
            f"Proportions sum to {total_proportion}, expected 1.0"
        )


# ---------------------------------------------------------------------------
# METR-08: Late vote share
# ---------------------------------------------------------------------------

def test_late_vote_share(metrics_results_df, metrics_windows_df):
    """METR-08: compute_late_vote_share returns LateVoteShareResult with values in [0, 1]."""
    result = compute_late_vote_share(metrics_results_df, metrics_windows_df)

    assert isinstance(result, LateVoteShareResult)
    assert isinstance(result.legacy, dict)
    assert isinstance(result.signals, dict)
    assert set(result.legacy.keys()) == set(result.signals.keys())

    vote_df = metrics_results_df[metrics_results_df['event_type'] == 'VOTE_CAST']
    n_proposals = vote_df['proposal_id'].nunique()
    assert len(result.legacy) == n_proposals

    # Non-nan values must be in [0, 1]
    for pid, val in result.legacy.items():
        if not math.isnan(val):
            assert 0.0 <= val <= 1.0, f"legacy late_vote_share[{pid}] = {val} out of [0, 1]"
    for pid, val in result.signals.items():
        if not math.isnan(val):
            assert 0.0 <= val <= 1.0, f"signals late_vote_share[{pid}] = {val} out of [0, 1]"


# ---------------------------------------------------------------------------
# METR-09: Lock-in timing
# ---------------------------------------------------------------------------

def test_lockin_timing(metrics_results_df, metrics_windows_df):
    """METR-09: compute_lockin_timing returns LockinTimingResult with values in [0, 1]."""
    result = compute_lockin_timing(metrics_results_df, metrics_windows_df)

    assert isinstance(result, LockinTimingResult)
    assert isinstance(result.legacy, dict)
    assert isinstance(result.signals, dict)
    assert set(result.legacy.keys()) == set(result.signals.keys())

    vote_df = metrics_results_df[metrics_results_df['event_type'] == 'VOTE_CAST']
    n_proposals = vote_df['proposal_id'].nunique()
    assert len(result.legacy) == n_proposals

    # Non-nan values must be in [0, 1]
    for pid, val in result.legacy.items():
        if not math.isnan(val):
            assert 0.0 <= val <= 1.0, f"legacy lockin_timing[{pid}] = {val} out of [0, 1]"
    for pid, val in result.signals.items():
        if not math.isnan(val):
            assert 0.0 <= val <= 1.0, f"signals lockin_timing[{pid}] = {val} out of [0, 1]"


# ---------------------------------------------------------------------------
# METR-10: Top-k concentration
# ---------------------------------------------------------------------------

def test_top_k_concentration(metrics_results_df):
    """METR-10: compute_top_k_concentration returns TopKConcentrationResult with k in {1, 5, 10}."""
    result = compute_top_k_concentration(metrics_results_df)

    assert isinstance(result, TopKConcentrationResult)
    assert set(result.legacy.keys()) == {1, 5, 10}
    assert set(result.signals.keys()) == {1, 5, 10}

    vote_df = metrics_results_df[metrics_results_df['event_type'] == 'VOTE_CAST']
    vote_df = vote_df[vote_df['support'].isin(['FOR', 'AGAINST'])]
    proposal_ids = set(vote_df['proposal_id'].unique())

    for k in [1, 5, 10]:
        assert set(result.legacy[k].keys()) == proposal_ids
        assert set(result.signals[k].keys()) == proposal_ids

        for pid in proposal_ids:
            leg_val = result.legacy[k][pid]
            sig_val = result.signals[k][pid]
            if not math.isnan(leg_val):
                assert 0.0 < leg_val <= 1.0, (
                    f"legacy top-{k}[{pid}] = {leg_val} out of (0, 1]"
                )
            if not math.isnan(sig_val):
                assert 0.0 < sig_val <= 1.0, (
                    f"signals top-{k}[{pid}] = {sig_val} out of (0, 1]"
                )

    # Monotonic: top-1 <= top-5 <= top-10 for each proposal and regime
    for pid in proposal_ids:
        leg1 = result.legacy[1][pid]
        leg5 = result.legacy[5][pid]
        leg10 = result.legacy[10][pid]
        sig1 = result.signals[1][pid]
        sig5 = result.signals[5][pid]
        sig10 = result.signals[10][pid]

        if not any(math.isnan(v) for v in [leg1, leg5, leg10]):
            assert leg1 <= leg5 <= leg10, (
                f"legacy concentration not monotonic for {pid}: "
                f"top-1={leg1}, top-5={leg5}, top-10={leg10}"
            )
        if not any(math.isnan(v) for v in [sig1, sig5, sig10]):
            assert sig1 <= sig5 <= sig10, (
                f"signals concentration not monotonic for {pid}: "
                f"top-1={sig1}, top-5={sig5}, top-10={sig10}"
            )


# ---------------------------------------------------------------------------
# Edge case: tie = Fail (locked design decision)
# ---------------------------------------------------------------------------

def test_tie_is_fail():
    """Tie (FOR == AGAINST) must be classified as Fail per locked decision."""
    import pandas as pd

    # Minimal DataFrame with one proposal where FOR == AGAINST (tie)
    tie_df = pd.DataFrame([
        {
            'event_type': 'VOTE_CAST', 'proposal_id': 'p1', 'block_number': 110,
            'voter': '0xA', 'support': 'FOR', 'weight': 1000.0, 'lock_duration_days': 0.0,
            'legacy_for': 1000.0, 'legacy_against': 0.0, 'legacy_abstain': 0.0,
            'signals_for': 1000.0, 'signals_against': 0.0, 'signals_abstain': 0.0,
        },
        {
            'event_type': 'VOTE_CAST', 'proposal_id': 'p1', 'block_number': 120,
            'voter': '0xB', 'support': 'AGAINST', 'weight': 1000.0, 'lock_duration_days': 0.0,
            'legacy_for': 1000.0, 'legacy_against': 1000.0, 'legacy_abstain': 0.0,
            'signals_for': 1000.0, 'signals_against': 1000.0, 'signals_abstain': 0.0,
        },
    ])

    result = compute_flip_rate(tie_df)
    # Both regimes show tie — both Fail — so no flip
    assert result.per_proposal['p1'] is False
    assert result.aggregate == 0.0

    matrix = compute_transition_matrix(tie_df)
    pp = matrix.counts[0][0]
    pf = matrix.counts[0][1]
    fp = matrix.counts[1][0]
    ff = matrix.counts[1][1]
    # Tie = Fail in both regimes: should be in FF cell
    assert ff == 1
    assert pp + pf + fp == 0
