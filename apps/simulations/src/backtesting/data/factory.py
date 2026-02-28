"""
Synthetic Governor-compatible event stream factory.

Generates realistic DAO governance event streams with configurable voter counts,
proposal counts, stake distributions, participation profiles, and lock durations.
Produces raw ProposalCreatedEvent, VoteCastEvent, ProposalFinalizedEvent — no
weighting or signals computation is performed here.

Usage:
    from backtesting.data.factory import generate_scenario, StakeProfile, LockProfile

    events = generate_scenario(n_voters=200, n_proposals=30, seed=42)
    events = generate_scenario(budget_enabled=True, allocation_strategy='aggressive')
"""

import logging
import warnings
from dataclasses import dataclass
from typing import Literal

import numpy as np

ScenarioCurveType = Literal['sqrt', 'log', 'linear', 'exp']
_VALID_CURVE_TYPES: tuple[str, ...] = ('sqrt', 'log', 'linear', 'exp')

from backtesting.data.budget import (
    AllocationDistribution,
    AllocationStrategy,
    LockEntry,
    VoterLedger,
    compute_allocation_fraction,
)
from backtesting.data.schema import (
    EventType,
    GovernorEvent,
    ProposalCreatedEvent,
    ProposalFinalizedEvent,
    VoteCastEvent,
    VoteSupport,
)

logger = logging.getLogger(__name__)

StakeProfile = Literal['pareto', 'uniform', 'bimodal']
LockProfile = Literal['correlated', 'inverse_correlated', 'independent', 'bimodal']


@dataclass
class VoteTimingConfig:
    """Vote timing fraction configuration. late_frac = 1 - early - mid."""
    early: float = 0.30
    mid: float = 0.40

    def __post_init__(self) -> None:
        if self.early < 0 or self.mid < 0:
            raise ValueError('early and mid must be >= 0')
        if self.early + self.mid > 1.0:
            raise ValueError(
                f'early + mid must be <= 1.0, '
                f'got {self.early} + {self.mid} = {self.early + self.mid}'
            )

BLOCKS_PER_DAY = 7200  # L2 default (~12s blocks)


def _generate_stakes(
    n_voters: int,
    total_supply: float,
    profile: StakeProfile,
    pareto_alpha: float = 0.7,
    rng: np.random.Generator | None = None,
) -> np.ndarray:
    """Generate voter stakes normalized to total_supply."""
    if rng is None:
        rng = np.random.default_rng()

    if profile == 'pareto':
        raw = rng.pareto(pareto_alpha, size=n_voters) + 1.0
    elif profile == 'uniform':
        raw = np.ones(n_voters, dtype=float)
    elif profile == 'bimodal':
        # 10% of voters hold 90% of supply — top 10% get weight 9, bottom 90% get weight 1
        raw = np.ones(n_voters, dtype=float)
        n_top = max(1, int(n_voters * 0.10))
        raw[:n_top] = 9.0 * n_voters / n_top
    else:
        raise ValueError(f'Unknown stake profile: {profile}')

    total = raw.sum()
    if total == 0:
        return np.full(n_voters, total_supply / n_voters)
    return raw / total * total_supply


def _generate_participation_probs(
    n_voters: int,
    avg_rate: float = 0.10,
    rng: np.random.Generator | None = None,
) -> np.ndarray:
    """
    Generate per-voter participation probabilities via power-law distribution.
    Clipped to [0.01, 0.95] and normalized to target average rate.
    """
    if rng is None:
        rng = np.random.default_rng()

    ranks = np.arange(1, n_voters + 1, dtype=float)
    # Shuffle so rank assignment is random
    rng.shuffle(ranks)
    probs = 1.0 / np.sqrt(ranks)
    probs = np.clip(probs, 0.01, 0.95)

    # Normalize so the mean matches avg_rate
    current_mean = probs.mean()
    if current_mean > 0:
        probs = probs * (avg_rate / current_mean)
    probs = np.clip(probs, 0.01, 0.95)
    return probs


