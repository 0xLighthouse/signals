"""
Tests for the Monte Carlo runner module (backtesting/mc.py).

Coverage:
  MCAL-02: 50 MC samples with same base_seed produce 50 distinct allocation sequences.
  MCAL-04: MC runner produces N samples each with a distinct seed in metadata.
"""

import numpy as np
import pytest

from backtesting.data.budget import BetaDistribution
from backtesting.data.schema import VoteCastEvent
from backtesting.mc import MCResult, MCSample, run_mc_samples


def test_mcal02_independent_sequences():
    """MCAL-02: 50 MC samples with same base_seed produce 50 distinct allocation sequences."""
    dist = BetaDistribution(a=2, b=5)
    result = run_mc_samples(
        mc_dist=dist,
        n_samples=50,
        base_seed=42,
        n_voters=50,
        n_proposals=3,
    )
    assert result.n_samples == 50
    assert len(result.samples) == 50

    # All allocation fractions must be distinct
    fracs = [s.alloc_frac for s in result.samples]
    unique_fracs = set(round(f, 12) for f in fracs)
    assert len(unique_fracs) == 50, (
        f'Expected 50 distinct alloc fractions, got {len(unique_fracs)}'
    )

    # All fractions must be in [0, 1] (Beta distribution property)
    for f in fracs:
        assert 0.0 <= f <= 1.0, f'alloc_frac {f} out of [0,1] range'


def test_mcal04_mc_runner_distinct_seeds():
    """MCAL-04: MC runner produces N samples with distinct seeds in metadata."""
    dist = BetaDistribution(a=2, b=5)
    result = run_mc_samples(
        mc_dist=dist,
        n_samples=20,
        base_seed=99,
        n_voters=50,
        n_proposals=3,
    )
    seeds = [s.seed for s in result.samples]
    assert len(set(seeds)) == 20, (
        f'Expected 20 distinct seeds, got {len(set(seeds))}'
    )

    # Each sample has sequential index
    indices = [s.index for s in result.samples]
    assert indices == list(range(20))

    # Each sample has events
    for sample in result.samples:
        assert len(sample.events) > 0, f'Sample {sample.index} has no events'


def test_mc_runner_reproducible():
    """MC runner with same base_seed produces identical results."""
    dist = BetaDistribution(a=2, b=5)
    r1 = run_mc_samples(mc_dist=dist, n_samples=10, base_seed=42, n_voters=50, n_proposals=3)
    r2 = run_mc_samples(mc_dist=dist, n_samples=10, base_seed=42, n_voters=50, n_proposals=3)

    assert r1.base_seed == r2.base_seed
    for s1, s2 in zip(r1.samples, r2.samples):
        assert s1.seed == s2.seed
        assert s1.alloc_frac == s2.alloc_frac
        assert len(s1.events) == len(s2.events)


def test_mc_runner_auto_seed():
    """MC runner with base_seed=None auto-generates and records a seed."""
    dist = BetaDistribution(a=2, b=5)
    result = run_mc_samples(
        mc_dist=dist, n_samples=5, base_seed=None, n_voters=50, n_proposals=3
    )
    assert result.base_seed is not None
    assert isinstance(result.base_seed, int)
    assert result.n_samples == 5
    assert len(result.samples) == 5
