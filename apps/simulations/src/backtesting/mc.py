"""
Monte Carlo runner module for Phase 9.

Produces N independent scenario samples using numpy SeedSequence.spawn() for
statistically independent RNG streams. Each sample uses a distinct child seed
derived from a shared base seed, ensuring reproducibility while eliminating
sample-to-sample correlation.

Usage:
    from backtesting.mc import run_mc_samples, MCSample, MCResult
    from backtesting.data.budget import BetaDistribution

    result = run_mc_samples(
        mc_dist=BetaDistribution(a=2, b=5),
        n_samples=50,
        base_seed=42,
    )
    for sample in result.samples:
        print(sample.index, sample.alloc_frac, len(sample.events))
"""

from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np

from backtesting.data.budget import AllocationDistribution
from backtesting.data.factory import VoteTimingConfig, generate_scenario
from backtesting.data.schema import GovernorEvent

__all__ = ['MCSample', 'MCResult', 'run_mc_samples']


@dataclass
class MCSample:
    """One MC sample: events + metadata for reproduction."""

    index: int
    seed: int  # unique per-sample seed derived from SeedSequence child
    alloc_frac: float  # the allocation fraction drawn for this sample
    events: list[GovernorEvent]


@dataclass
class MCResult:
    """Result of an MC sampling run: N independent samples."""

    base_seed: int  # base seed used (auto-generated if None was passed)
    n_samples: int
    samples: list[MCSample] = field(default_factory=list)


def run_mc_samples(
    mc_dist: AllocationDistribution,
    n_samples: int = 50,
    base_seed: int | None = None,
    vote_timing: VoteTimingConfig | None = None,
    *,
    n_voters: int = 200,
    n_proposals: int = 30,
    total_supply: float = 1_000_000.0,
    avg_participation_rate: float = 0.10,
    stake_profile: str = 'pareto',
    lock_profile: str = 'independent',
    pareto_alpha: float = 0.7,
    l_max_days: float = 365.0,
    proposal_window_blocks: int = 50400,
    budget_enabled: bool = True,
    allocation_strategy: str = 'uniform_fraction',
    blocks_per_day: int = 7200,
    curve_type: str = 'sqrt',
) -> MCResult:
    """
    Run N independent Monte Carlo scenario samples.

    Uses numpy SeedSequence.spawn(n_samples) to produce statistically
    independent RNG streams, one per sample. Each sample receives a distinct
    child SeedSequence, ensuring no inter-sample correlation.

    Parameters
    ----------
    mc_dist : AllocationDistribution
        Distribution to draw per-scenario allocation fractions from.
    n_samples : int
        Number of independent MC samples to generate.
    base_seed : int | None
        Base seed for reproducibility. If None, a random seed is generated
        and recorded in MCResult for later reproduction.
    vote_timing : VoteTimingConfig | None
        Optional vote timing override passed to generate_scenario().
    n_voters : int
        Number of voters per scenario.
    n_proposals : int
        Number of proposals per scenario.
    total_supply : float
        Total token supply distributed across voters.
    avg_participation_rate : float
        Target average participation rate per proposal.
    stake_profile : str
        Voter stake distribution: 'pareto', 'uniform', or 'bimodal'.
    lock_profile : str
        Lock duration distribution: 'correlated', 'independent', or 'bimodal'.
    pareto_alpha : float
        Pareto shape parameter (higher = more equal distribution).
    l_max_days : float
        Maximum lock duration in days.
    proposal_window_blocks : int
        Number of blocks each proposal is open for voting.
    budget_enabled : bool
        Whether token budget constraints apply.
    allocation_strategy : str
        Fallback allocation strategy when mc_dist=None (not used here).
    blocks_per_day : int
        Blocks per day for lock duration conversion.
    curve_type : str
        Lock curve shape: 'sqrt', 'log', or 'linear'.

    Returns
    -------
    MCResult
        Contains base_seed, n_samples, and a list of MCSample objects.
    """
    # Auto-generate base seed if not provided
    if base_seed is None:
        ss = np.random.SeedSequence()
        base_seed = ss.entropy  # large int, fully reproducible if stored
    else:
        ss = np.random.SeedSequence(base_seed)

    # Spawn N independent child SeedSequences — one per sample
    children = ss.spawn(n_samples)

    samples: list[MCSample] = []

    for i, child in enumerate(children):
        # Derive a uint32 int seed from the child for use as generate_scenario's seed
        # generate_scenario internally wraps this int in SeedSequence(seed), then spawns 2
        # children for alloc_rng and scenario_rng — ensuring distinct streams per sample.
        sample_seed = int(child.generate_state(1)[0])

        events = generate_scenario(
            n_voters=n_voters,
            n_proposals=n_proposals,
            total_supply=total_supply,
            avg_participation_rate=avg_participation_rate,
            stake_profile=stake_profile,
            lock_profile=lock_profile,
            pareto_alpha=pareto_alpha,
            l_max_days=l_max_days,
            proposal_window_blocks=proposal_window_blocks,
            seed=sample_seed,
            budget_enabled=budget_enabled,
            allocation_strategy=allocation_strategy,
            blocks_per_day=blocks_per_day,
            curve_type=curve_type,
            mc_dist=mc_dist,
            vote_timing=vote_timing,
        )

        # Reproduce the alloc_frac that generate_scenario drew.
        # generate_scenario does: SeedSequence(sample_seed).spawn(2)
        # where first child is alloc_child. Mirror that exactly:
        alloc_ss = np.random.SeedSequence(sample_seed)
        alloc_child_ss, _ = alloc_ss.spawn(2)
        alloc_rng = np.random.default_rng(alloc_child_ss)
        alloc_frac = float(mc_dist.sample(alloc_rng, 1)[0])

        samples.append(MCSample(
            index=i,
            seed=sample_seed,
            alloc_frac=alloc_frac,
            events=events,
        ))

    return MCResult(base_seed=base_seed, n_samples=n_samples, samples=samples)
