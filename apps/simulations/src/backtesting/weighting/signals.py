"""
Pure weighting functions for Signals Protocol and legacy voting.

All functions in this module are PURE — no side effects, no state, no cadCAD
import, no pandas. Input: numeric scalars. Output: numeric scalars.

This isolation enables independent unit testing of the core scientific claim:
    W_signals = stake * f(lock_duration)

where f(L) is the lock curve returning a multiplier in [floor, 1.0].
"""

import numpy as np
from typing import Literal

CurveType = Literal['sqrt', 'linear', 'log', 'exp']


def lock_curve(
    lock_duration_days: float,
    curve_type: CurveType = 'sqrt',
    l_max_days: float = 365.0,
    floor: float = 0.1,
) -> float:
    """
    Compute f(L) — the lock duration multiplier in [floor, 1.0].

    Default curve shape is square root (per user decision). All curve types
    are normalized so f(0) = floor and f(l_max) = 1.0.

    Curve shapes:
        - sqrt:   f(L) = floor + (1 - floor) * sqrt(L / L_max)  [diminishing returns]
        - linear: f(L) = floor + (1 - floor) * (L / L_max)      [proportional]
        - log:    f(L) = floor + (1 - floor) * log1p(L) / log1p(L_max)  [fast early gains]
        - exp:    f(L) = floor + (1 - floor) * (1 - exp(-alpha*L)) / (1 - exp(-alpha*L_max))

    Args:
        lock_duration_days: Lock duration in days. 0 or negative = no lock.
        curve_type: Shape of the curve ('sqrt', 'linear', 'log', 'exp').
        l_max_days: Maximum lock duration in days (normalization denominator).
                    Default 365 days (12 months).
        floor: Minimum multiplier at L=0. Default 0.1.
               Uncommitted voters still get minimal weight, not silenced.

    Returns:
        Multiplier in [floor, 1.0].

    Examples:
        >>> lock_curve(0)            # no lock — returns floor
        0.1
        >>> lock_curve(365)          # max lock — returns 1.0
        1.0
        >>> lock_curve(90, 'linear') # 3 months linear
        0.32191780821917804
    """
    if lock_duration_days <= 0:
        return floor

    L = min(lock_duration_days, l_max_days)  # cap at l_max

    if curve_type == 'sqrt':
        raw = np.sqrt(L / l_max_days)
    elif curve_type == 'linear':
        raw = L / l_max_days
    elif curve_type == 'log':
        raw = np.log1p(L) / np.log1p(l_max_days)
    elif curve_type == 'exp':
        # alpha = 0.5 per month (0.5/30 per day) — ~78% weight at 3 months
        alpha_per_day = 0.5 / 30.0
        raw = 1.0 - np.exp(-alpha_per_day * L)
        raw = raw / (1.0 - np.exp(-alpha_per_day * l_max_days))  # normalize to 1.0 at L_max
    else:
        raise ValueError(f'Unknown curve_type: {curve_type!r}. Must be one of: sqrt, linear, log, exp')

    return float(floor + (1.0 - floor) * raw)


def compute_signals_weight(
    stake: float,
    lock_duration_days: float,
    curve_type: CurveType = 'sqrt',
    l_max_days: float = 365.0,
    floor: float = 0.1,
) -> float:
    """
    Compute Signals Protocol voting weight.

    W_signals = stake * f(lock_duration)

    The Signals weight is always <= raw stake (since f(L) in [floor, 1.0]
    and floor <= 1.0). Commitment-weighted voting rewards long-term holders
    by amplifying their effective weight relative to uncommitted voters.

    Args:
        stake: Raw token stake at time of vote (must be non-negative).
        lock_duration_days: Lock duration in days.
        curve_type: Lock curve shape ('sqrt', 'linear', 'log', 'exp').
        l_max_days: Maximum lock duration for normalization.
        floor: Minimum multiplier for uncommitted voters.

    Returns:
        Signals voting weight = stake * lock_curve(lock_duration_days, ...).

    Examples:
        >>> compute_signals_weight(1000, 0)   # no lock — floor weight
        100.0
        >>> compute_signals_weight(1000, 365) # max lock — full weight
        1000.0
    """
    return stake * lock_curve(lock_duration_days, curve_type, l_max_days, floor)


def compute_legacy_weight(stake: float) -> float:
    """
    Compute legacy (plain token-weighted) voting weight.

    W_legacy = stake

    Identity function — no lock duration adjustment. Used as baseline
    comparison for the Signals Protocol backtesting analysis.

    Args:
        stake: Raw token stake at time of vote.

    Returns:
        stake as a float (no transformation).

    Examples:
        >>> compute_legacy_weight(1000)
        1000.0
        >>> compute_legacy_weight(0)
        0.0
    """
    return float(stake)