def _generate_vote_timing(
    n_votes: int,
    start_block: int,
    end_block: int,
    early_frac: float = 0.30,
    mid_frac: float = 0.40,
    rng: np.random.Generator | None = None,
) -> np.ndarray:
    """
    Generate tri-modal vote block numbers within [start_block, end_block].
    30% early (0-20% of window), 40% mid (30-70%), 30% late (80-100%).
    """
    if rng is None:
        rng = np.random.default_rng()

    window = end_block - start_block
    if window <= 0 or n_votes == 0:
        return np.full(n_votes, start_block, dtype=int)

    late_frac = 1.0 - early_frac - mid_frac
    n_early = int(round(n_votes * early_frac))
    n_mid = int(round(n_votes * mid_frac))
    n_late = n_votes - n_early - n_mid

    early_blocks = (rng.uniform(0.0, 0.20, size=n_early) * window).astype(int)
    mid_blocks = (rng.uniform(0.30, 0.70, size=n_mid) * window).astype(int)
    late_blocks = (rng.uniform(0.80, 1.00, size=n_late) * window).astype(int)

    offsets = np.concatenate([early_blocks, mid_blocks, late_blocks])
    offsets = np.clip(offsets, 0, window - 1)
    blocks = start_block + offsets
    rng.shuffle(blocks)
    return blocks.astype(int)


def _generate_contentiousness(rng: np.random.Generator) -> float:
    """
    Return a FOR-bias scalar in [0,1] based on a mixed contentiousness model:
      20% FOR blowout  -> bias ~ 0.90
      20% AGAINST blowout -> bias ~ 0.10
      40% competitive -> bias ~ 0.50 ± 0.10
      20% coin-flip   -> bias ~ uniform(0.35, 0.65)
    """
    draw = rng.uniform()
    if draw < 0.20:
        return float(rng.uniform(0.80, 0.95))
    elif draw < 0.40:
        return float(rng.uniform(0.05, 0.20))
    elif draw < 0.80:
        return float(rng.normal(0.50, 0.08))
    else:
        return float(rng.uniform(0.35, 0.65))


def _generate_lock_durations(
    n_votes: int,
    stakes: np.ndarray,
    profile: LockProfile,
    l_max_days: float = 365.0,
    rng: np.random.Generator | None = None,
) -> np.ndarray:
    """
    Generate lock durations in days per lock profile:
      correlated: higher stake -> longer lock (rank-based)
      independent: uniform random in [0, l_max_days]
      bimodal: 30% short-term (0-30d), 70% long-term (180-365d)
    """
    if rng is None:
        rng = np.random.default_rng()

    if n_votes == 0:
        return np.array([], dtype=float)

    if profile == 'correlated':
        # Rank stakes, higher stake -> higher rank -> longer lock
        ranks = np.argsort(np.argsort(stakes)) / max(len(stakes) - 1, 1)
        durations = ranks * l_max_days
        # Add small noise
        noise = rng.uniform(-0.05, 0.05, size=n_votes) * l_max_days
        durations = np.clip(durations + noise, 0.0, l_max_days)
    elif profile == 'inverse_correlated':
        # Higher stake -> shorter lock (whales seek liquidity)
        ranks = np.argsort(np.argsort(stakes)) / max(len(stakes) - 1, 1)
        durations = (1.0 - ranks) * l_max_days
        noise = rng.uniform(-0.05, 0.05, size=n_votes) * l_max_days
        durations = np.clip(durations + noise, 0.0, l_max_days)
    elif profile == 'independent':
        durations = rng.uniform(0.0, l_max_days, size=n_votes)
    elif profile == 'bimodal':
        n_short = int(round(n_votes * 0.30))
        n_long = n_votes - n_short
        short = rng.uniform(0.0, 30.0, size=n_short)
        long_ = rng.uniform(180.0, l_max_days, size=n_long)
        durations = np.concatenate([short, long_])
        rng.shuffle(durations)
    else:
        raise ValueError(f'Unknown lock profile: {profile}')

    return durations.astype(float)


