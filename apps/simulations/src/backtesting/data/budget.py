"""
Public budget and lock constraint module for backtesting.

Promoted from private internals in factory.py to enable testability and
Monte Carlo parameterization needed by Phase 9.

Provides:
  - LockEntry / VoterLedger — token lock accounting
  - compute_allocation_fraction — per-proposal allocation logic
  - AllocationDistribution hierarchy — pluggable MC sampling (Phase 9)

Leaf module: imports ONLY numpy, stdlib, and scipy.stats.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Literal

import numpy as np

# ---------------------------------------------------------------------------
# Type aliases
# ---------------------------------------------------------------------------

AllocationStrategy = Literal['uniform_fraction', 'conviction_weighted', 'aggressive']


# ---------------------------------------------------------------------------
# Lock accounting
# ---------------------------------------------------------------------------

@dataclass
class LockEntry:
    """A single token lock: amount locked until unlock_block."""
    amount: float
    unlock_block: int


@dataclass
class VoterLedger:
    """Tracks a voter's total stake and active locks for budget allocation."""
    total_stake: float
    locks: list[LockEntry] = field(default_factory=list)

    def available_balance(self, at_block: int) -> float:
        """Return total_stake minus sum of locks still active at at_block."""
        locked = sum(
            lock.amount for lock in self.locks if lock.unlock_block > at_block
        )
        return max(0.0, self.total_stake - locked)

    def add_lock(self, amount: float, unlock_block: int) -> None:
        self.locks.append(LockEntry(amount=amount, unlock_block=unlock_block))


# ---------------------------------------------------------------------------
# Allocation fraction
# ---------------------------------------------------------------------------

def compute_allocation_fraction(
    strategy: AllocationStrategy,
    lock_duration_days: float,
    l_max_days: float,
    rng: np.random.Generator,
) -> float:
    """Return the fraction of available balance a voter commits to one proposal."""
    if strategy == 'uniform_fraction':
        return float(rng.uniform(0.15, 0.45))
    elif strategy == 'conviction_weighted':
        # Longer lock -> bigger commitment (15-70% range)
        ratio = min(lock_duration_days / max(l_max_days, 1.0), 1.0)
        base = 0.15 + 0.55 * ratio
        noise = float(rng.uniform(-0.05, 0.05))
        return float(np.clip(base + noise, 0.10, 0.75))
    elif strategy == 'aggressive':
        return float(rng.uniform(0.60, 1.00))
    else:
        raise ValueError(f'Unknown allocation strategy: {strategy}')


# ---------------------------------------------------------------------------
# AllocationDistribution hierarchy (BUDG-05)
# ---------------------------------------------------------------------------

class AllocationDistribution(ABC):
    """Abstract base: knows how to sample allocation fractions in [0, 1]."""

    @abstractmethod
    def sample(self, rng: np.random.Generator, size: int) -> np.ndarray:
        """Draw `size` allocation fractions. Returns ndarray of shape (size,)."""
        ...


@dataclass
class BetaDistribution(AllocationDistribution):
    """Beta(a, b) distribution bounded to [0, 1]."""
    a: float
    b: float

    def __post_init__(self) -> None:
        if self.a <= 0 or self.b <= 0:
            raise ValueError(
                f'BetaDistribution requires a > 0, b > 0, got a={self.a}, b={self.b}'
            )

    def sample(self, rng: np.random.Generator, size: int) -> np.ndarray:
        return rng.beta(self.a, self.b, size=size)


@dataclass
class UniformDistribution(AllocationDistribution):
    """Uniform(low, high) distribution."""
    low: float = 0.15
    high: float = 0.45

    def __post_init__(self) -> None:
        if self.low >= self.high:
            raise ValueError(
                f'UniformDistribution requires low < high, got {self.low}, {self.high}'
            )

    def sample(self, rng: np.random.Generator, size: int) -> np.ndarray:
        return rng.uniform(self.low, self.high, size=size)


@dataclass
class TruncnormDistribution(AllocationDistribution):
    """Truncated normal distribution clipped to [clip_low, clip_high]."""
    mean: float = 0.35
    std: float = 0.15
    clip_low: float = 0.0
    clip_high: float = 1.0

    def __post_init__(self) -> None:
        if self.std <= 0:
            raise ValueError(
                f'TruncnormDistribution requires std > 0, got {self.std}'
            )
        if self.clip_low >= self.clip_high:
            raise ValueError(
                f'TruncnormDistribution requires clip_low < clip_high'
            )

    def sample(self, rng: np.random.Generator, size: int) -> np.ndarray:
        from scipy import stats
        a_param = (self.clip_low - self.mean) / self.std
        b_param = (self.clip_high - self.mean) / self.std
        return stats.truncnorm.rvs(
            a_param, b_param,
            loc=self.mean, scale=self.std,
            size=size, random_state=rng,
        )
