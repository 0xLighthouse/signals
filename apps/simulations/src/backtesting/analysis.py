"""
Extended analysis functions operating on results DataFrames from the sweep engine.

All functions are pure functions accepting results_df (pd.DataFrame) from
build_results_dataframe. No simulation framework imports. No side effects.
All functions return frozen dataclasses.

NaN-for-degenerate-inputs convention: helper functions return np.nan (not 0.0)
when given zero-sum, zero-weight, or zero-denominator inputs. NaN propagates
silently through downstream aggregation (np.nanmean, etc.). This is the
documented convention for all analysis functions, consistent with metrics.py.

This module is independent of metrics.py — it does not import from it.
"""
from __future__ import annotations

from dataclasses import dataclass

import numpy as np
import pandas as pd
from scipy.stats import bootstrap as _bootstrap
from scipy.stats import mannwhitneyu as _mannwhitneyu

from backtesting.weighting.signals import compute_signals_weight as _compute_signals_weight

__all__ = [
    'MarginClassBreakdown',
    'VoterArchetypes',
    'AddressInfluence',
    'TimingSensitivity',
    'SignificanceResult',
    'BootstrapCI',
    'margin_class_breakdown',
    'voter_archetypes',
    'address_influence',
    'timing_sensitivity',
    'influence_significance',
    'bootstrap_ci',
]


# ---------------------------------------------------------------------------
# Result dataclasses (all frozen)
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class MarginClassBreakdown:
    """
    Count of flipped proposals grouped by legacy victory margin class.

    A proposal is 'flipped' when its pass/fail outcome differs between
    legacy and Signals regimes (tie = fail, strict greater-than = pass).

    Margin classes are computed on the legacy regime:
        tight:    |legacy_margin| < 10%   (margin in [0.0, 0.10))
        moderate: |legacy_margin| in [10%, 30%)
        decisive: |legacy_margin| >= 30%
    """
    tight: int
    moderate: int
    decisive: int
    total_flips: int


@dataclass(frozen=True)
class VoterArchetypes:
    """
    Voter classification by total stake (sum of weight across all proposals).

    Archetypes are assigned by tertile (pd.qcut with q=3):
        retail: bottom third by total stake
        medium: middle third
        whale:  top third

    Edge case: if fewer than 3 unique voters, all are classified as 'retail'.
    """
    labels: pd.DataFrame  # columns: ['voter', 'weight', 'archetype']
    counts: dict[str, int]  # count per archetype label


# ---------------------------------------------------------------------------
# Private helpers (inline — keeps analysis.py independent of metrics.py)
# ---------------------------------------------------------------------------


def _get_final_tallies(results_df: pd.DataFrame) -> pd.DataFrame:
    """Return last VOTE_CAST row per proposal (cumulative tally at proposal end).

    Replicates the same logic as metrics._get_final_tallies but kept inline
    to maintain module independence.
    """
    vote_df = results_df[results_df['event_type'] == 'VOTE_CAST']
    return (
        vote_df.groupby('proposal_id').last()
        [['legacy_for', 'legacy_against', 'signals_for', 'signals_against']]
        .reset_index()
    )


# ---------------------------------------------------------------------------
# Public analysis functions
# ---------------------------------------------------------------------------


def margin_class_breakdown(results_df: pd.DataFrame) -> MarginClassBreakdown:
    """
    ANAL-01: Count flipped proposals grouped by legacy victory margin class.

    Determines which proposals flipped (legacy_pass != signals_pass) and
    bins them by the absolute legacy margin into tight/moderate/decisive.

    A tie (FOR == AGAINST) is classified as Fail (strict greater-than).
    Zero-denominator proposals are assigned NaN margin and excluded from bins.

    Args:
        results_df: Results DataFrame from build_results_dataframe.

    Returns:
        MarginClassBreakdown with flip counts per margin class.
    """
    final = _get_final_tallies(results_df)

    if final.empty:
        return MarginClassBreakdown(tight=0, moderate=0, decisive=0, total_flips=0)

    legacy_pass = final['legacy_for'] > final['legacy_against']
    signals_pass = final['signals_for'] > final['signals_against']
    flipped_mask = legacy_pass != signals_pass

    total_flips = int(flipped_mask.sum())

    if total_flips == 0:
        return MarginClassBreakdown(tight=0, moderate=0, decisive=0, total_flips=0)

    # Compute legacy margin for flipped proposals only
    flipped = final[flipped_mask].copy()
    denom = flipped['legacy_for'] + flipped['legacy_against']
    margin_abs = np.where(
        denom == 0,
        np.nan,
        np.abs((flipped['legacy_for'] - flipped['legacy_against']) / denom),
    )

    # Bin into margin classes
    margin_series = pd.Series(margin_abs)
    bins = pd.cut(
        margin_series,
        bins=[0.0, 0.10, 0.30, 1.01],
        labels=['tight', 'moderate', 'decisive'],
        include_lowest=True,
    )
    counts = bins.value_counts()

    return MarginClassBreakdown(
        tight=int(counts.get('tight', 0)),
        moderate=int(counts.get('moderate', 0)),
        decisive=int(counts.get('decisive', 0)),
        total_flips=total_flips,
    )


