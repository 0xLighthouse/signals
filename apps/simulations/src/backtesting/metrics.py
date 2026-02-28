"""
Governance metrics as pure functions on the backtesting results DataFrame.

All functions accept results_df (pd.DataFrame) from build_results_dataframe.
Timing metrics (compute_late_vote_share, compute_lockin_timing) additionally
accept windows_df (pd.DataFrame) with proposal_id, start_block, end_block.

No simulation framework imports. No side effects. All functions return frozen dataclasses.

NaN-for-degenerate-inputs convention: metric helpers return np.nan (not 0.0)
when given zero-sum or zero-weight arrays. NaN propagates silently through
downstream aggregation (np.nanmean, etc.). This is the documented convention
for all metric functions — Phase 11 extended analysis must follow it.
"""
from __future__ import annotations

from dataclasses import dataclass

import numpy as np
import pandas as pd

from backtesting.weighting.signals import compute_signals_weight as _compute_signals_weight


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------


def _gini(arr: np.ndarray) -> float:
    """Standard Gini coefficient for a 1-D array of non-negative values.

    Returns np.nan for zero-sum arrays (NaN-for-degenerate-inputs convention).
    Zero participation is a valid but degenerate case, not 'perfect equality'.
    """
    arr = np.sort(arr.astype(float))
    n = len(arr)
    if n == 0 or arr.sum() == 0:
        return float(np.nan)
    idx = np.arange(1, n + 1)
    return float((2 * (idx * arr).sum()) / (n * arr.sum()) - (n + 1) / n)


def _enp(weights: np.ndarray) -> float:
    """Effective Number of Parties — ENP = 1 / sum(s_i^2).

    Returns np.nan for zero-weight arrays (NaN-for-degenerate-inputs convention).
    ENP=0 is outside the valid range [1, n_voters] and would corrupt sweep heatmaps.
    """
    total = weights.sum()
    if total == 0:
        return float(np.nan)
    shares = weights / total
    return float(1.0 / (shares ** 2).sum())


def _nakamoto(weights: np.ndarray) -> int:
    """Minimum number of voters controlling > 50% of total weight."""
    if len(weights) == 0 or weights.sum() == 0:
        return 0
    sorted_w = np.sort(weights)[::-1]
    cumsum = np.cumsum(sorted_w)
    threshold = 0.5 * sorted_w.sum()
    idx = np.searchsorted(cumsum, threshold, side='left')
    return int(idx + 1)


def _get_final_tallies(results_df: pd.DataFrame) -> pd.DataFrame:
    """Return last VOTE_CAST row per proposal (cumulative tally at proposal end)."""
    vote_df = results_df[results_df['event_type'] == 'VOTE_CAST']
    return (
        vote_df.groupby('proposal_id').last()
        [['legacy_for', 'legacy_against', 'signals_for', 'signals_against']]
        .reset_index()
    )


def _add_signals_weight_column(vote_df: pd.DataFrame, curve_type: str = 'sqrt') -> pd.DataFrame:
    """Return a copy of vote_df with a new `signals_w` column computed per row."""
    vote_df = vote_df.copy()
    vote_df['signals_w'] = np.vectorize(_compute_signals_weight)(
        vote_df['weight'].values,
        vote_df['lock_duration_days'].fillna(0.0).values,
        curve_type,
    )
    return vote_df


def _merge_windows(vote_df: pd.DataFrame, windows_df: pd.DataFrame) -> pd.DataFrame:
    """Merge start_block/end_block into vote rows from windows_df."""
    return vote_df.merge(
        windows_df[['proposal_id', 'start_block', 'end_block']],
        on='proposal_id',
        how='left',
    )


def _compute_lockin_fraction(proposal_df: pd.DataFrame, regime: str) -> float:
    """
    Compute the fraction of the voting window elapsed when the outcome was
    mathematically locked in (remaining votes cannot change the result).

    Returns a value in [0.0, 1.0]:
        0.0 = locked at start of window
        1.0 = locked at end (or never fully locked — all votes were needed)

    Uses cumulative tally columns (legacy_for / signals_for etc.) for the
    running net calculation — these are the correct running totals for
    determining lock-in at each timestep.
    """
    rows = proposal_df.sort_values('block_number').reset_index(drop=True)
    start = float(rows['start_block'].iloc[0])
    end = float(rows['end_block'].iloc[0])
    window = end - start
    if window <= 0 or len(rows) == 0:
        return float('nan')
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
    return 1.0  # never locked in before all votes cast


