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

__all__ = [
    'MarginClassBreakdown',
    'VoterArchetypes',
    'margin_class_breakdown',
    'voter_archetypes',
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