def voter_archetypes(results_df: pd.DataFrame) -> VoterArchetypes:
    """
    ANAL-04: Classify voters into retail/medium/whale archetypes by total stake.

    Total stake per voter = sum of 'weight' across all VOTE_CAST events.
    Archetypes are assigned by tertile using pd.qcut(q=3). If duplicate bin
    edges arise (common with Pareto-distributed stakes), falls back to assigning
    all voters to a single category.

    Edge case: fewer than 3 unique voters -> all classified as 'retail'.

    Args:
        results_df: Results DataFrame from build_results_dataframe.

    Returns:
        VoterArchetypes with per-voter labels DataFrame and archetype counts.
    """
    vote_df = results_df[results_df['event_type'] == 'VOTE_CAST']

    if vote_df.empty:
        labels_df = pd.DataFrame(columns=['voter', 'weight', 'archetype'])
        return VoterArchetypes(labels=labels_df, counts={})

    # Per-voter total stake (sum of weight across all proposals they voted on)
    stakes = vote_df.groupby('voter')['weight'].sum().reset_index()
    stakes.columns = ['voter', 'weight']

    n_voters = len(stakes)

    if n_voters < 3:
        # Edge case: too few voters for meaningful tertile split
        stakes['archetype'] = pd.Categorical(
            ['retail'] * n_voters, categories=['retail', 'medium', 'whale']
        )
    else:
        try:
            stakes['archetype'] = pd.qcut(
                stakes['weight'],
                q=3,
                labels=['retail', 'medium', 'whale'],
                duplicates='drop',
            )
        except ValueError:
            # Fallback: all voters in same category when qcut fails completely
            stakes['archetype'] = pd.Categorical(
                ['retail'] * n_voters, categories=['retail', 'medium', 'whale']
            )

    labels_df = stakes[['voter', 'weight', 'archetype']].copy()
    counts = dict(labels_df['archetype'].value_counts())

    return VoterArchetypes(labels=labels_df, counts=counts)


# ---------------------------------------------------------------------------
# Additional frozen dataclasses for ANAL-02, ANAL-03, ANAL-05, ANAL-06
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class AddressInfluence:
    """
    Per-voter influence breakdown using median-lock counterfactual.

    Fields:
        per_voter: DataFrame with columns ['voter', 'legacy_share',
            'signals_share', 'counterfactual_share', 'delta']
        median_lock_days: median lock duration used as the counterfactual
            baseline (all voters set to this lock duration to isolate the
            commitment signal)
    """
    per_voter: pd.DataFrame  # columns: ['voter', 'legacy_share', 'signals_share', 'counterfactual_share', 'delta']
    median_lock_days: float


@dataclass(frozen=True)
class TimingSensitivity:
    """
    2D pivot table of weight_ratio (signals_w / legacy_w) indexed by timing
    quantile and lock quantile.

    Fields:
        heatmap: 2D DataFrame with timing quantile as index (rows) and lock
            quantile as columns
        n_quantiles: number of quantile bins used when building the pivot
    """
    heatmap: pd.DataFrame  # 2D pivot: index=timing_q, columns=lock_q
    n_quantiles: int


@dataclass(frozen=True)
class SignificanceResult:
    """
    Result of a Mann-Whitney U significance test.

    Fields:
        statistic: Mann-Whitney U test statistic
        p_value: two-sided p-value
    """
    statistic: float
    p_value: float


@dataclass(frozen=True)
class BootstrapCI:
    """
    Bootstrap confidence interval for an aggregate statistic.

    Fields:
        low: lower bound of the confidence interval
        high: upper bound of the confidence interval
        confidence_level: the confidence level used (e.g. 0.95)
    """
    low: float
    high: float
    confidence_level: float