# ---------------------------------------------------------------------------
# Result dataclasses (all frozen)
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class FlipRateResult:
    """Fraction of proposals whose outcome differs between legacy and Signals."""
    per_proposal: dict[str, bool]  # proposal_id -> True if outcome flipped
    aggregate: float               # fraction of proposals that flipped


@dataclass(frozen=True)
class GiniResult:
    """
    Gini coefficient of voting power distribution.

    Computed over participating voters only (those who cast a vote on any
    proposal). This reflects the inequality among active participants, not
    the full token holder distribution.
    """
    legacy: float
    signals: float


@dataclass(frozen=True)
class ParticipationResult:
    """Per-proposal voter participation rates."""
    per_proposal: dict[str, float]  # proposal_id -> fraction of unique voters
    aggregate: float                # mean of per-proposal rates


@dataclass(frozen=True)
class ENPResult:
    """Effective Number of Parties per proposal (FOR/AGAINST voters only)."""
    legacy: dict[str, float]   # proposal_id -> ENP
    signals: dict[str, float]


@dataclass(frozen=True)
class NakamotoResult:
    """Nakamoto coefficient per proposal (FOR/AGAINST voters only)."""
    legacy: dict[str, int]   # proposal_id -> min voters controlling > 50%
    signals: dict[str, int]


@dataclass(frozen=True)
class MarginShiftResult:
    """Per-proposal margin shift: signals_margin - legacy_margin."""
    per_proposal: dict[str, float]  # proposal_id -> signals_margin - legacy_margin
    aggregate_mean: float
    aggregate_std: float


@dataclass(frozen=True)
class TransitionMatrix:
    """
    Outcome transition matrix: how proposals move between Pass/Fail under
    the two voting regimes.

    Layout: counts[legacy_pass][signals_pass]
        counts[0][0] = FF (both fail)
        counts[0][1] = FP (legacy fail -> signals pass)
        counts[1][0] = PF (legacy pass -> signals fail)
        counts[1][1] = PP (both pass)
    """
    counts: tuple[tuple[int, int], tuple[int, int]]              # [[PP, PF], [FP, FF]]
    proportions: tuple[tuple[float, float], tuple[float, float]]


@dataclass(frozen=True)
class LateVoteShareResult:
    """Fraction of total voting weight cast in the final third of the voting window."""
    legacy: dict[str, float]   # proposal_id -> fraction in final third
    signals: dict[str, float]


@dataclass(frozen=True)
class LockinTimingResult:
    """
    Fraction of voting window elapsed at the point the outcome was locked in.

    NaN if outcome never locked in (all votes were required for the final result).
    """
    legacy: dict[str, float]   # proposal_id -> fraction elapsed at lock-in
    signals: dict[str, float]


@dataclass(frozen=True)
class TopKConcentrationResult:
    """Fraction of total voting weight held by top-k voters (k in [1, 5, 10])."""
    legacy: dict[int, dict[str, float]]   # k -> {proposal_id -> share}
    signals: dict[int, dict[str, float]]


# ---------------------------------------------------------------------------
# Public metric functions
# ---------------------------------------------------------------------------

K_VALUES = [1, 5, 10]


def compute_flip_rate(results_df: pd.DataFrame) -> FlipRateResult:
    """
    METR-01: Fraction of proposals whose pass/fail outcome differs between
    legacy and Signals regimes.

    A tie (FOR == AGAINST) is classified as Fail (strict greater-than).
    """
    final = _get_final_tallies(results_df)
    legacy_pass = final['legacy_for'] > final['legacy_against']
    signals_pass = final['signals_for'] > final['signals_against']
    flipped = legacy_pass != signals_pass
    per_proposal = dict(zip(final['proposal_id'], flipped.tolist()))
    aggregate = float(flipped.mean()) if len(flipped) > 0 else 0.0
    return FlipRateResult(per_proposal=per_proposal, aggregate=aggregate)


def compute_gini(results_df: pd.DataFrame, curve_type: str = 'sqrt') -> GiniResult:
    """
    METR-02: Gini coefficient of voting power for participating voters.

    Computed over per-voter weight (legacy: raw stake; Signals: commitment-
    weighted stake). Only voters who actually cast a vote are included.
    """
    vote_df = results_df[results_df['event_type'] == 'VOTE_CAST'].copy()
    vote_df = _add_signals_weight_column(vote_df, curve_type)
    legacy_gini = _gini(vote_df['weight'].values)
    signals_gini = _gini(vote_df['signals_w'].values)
    return GiniResult(legacy=legacy_gini, signals=signals_gini)


