"""
backtesting.weighting — Pure weighting functions for Signals and legacy voting.
"""

from backtesting.weighting.signals import (
    CurveType,
    lock_curve,
    compute_signals_weight,
    compute_legacy_weight,
)

__all__ = [
    'CurveType',
    'lock_curve',
    'compute_signals_weight',
    'compute_legacy_weight',
]