def generate_scenario(
    n_voters: int = 200,
    n_proposals: int = 30,
    total_supply: float = 1_000_000.0,
    avg_participation_rate: float = 0.10,
    stake_profile: StakeProfile = 'pareto',
    lock_profile: LockProfile = 'independent',
    pareto_alpha: float = 0.7,
    l_max_days: float = 365.0,
    proposal_window_blocks: int = 50400,
    seed: int | None = None,
    budget_enabled: bool = True,
    allocation_strategy: AllocationStrategy = 'uniform_fraction',
    blocks_per_day: int = BLOCKS_PER_DAY,
    curve_type: ScenarioCurveType = 'sqrt',
    floor: float = 0.1,
    mc_dist: AllocationDistribution | None = None,
    vote_timing: VoteTimingConfig | None = None,
) -> list[GovernorEvent]:
    """
    Generate a synthetic Governor-compatible event stream.

    Parameters
    ----------
    n_voters : int
        Number of unique voter addresses to generate.
    n_proposals : int
        Number of governance proposals.
    total_supply : float
        Total token supply distributed across voters.
    avg_participation_rate : float
        Target average fraction of voters per proposal.
    stake_profile : StakeProfile
        Stake distribution: 'pareto', 'uniform', or 'bimodal'.
    lock_profile : LockProfile
        Lock duration distribution: 'correlated', 'independent', or 'bimodal'.
    pareto_alpha : float
        Shape parameter for Pareto distribution (higher = more equal).
    l_max_days : float
        Maximum lock duration in days.
    proposal_window_blocks : int
        Number of blocks each proposal is open for voting.
    seed : int | None
        Random seed for reproducibility. None = random.
    budget_enabled : bool
        If True, tokens locked for one proposal are unavailable for concurrent
        proposals. Voters commit a fraction of available balance per vote.
    allocation_strategy : AllocationStrategy
        How much of available balance to commit: 'uniform_fraction' (15-45%),
        'conviction_weighted' (scales with lock duration), or 'aggressive' (60-100%).
    blocks_per_day : int
        Blocks per day for lock duration conversion (default 7200 for L2).
    curve_type : ScenarioCurveType
        Lock curve shape used by the simulation: 'sqrt', 'log', 'linear', or 'exp'.
        Default 'sqrt' (backward-compatible).
    floor : float
        Floor value for compute_signals_weight in the cadCAD simulation.
        Passed through to run_backtest via the caller; not used in event generation.
        Default 0.1 (backward-compatible).
    mc_dist : AllocationDistribution | None
        If provided, draw ONE allocation fraction for the entire scenario from this
        distribution using a separate RNG stream (two-RNG split). When None, the
        legacy per-voter allocation strategy is used (backward-compatible).
    vote_timing : VoteTimingConfig | None
        If provided, override the default early/mid vote timing fractions.
        When None, defaults to early=0.30, mid=0.40.

    Returns
    -------
    list[GovernorEvent]
        Events sorted by block_number. Contains ProposalCreatedEvent,
        VoteCastEvent, and ProposalFinalizedEvent objects.
    """
    if curve_type not in _VALID_CURVE_TYPES:
        raise ValueError(
            f'curve_type={curve_type!r} is invalid. '
            f'Must be one of: {_VALID_CURVE_TYPES}'
        )

    if n_voters < 100 and stake_profile == 'pareto':
        warnings.warn(
            f'n_voters={n_voters} < 100 with stake_profile=pareto: '
            'Gini coefficient may not reach 0.65 threshold.',
            UserWarning,
            stacklevel=2,
        )

    # --- MC distribution mode: two-RNG split ---
    alloc_frac: float | None = None
    if mc_dist is not None:
        if seed is None:
            parent_ss = np.random.SeedSequence()
        else:
            parent_ss = np.random.SeedSequence(seed)
        alloc_child, scenario_child = parent_ss.spawn(2)
        alloc_rng = np.random.default_rng(alloc_child)
        rng = np.random.default_rng(scenario_child)
        # Draw ONE allocation fraction for the entire scenario (locked decision)
        alloc_frac = float(mc_dist.sample(alloc_rng, 1)[0])
    else:
        # UNCHANGED: backward-compatible path
        rng = np.random.default_rng(seed)

    # Generate voter addresses
    voters = [f'0x{i:040x}' for i in range(n_voters)]

    # Generate stakes
    stakes = _generate_stakes(n_voters, total_supply, stake_profile, pareto_alpha, rng)

    # Generate per-voter participation probabilities
    participation_probs = _generate_participation_probs(n_voters, avg_participation_rate, rng)

    # Initialize per-voter budget ledgers
    ledgers = [VoterLedger(total_stake=float(stakes[i])) for i in range(n_voters)]

    events: list[GovernorEvent] = []

    # Spacing between proposals: proposal window + gap
    gap_blocks = 100
    proposal_start_offset = 1000  # first proposal starts at block 1000

    for p_idx in range(n_proposals):
        proposal_id = f'proposal-{p_idx:04d}'
        proposer = voters[p_idx % n_voters]

        creation_block = proposal_start_offset + p_idx * (proposal_window_blocks + gap_blocks)
        start_block = creation_block + 10
        end_block = start_block + proposal_window_blocks

        proposal_event = ProposalCreatedEvent(
            block_number=creation_block,
            proposal_id=proposal_id,
            proposer=proposer,
            start_block=start_block,
            end_block=end_block,
            description=f'Synthetic proposal {p_idx}',
            quorum=0,
        )
        events.append(proposal_event)

        # Determine participating voters (Bernoulli draw per voter)
        participation_draws = rng.uniform(0.0, 1.0, size=n_voters)
        participating_mask = participation_draws < participation_probs
        participating_indices = np.where(participating_mask)[0]

        if len(participating_indices) == 0:
            # Ensure at least one voter participates
            participating_indices = np.array([rng.integers(0, n_voters)])

        n_votes = len(participating_indices)

        # Generate vote timing — resolve timing fractions from VoteTimingConfig
        _early = vote_timing.early if vote_timing is not None else 0.30
        _mid = vote_timing.mid if vote_timing is not None else 0.40
        vote_blocks = _generate_vote_timing(n_votes, start_block, end_block, early_frac=_early, mid_frac=_mid, rng=rng)

        # Generate contentiousness (FOR bias)
        for_bias = _generate_contentiousness(rng)
        # Clamp to valid probability range
        for_bias = float(np.clip(for_bias, 0.01, 0.99))

        # Generate lock durations for this proposal's voters
        voter_stakes_subset = stakes[participating_indices]
        lock_durations = _generate_lock_durations(
            n_votes, voter_stakes_subset, lock_profile, l_max_days, rng
        )

        # Generate support values
        support_draws = rng.uniform(0.0, 1.0, size=n_votes)
        # 5% abstain, rest split by for_bias
        abstain_threshold = 0.05
        for_threshold = abstain_threshold + (1.0 - abstain_threshold) * for_bias

        seen_voters: set[str] = set()

        for i, voter_idx in enumerate(participating_indices):
            voter = voters[voter_idx]
            # Enforce no double votes
            if voter in seen_voters:
                continue
            seen_voters.add(voter)

            draw = support_draws[i]
            if draw < abstain_threshold:
                support = VoteSupport.ABSTAIN
            elif draw < for_threshold:
                support = VoteSupport.FOR
            else:
                support = VoteSupport.AGAINST

            vote_block = int(vote_blocks[i])
            # Clamp to valid window
            vote_block = max(start_block, min(end_block - 1, vote_block))

            lock_days = float(lock_durations[i])

            # Budget allocation: compute weight from available balance
            if budget_enabled:
                available = ledgers[voter_idx].available_balance(vote_block)
                if available <= 0.0:
                    continue  # voter is fully locked out

                if alloc_frac is not None:
                    # MC mode: use pre-drawn fraction for all voters
                    frac = alloc_frac
                else:
                    # Legacy mode: compute per-voter fraction (unchanged)
                    frac = compute_allocation_fraction(
                        allocation_strategy, lock_days, l_max_days, rng
                    )
                allocated = available * frac
                unlock_block = vote_block + int(lock_days * blocks_per_day)
                ledgers[voter_idx].add_lock(allocated, unlock_block)
                vote_weight = allocated
            else:
                vote_weight = float(stakes[voter_idx])

            vote_event = VoteCastEvent(
                block_number=vote_block,
                proposal_id=proposal_id,
                voter=voter,
                support=support,
                weight=vote_weight,
                lock_duration_days=lock_days,
            )
            events.append(vote_event)

        # ProposalFinalizedEvent after end_block
        finalized_block = end_block + 1
        # Determine if passed: simple majority of FOR > AGAINST
        for_weight = sum(
            e.weight for e in events
            if isinstance(e, VoteCastEvent)
            and e.proposal_id == proposal_id
            and e.support == VoteSupport.FOR
        )
        against_weight = sum(
            e.weight for e in events
            if isinstance(e, VoteCastEvent)
            and e.proposal_id == proposal_id
            and e.support == VoteSupport.AGAINST
        )
        passed = for_weight > against_weight

        finalized_event = ProposalFinalizedEvent(
            block_number=finalized_block,
            proposal_id=proposal_id,
            passed=passed,
        )
        events.append(finalized_event)

    # Sort all events by block_number
    events.sort(key=lambda e: e.block_number)

    return events