# ---------------------------------------------------------------------------
# Public analysis functions — ANAL-02, ANAL-03, ANAL-05, ANAL-06
# ---------------------------------------------------------------------------


def address_influence(
    results_df: pd.DataFrame,
    curve_type: str = 'sqrt',
) -> AddressInfluence:
    """
    ANAL-02: Compute per-voter influence share under legacy, signals, and a
    median-lock counterfactual baseline.

    The counterfactual baseline assigns every voter the median lock duration
    observed in the dataset, then recomputes signals weights. This isolates
    the commitment signal: delta = signals_share - counterfactual_share measures
    how much a voter's actual lock duration moves their share relative to the
    typical (median) commitment level, rather than comparing to the absence of
    commitment entirely. Using the median-lock counterfactual is the correct
    approach because it:
      1. Holds participation constant (same voters, same stakes).
      2. Varies only the lock duration dimension of the signals weight formula.
      3. Produces a within-protocol comparison (not legacy vs. signals) that
         reveals who benefits or loses from their actual lock commitment.

    Args:
        results_df: Results DataFrame from build_results_dataframe.
        curve_type: Lock duration curve type ('sqrt', 'linear', etc.).

    Returns:
        AddressInfluence with per_voter DataFrame and median_lock_days used.
    """
    vote_df = results_df[results_df['event_type'] == 'VOTE_CAST'].copy()

    if vote_df.empty:
        per_voter = pd.DataFrame(
            columns=['voter', 'legacy_share', 'signals_share', 'counterfactual_share', 'delta']
        )
        return AddressInfluence(per_voter=per_voter, median_lock_days=float('nan'))

    median_lock = float(vote_df['lock_duration_days'].fillna(0.0).median())

    # Compute signals weight using actual lock durations
    vote_df['signals_w'] = np.vectorize(_compute_signals_weight)(
        vote_df['weight'].values,
        vote_df['lock_duration_days'].fillna(0.0).values,
        curve_type,
    )

    # Compute counterfactual weight: everyone at median lock
    vote_df['counterfactual_w'] = np.vectorize(_compute_signals_weight)(
        vote_df['weight'].values,
        median_lock,
        curve_type,
    )

    # Group by voter, sum up weights
    grouped = vote_df.groupby('voter').agg(
        legacy_w_sum=('weight', 'sum'),
        signals_w_sum=('signals_w', 'sum'),
        counterfactual_w_sum=('counterfactual_w', 'sum'),
    ).reset_index()

    total_legacy = grouped['legacy_w_sum'].sum()
    total_signals = grouped['signals_w_sum'].sum()
    total_counterfactual = grouped['counterfactual_w_sum'].sum()

    grouped['legacy_share'] = np.where(
        total_legacy == 0, np.nan, grouped['legacy_w_sum'] / total_legacy
    )
    grouped['signals_share'] = np.where(
        total_signals == 0, np.nan, grouped['signals_w_sum'] / total_signals
    )
    grouped['counterfactual_share'] = np.where(
        total_counterfactual == 0, np.nan, grouped['counterfactual_w_sum'] / total_counterfactual
    )
    grouped['delta'] = grouped['signals_share'] - grouped['counterfactual_share']

    per_voter = grouped[
        ['voter', 'legacy_share', 'signals_share', 'counterfactual_share', 'delta']
    ].copy()

    return AddressInfluence(per_voter=per_voter, median_lock_days=median_lock)