def compute_participation_rate(results_df: pd.DataFrame) -> ParticipationResult:
    """
    METR-03: Per-proposal voter participation rate.

    Participation = unique voters on proposal / total unique voters across all
    proposals. Aggregate = mean of per-proposal rates.
    """
    vote_df = results_df[results_df['event_type'] == 'VOTE_CAST']
    total_unique_voters = vote_df['voter'].nunique()
    if total_unique_voters == 0:
        return ParticipationResult(per_proposal={}, aggregate=0.0)
    voters_per_proposal = vote_df.groupby('proposal_id')['voter'].nunique()
    per_proposal = (voters_per_proposal / total_unique_voters).to_dict()
    aggregate = float(np.mean(list(per_proposal.values()))) if per_proposal else 0.0
    return ParticipationResult(per_proposal=per_proposal, aggregate=aggregate)


def compute_enp(results_df: pd.DataFrame, curve_type: str = 'sqrt') -> ENPResult:
    """
    METR-04: Effective Number of Parties per proposal.

    ENP = 1 / sum(s_i^2) where s_i is each voter's share of total weight.
    Computed on FOR/AGAINST voters only (ABSTAIN excluded — per analysis spec).
    """
    vote_df = results_df[results_df['event_type'] == 'VOTE_CAST']
    vote_df = vote_df[vote_df['support'].isin(['FOR', 'AGAINST'])]
    vote_df = _add_signals_weight_column(vote_df, curve_type)

    legacy: dict[str, float] = {}
    signals: dict[str, float] = {}
    for proposal_id, group in vote_df.groupby('proposal_id'):
        legacy[proposal_id] = _enp(group['weight'].values)
        signals[proposal_id] = _enp(group['signals_w'].values)
    return ENPResult(legacy=legacy, signals=signals)


def compute_nakamoto_coefficient(results_df: pd.DataFrame, curve_type: str = 'sqrt') -> NakamotoResult:
    """
    METR-05: Nakamoto coefficient per proposal.

    Minimum number of voters whose combined weight exceeds 50% of the total.
    Computed on FOR/AGAINST voters only (ABSTAIN excluded).
    Returns 0 if no votes were cast on a proposal.
    """
    vote_df = results_df[results_df['event_type'] == 'VOTE_CAST']
    vote_df = vote_df[vote_df['support'].isin(['FOR', 'AGAINST'])]
    vote_df = _add_signals_weight_column(vote_df, curve_type)

    legacy: dict[str, int] = {}
    signals: dict[str, int] = {}
    for proposal_id, group in vote_df.groupby('proposal_id'):
        legacy[proposal_id] = _nakamoto(group['weight'].values)
        signals[proposal_id] = _nakamoto(group['signals_w'].values)
    return NakamotoResult(legacy=legacy, signals=signals)


def compute_margin_shift(results_df: pd.DataFrame) -> MarginShiftResult:
    """
    METR-06: Per-proposal shift in victory margin between regimes.

    Margin = (for - against) / (for + against). Positive shift = Signals
    produces a more decisive result; negative shift = less decisive.
    NaN returned for proposals with no votes (zero denominator).
    """
    final = _get_final_tallies(results_df)

    def _margin(for_col: pd.Series, against_col: pd.Series) -> pd.Series:
        denom = for_col + against_col
        return np.where(denom == 0, np.nan, (for_col - against_col) / denom)

    legacy_margin = _margin(final['legacy_for'], final['legacy_against'])
    signals_margin = _margin(final['signals_for'], final['signals_against'])
    shift = signals_margin - legacy_margin

    per_proposal = dict(zip(final['proposal_id'].tolist(), shift.tolist()))
    values = list(per_proposal.values())
    aggregate_mean = float(np.nanmean(values)) if values else 0.0
    aggregate_std = float(np.nanstd(values)) if values else 0.0
    return MarginShiftResult(
        per_proposal=per_proposal,
        aggregate_mean=aggregate_mean,
        aggregate_std=aggregate_std,
    )


def compute_transition_matrix(results_df: pd.DataFrame) -> TransitionMatrix:
    """
    METR-07: Outcome transition matrix between legacy and Signals regimes.

    Layout (rows = legacy outcome, cols = signals outcome):
        counts = [[PP, PF], [FP, FF]]

    Tie (FOR == AGAINST) is classified as Fail (strict greater-than).
    """
    final = _get_final_tallies(results_df)
    legacy_pass = final['legacy_for'] > final['legacy_against']
    signals_pass = final['signals_for'] > final['signals_against']

    pp = int((legacy_pass & signals_pass).sum())
    pf = int((legacy_pass & ~signals_pass).sum())
    fp = int((~legacy_pass & signals_pass).sum())
    ff = int((~legacy_pass & ~signals_pass).sum())
    total = pp + pf + fp + ff

    counts = ((pp, pf), (fp, ff))
    if total == 0:
        proportions = ((0.0, 0.0), (0.0, 0.0))
    else:
        proportions = (
            (pp / total, pf / total),
            (fp / total, ff / total),
        )
    return TransitionMatrix(counts=counts, proportions=proportions)


