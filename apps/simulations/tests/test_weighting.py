"""
Tests for backtesting.weighting.signals — lock curve, Signals weight, legacy weight.

Covers: WGHT-01 (no cadCAD import), WGHT-02 (all 4 curve types, correct range),
WGHT-03 (sqrt diminishing returns), WGHT-04 (legacy weight identity).
"""

import inspect
import math

import pytest

import backtesting.weighting.signals as signals_module
from backtesting.weighting.signals import (
    compute_legacy_weight,
    compute_signals_weight,
    lock_curve,
)


class TestNoCadCADImport:
    """WGHT-01: Signals weight function is independent of cadCAD."""

    def test_no_cadcad_import(self):
        """signals.py source must not contain a cadCAD import statement."""
        source = inspect.getsource(signals_module)
        # Check for actual import statements (not docstring mentions)
        import_lines = [
            line.strip() for line in source.splitlines()
            if line.strip().startswith('import') or line.strip().startswith('from')
        ]
        for line in import_lines:
            assert 'cadcad' not in line.lower(), (
                f'backtesting/weighting/signals.py must not import cadCAD, found: {line}'
            )

    def test_no_pandas_import(self):
        """signals.py is a pure function module — no pandas allowed."""
        source = inspect.getsource(signals_module)
        assert 'import pandas' not in source, (
            'signals.py must not import pandas — pure functions only'
        )


class TestAllCurveTypes:
    """WGHT-02: All four curve types implemented and return values in [floor, 1.0]."""

    @pytest.mark.parametrize('curve_type', ['sqrt', 'linear', 'log', 'exp'])
    def test_floor_at_zero(self, curve_type):
        """lock_curve(0) returns floor (0.1) for all curve types."""
        result = lock_curve(0, curve_type=curve_type)
        assert abs(result - 0.1) < 1e-9, (
            f'{curve_type}: expected floor 0.1 at L=0, got {result}'
        )

    @pytest.mark.parametrize('curve_type', ['sqrt', 'linear', 'log', 'exp'])
    def test_cap_at_lmax(self, curve_type):
        """lock_curve(365) returns 1.0 for all curve types (default l_max=365)."""
        result = lock_curve(365.0, curve_type=curve_type)
        assert abs(result - 1.0) < 1e-6, (
            f'{curve_type}: expected cap 1.0 at L=L_max, got {result}'
        )

    @pytest.mark.parametrize('curve_type', ['sqrt', 'linear', 'log', 'exp'])
    def test_midpoint_in_range(self, curve_type):
        """lock_curve(180) is strictly between floor and 1.0 for all curve types."""
        result = lock_curve(180, curve_type=curve_type)
        assert 0.1 < result < 1.0, (
            f'{curve_type}: expected midpoint in (0.1, 1.0), got {result}'
        )

    @pytest.mark.parametrize('curve_type', ['sqrt', 'linear', 'log', 'exp'])
    def test_monotonically_increasing(self, curve_type):
        """All curve types are monotonically increasing with lock duration."""
        prev = lock_curve(0, curve_type=curve_type)
        for days in [30, 90, 180, 270, 365]:
            curr = lock_curve(days, curve_type=curve_type)
            assert curr >= prev, (
                f'{curve_type}: not monotonically increasing at {days}d: {curr} < {prev}'
            )
            prev = curr


class TestFloorAtZero:
    """lock_curve floor behavior at L=0 and negative values."""

    def test_floor_at_exactly_zero(self):
        """lock_curve(0) == 0.1 for default floor."""
        assert lock_curve(0) == 0.1

    def test_floor_at_negative(self):
        """lock_curve(-5) == 0.1 — negative duration treated as no lock."""
        assert lock_curve(-5) == 0.1

    def test_floor_at_zero_all_curves(self):
        """Explicit check: all curve types return floor at L=0."""
        for curve_type in ['sqrt', 'linear', 'log', 'exp']:
            assert lock_curve(0, curve_type=curve_type) == 0.1