def timing_sensitivity(
    results_df: pd.DataFrame,
    windows_df: pd.DataFrame,
    curve_type: str = 'sqrt',
    n_quantiles: int = 4,
) -> TimingSensitivity:
    """
    ANAL-03: Compute 2D heatmap of signals/legacy weight ratio by timing and
    lock duration quantile.

    Timing fraction measures where within a proposal window each vote was cast
    (0 = start, 1 = end). Lock quantile captures the voter's commitment level.
    The resulting pivot table shows how the signals amplification (weight_ratio)
    varies across timing x lock combinations.

    Args:
        results_df: Results DataFrame from build_results_dataframe.
        windows_df: DataFrame with proposal_id, start_block, end_block columns.
        curve_type: Lock duration curve type ('sqrt', 'linear', etc.).
        n_quantiles: Number of quantile bins for timing and lock dimensions.

    Returns:
        TimingSensitivity with 2D pivot heatmap and n_quantiles used.
    """
    vote_df = results_df[results_df['event_type'] == 'VOTE_CAST'].copy()

    if vote_df.empty:
        heatmap = pd.DataFrame()
        return TimingSensitivity(heatmap=heatmap, n_quantiles=n_quantiles)

    # Merge start_block/end_block from windows_df
    vote_df = vote_df.merge(
        windows_df[['proposal_id', 'start_block', 'end_block']],
        on='proposal_id',
        how='left',
    )

    # Compute timing fraction within proposal window
    window_size = vote_df['end_block'] - vote_df['start_block']
    vote_df['timing_frac'] = np.where(
        window_size == 0,
        0.0,
        (vote_df['block_number'] - vote_df['start_block']) / window_size,
    )

    # Compute signals weight
    vote_df['signals_w'] = np.vectorize(_compute_signals_weight)(
        vote_df['weight'].values,
        vote_df['lock_duration_days'].fillna(0.0).values,
        curve_type,
    )

    # Weight ratio: signals amplification relative to legacy
    vote_df['weight_ratio'] = np.where(
        vote_df['weight'] == 0,
        np.nan,
        vote_df['signals_w'] / vote_df['weight'],
    )

    # Quantile bins for timing
    timing_labels = [f'T{i + 1}' for i in range(n_quantiles)]
    vote_df['timing_q'] = pd.qcut(
        vote_df['timing_frac'],
        q=n_quantiles,
        labels=timing_labels,
        duplicates='drop',
    )

    # Quantile bins for lock duration
    lock_labels = [f'L{i + 1}' for i in range(n_quantiles)]
    vote_df['lock_q'] = pd.qcut(
        vote_df['lock_duration_days'].fillna(0.0),
        q=n_quantiles,
        labels=lock_labels,
        duplicates='drop',
    )

    # 2D pivot table: rows = timing quantile, columns = lock quantile
    heatmap = vote_df.pivot_table(
        values='weight_ratio',
        index='timing_q',
        columns='lock_q',
        aggfunc='mean',
        observed=True,
    )

    return TimingSensitivity(heatmap=heatmap, n_quantiles=n_quantiles)


def influence_significance(
    group_a: np.ndarray,
    group_b: np.ndarray,
) -> SignificanceResult:
    """
    ANAL-05: Run a two-sided Mann-Whitney U test on two influence distributions.

    Used to assess whether two groups (e.g., early vs. late voters) have
    statistically different influence share distributions.

    Args:
        group_a: First array of influence values.
        group_b: Second array of influence values.

    Returns:
        SignificanceResult with U statistic and two-sided p-value. If either
        group has fewer than 2 non-NaN values, returns NaN for both fields.
    """
    a = group_a[~np.isnan(group_a)] if len(group_a) > 0 else group_a
    b = group_b[~np.isnan(group_b)] if len(group_b) > 0 else group_b

    if len(a) < 2 or len(b) < 2:
        return SignificanceResult(statistic=float('nan'), p_value=float('nan'))

    stat, pval = _mannwhitneyu(a, b, alternative='two-sided')
    return SignificanceResult(statistic=float(stat), p_value=float(pval))


def bootstrap_ci(
    values: np.ndarray,
    statistic=np.mean,
    confidence_level: float = 0.95,
    n_resamples: int = 999,
    random_state: int = 42,
) -> BootstrapCI:
    """
    ANAL-06: Compute a bootstrap confidence interval for an aggregate statistic.

    Uses scipy.stats.bootstrap with the percentile method. Suitable for
    computing confidence intervals on sweep-level metrics (e.g., mean flip
    rate, mean margin shift) across multiple simulation runs.

    Args:
        values: 1D array of values to bootstrap.
        statistic: Aggregate function (default np.mean).
        confidence_level: Confidence level (default 0.95).
        n_resamples: Number of bootstrap resamples (default 999).
        random_state: Random seed for reproducibility (default 42).

    Returns:
        BootstrapCI with low, high bounds and confidence_level. If fewer than
        2 non-NaN values are present, low and high are NaN.
    """
    clean = values[~np.isnan(values)] if len(values) > 0 else values

    if len(clean) < 2:
        return BootstrapCI(low=float('nan'), high=float('nan'), confidence_level=confidence_level)

    res = _bootstrap(
        (clean,),
        statistic,
        confidence_level=confidence_level,
        n_resamples=n_resamples,
        random_state=random_state,
        method='percentile',
    )
    return BootstrapCI(
        low=float(res.confidence_interval.low),
        high=float(res.confidence_interval.high),
        confidence_level=confidence_level,
    )