def compute_late_vote_share(
    results_df: pd.DataFrame,
    windows_df: pd.DataFrame,
    curve_type: str = 'sqrt',
) -> LateVoteShareResult:
    """
    METR-08: Fraction of total voting weight cast in the final third of the
    voting window, per proposal.

    Late = block_number >= start_block + (end_block - start_block) * (2/3).
    Weight-based (not voter-count-based) — sum of weight/signals_w in late
    period divided by total weight for that proposal.
    """
    vote_df = results_df[results_df['event_type'] == 'VOTE_CAST'].copy()
    vote_df = _add_signals_weight_column(vote_df, curve_type)
    vote_df = _merge_windows(vote_df, windows_df)

    vote_df['late_threshold'] = (
        vote_df['start_block'] + (vote_df['end_block'] - vote_df['start_block']) * (2.0 / 3.0)
    )
    vote_df['is_late'] = vote_df['block_number'] >= vote_df['late_threshold']

    legacy: dict[str, float] = {}
    signals: dict[str, float] = {}
    for proposal_id, group in vote_df.groupby('proposal_id'):
        total_l = group['weight'].sum()
        total_s = group['signals_w'].sum()
        late_l = group.loc[group['is_late'], 'weight'].sum()
        late_s = group.loc[group['is_late'], 'signals_w'].sum()
        legacy[proposal_id] = float(late_l / total_l) if total_l > 0 else float('nan')
        signals[proposal_id] = float(late_s / total_s) if total_s > 0 else float('nan')

    return LateVoteShareResult(legacy=legacy, signals=signals)


def compute_lockin_timing(
    results_df: pd.DataFrame,
    windows_df: pd.DataFrame,
    curve_type: str = 'sqrt',
) -> LockinTimingResult:
    """
    METR-09: Fraction of voting window elapsed when outcome was mathematically
    locked in (remaining votes cannot change the result).

    0.0 = locked at start of window; 1.0 = locked at end or never locked.
    NaN if the proposal had no votes.
    """
    vote_df = results_df[results_df['event_type'] == 'VOTE_CAST'].copy()
    vote_df = _add_signals_weight_column(vote_df, curve_type)
    vote_df = _merge_windows(vote_df, windows_df)

    legacy: dict[str, float] = {}
    signals: dict[str, float] = {}
    for proposal_id, group in vote_df.groupby('proposal_id'):
        legacy[proposal_id] = _compute_lockin_fraction(group, 'legacy')
        signals[proposal_id] = _compute_lockin_fraction(group, 'signals')

    return LockinTimingResult(legacy=legacy, signals=signals)


def compute_top_k_concentration(results_df: pd.DataFrame, curve_type: str = 'sqrt') -> TopKConcentrationResult:
    """
    METR-10: Top-k voting power concentration per proposal.

    For k in [1, 5, 10]: fraction of total voting weight held by the k
    highest-weight voters on each proposal (FOR/AGAINST voters only).
    If k >= num_voters, returns 1.0 (all voting power captured).
    """
    vote_df = results_df[results_df['event_type'] == 'VOTE_CAST']
    vote_df = vote_df[vote_df['support'].isin(['FOR', 'AGAINST'])]
    vote_df = _add_signals_weight_column(vote_df, curve_type)

    legacy: dict[int, dict[str, float]] = {k: {} for k in K_VALUES}
    signals: dict[int, dict[str, float]] = {k: {} for k in K_VALUES}

    for proposal_id, group in vote_df.groupby('proposal_id'):
        leg_weights = np.sort(group['weight'].values)[::-1]
        sig_weights = np.sort(group['signals_w'].values)[::-1]
        total_l = leg_weights.sum()
        total_s = sig_weights.sum()
        for k in K_VALUES:
            if total_l == 0:
                legacy[k][proposal_id] = float('nan')
            elif k >= len(leg_weights):
                legacy[k][proposal_id] = 1.0
            else:
                legacy[k][proposal_id] = float(leg_weights[:k].sum() / total_l)

            if total_s == 0:
                signals[k][proposal_id] = float('nan')
            elif k >= len(sig_weights):
                signals[k][proposal_id] = 1.0
            else:
                signals[k][proposal_id] = float(sig_weights[:k].sum() / total_s)

    return TopKConcentrationResult(legacy=legacy, signals=signals)