class TestCapAtLmax:
    """lock_curve cap behavior at L >= l_max_days."""

    def test_cap_at_lmax_default(self):
        """lock_curve(365) == 1.0 with default l_max_days=365."""
        for curve_type in ['sqrt', 'linear', 'log', 'exp']:
            result = lock_curve(365, curve_type=curve_type)
            assert abs(result - 1.0) < 1e-6, f'{curve_type}: cap failed at L_max'

    def test_cap_beyond_lmax(self):
        """lock_curve(500) == lock_curve(365) — values beyond L_max are capped."""
        for curve_type in ['sqrt', 'linear', 'log', 'exp']:
            at_lmax = lock_curve(365, curve_type=curve_type, l_max_days=365)
            beyond = lock_curve(500, curve_type=curve_type, l_max_days=365)
            assert abs(at_lmax - beyond) < 1e-9, (
                f'{curve_type}: beyond L_max not capped: {at_lmax} vs {beyond}'
            )


class TestDiminishingReturns:
    """WGHT-03: sqrt curve exhibits diminishing returns."""

    def test_diminishing_returns_sqrt(self):
        """
        For sqrt curve, sequential 30-day deltas decrease over time.

        Computes increments at 30-day intervals (0→30, 30→60, 60→90, 90→120)
        and verifies each subsequent 30-day gain is smaller than the previous.
        """
        v0 = lock_curve(0, 'sqrt')
        v30 = lock_curve(30, 'sqrt')
        v60 = lock_curve(60, 'sqrt')
        v90 = lock_curve(90, 'sqrt')
        v120 = lock_curve(120, 'sqrt')

        d1 = v30 - v0    # 0→30 day increment
        d2 = v60 - v30   # 30→60 day increment
        d3 = v90 - v60   # 60→90 day increment
        d4 = v120 - v90  # 90→120 day increment

        assert d1 > d2, f'Delta 0→30 ({d1:.4f}) not > delta 30→60 ({d2:.4f})'
        assert d2 > d3, f'Delta 30→60 ({d2:.4f}) not > delta 60→90 ({d3:.4f})'
        assert d3 > d4, f'Delta 60→90 ({d3:.4f}) not > delta 90→120 ({d4:.4f})'

    def test_diminishing_returns_research_values(self):
        """
        Verify against research-documented values (from RESEARCH.md verification).

        Expected: sqrt deltas at 30-day intervals are approximately:
            d(0→30) ≈ 0.107, d(30→60) ≈ 0.107, d(60→90) ≈ 0.082 — but key is decreasing.
        The exact values from RESEARCH.md: 0.107, 0.082, 0.069 — confirmed decreasing.
        """
        v30 = lock_curve(30, 'sqrt')
        v60 = lock_curve(60, 'sqrt')
        v90 = lock_curve(90, 'sqrt')

        # Absolute values must be in expected range (from RESEARCH.md)
        assert 0.30 < v30 < 0.42, f'v30 out of expected range: {v30}'
        assert 0.43 < v60 < 0.55, f'v60 out of expected range: {v60}'
        assert 0.50 < v90 < 0.62, f'v90 out of expected range: {v90}'

    def test_sqrt_concavity(self):
        """Second derivative of sqrt is negative — confirming concavity (diminishing returns)."""
        # f(L) = floor + (1-floor)*sqrt(L/L_max)
        # f''(L) = (1-floor) * (-1/4) * L_max^(1/2) * L^(-3/2) < 0 for L > 0
        # Verify numerically: f(60) - f(30) > f(90) - f(60)
        d1 = lock_curve(60, 'sqrt') - lock_curve(30, 'sqrt')
        d2 = lock_curve(90, 'sqrt') - lock_curve(60, 'sqrt')
        assert d1 > d2, 'sqrt curve must be concave (diminishing returns)'


class TestSignalsWeightFormula:
    """WGHT-01: compute_signals_weight = stake * lock_curve."""

    def test_signals_weight_formula(self):
        """compute_signals_weight(stake, L) == stake * lock_curve(L)."""
        stake = 1000.0
        days = 90.0
        expected = stake * lock_curve(days)
        result = compute_signals_weight(stake, days)
        assert abs(result - expected) < 1e-9

    def test_signals_weight_formula_all_curves(self):
        """Formula holds for all four curve types."""
        stake = 5000.0
        days = 180.0
        for curve_type in ['sqrt', 'linear', 'log', 'exp']:
            expected = stake * lock_curve(days, curve_type=curve_type)
            result = compute_signals_weight(stake, days, curve_type=curve_type)
            assert abs(result - expected) < 1e-9, (
                f'{curve_type}: signals weight formula mismatch'
            )

    def test_signals_weight_multiple_values(self):
        """Spot-check compute_signals_weight at known values."""
        # At L=0: weight = stake * floor = stake * 0.1
        assert abs(compute_signals_weight(1000, 0) - 100.0) < 1e-9

        # At L=365: weight = stake * 1.0 = stake
        assert abs(compute_signals_weight(1000, 365) - 1000.0) < 1e-6


class TestSignalsWeightLeqStake:
    """Signals weight must always be <= raw stake."""

    @pytest.mark.parametrize('days', [0, 1, 30, 90, 180, 365, 500])
    def test_signals_weight_leq_stake(self, days):
        """compute_signals_weight(stake, L) <= stake for all lock durations."""
        stake = 1000.0
        weight = compute_signals_weight(stake, days)
        assert weight <= stake + 1e-9, (
            f'Signals weight {weight} > stake {stake} at L={days}'
        )

    def test_signals_weight_geq_floor_times_stake(self):
        """Signals weight is always >= stake * floor."""
        stake = 1000.0
        floor = 0.1
        for days in [0, 30, 90, 180, 365]:
            weight = compute_signals_weight(stake, days, floor=floor)
            assert weight >= stake * floor - 1e-9, (
                f'Signals weight {weight} < stake*floor at L={days}'
            )


class TestLegacyWeightIdentity:
    """WGHT-04: compute_legacy_weight returns stake unchanged."""

    @pytest.mark.parametrize('stake', [0, 1, 100, 1_000_000, 0.001])
    def test_legacy_weight_identity(self, stake):
        """compute_legacy_weight(stake) == stake for any non-negative value."""
        result = compute_legacy_weight(stake)
        assert result == float(stake), (
            f'Legacy weight {result} != stake {stake}'
        )

    def test_legacy_weight_returns_float(self):
        """compute_legacy_weight always returns a float."""
        assert isinstance(compute_legacy_weight(1000), float)
        assert isinstance(compute_legacy_weight(0), float)

    def test_legacy_weight_no_lock_dependency(self):
        """Legacy weight does not depend on any lock duration."""
        stake = 5000.0
        # Same result regardless of any lock duration (no lock param)
        result = compute_legacy_weight(stake)
        assert result == 5000.0


class TestCustomFloor:
    """Custom floor parameter behavior."""

    def test_custom_floor_at_zero(self):
        """lock_curve(0, floor=0.2) returns 0.2."""
        result = lock_curve(0, floor=0.2)
        assert abs(result - 0.2) < 1e-9

    def test_custom_floor_at_lmax(self):
        """lock_curve(365, floor=0.2) returns 1.0 regardless of floor."""
        result = lock_curve(365, floor=0.2)
        assert abs(result - 1.0) < 1e-6

    def test_custom_floor_in_range(self):
        """With custom floor=0.2, midpoint is between 0.2 and 1.0."""
        result = lock_curve(180, floor=0.2)
        assert 0.2 < result < 1.0


class TestCustomLmax:
    """Custom l_max_days parameter behavior."""

    def test_custom_lmax_at_lmax(self):
        """lock_curve(180, l_max_days=180) returns 1.0."""
        for curve_type in ['sqrt', 'linear', 'log', 'exp']:
            result = lock_curve(180, curve_type=curve_type, l_max_days=180)
            assert abs(result - 1.0) < 1e-6, (
                f'{curve_type}: expected 1.0 at L=l_max=180, got {result}'
            )

    def test_custom_lmax_cap(self):
        """lock_curve(500, l_max_days=365) == lock_curve(365, l_max_days=365)."""
        for curve_type in ['sqrt', 'linear', 'log', 'exp']:
            at_lmax = lock_curve(365, curve_type=curve_type, l_max_days=365)
            beyond = lock_curve(500, curve_type=curve_type, l_max_days=365)
            assert abs(at_lmax - beyond) < 1e-9, (
                f'{curve_type}: cap at custom l_max failed'
            )


class TestInvalidCurveType:
    """Unknown curve_type raises ValueError."""

    def test_unknown_curve_type_raises(self):
        with pytest.raises(ValueError, match='Unknown curve_type'):
            lock_curve(90, curve_type='quadratic')
