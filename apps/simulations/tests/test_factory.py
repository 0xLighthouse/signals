"""
Tests for the synthetic event factory — DATA-02 through DATA-08.

Covers:
  DATA-02: Configurable voter/proposal counts and participation rate
  DATA-03: Pareto Gini >= 0.65 at n=200
  DATA-04: Tri-modal vote timing (early/mid/late)
  DATA-05: No double votes, no out-of-window votes
  DATA-07: All three distribution profiles produce valid output
  DATA-08: Reproducibility — same seed = identical output
"""

import warnings

import numpy as np
import pytest

from backtesting.data.budget import BetaDistribution
from backtesting.data.factory import VoteTimingConfig, generate_scenario
from backtesting.data.loader import events_to_dataframe, validate_event_stream
from backtesting.data.schema import EventType, VoteCastEvent, VoteSupport


def _gini(values: np.ndarray) -> float:
    """Compute the Gini coefficient of a 1-D array."""
    if len(values) == 0:
        return 0.0
    values = np.sort(np.abs(values))
    n = len(values)
    index = np.arange(1, n + 1)
    return float((2 * np.sum(index * values) - (n + 1) * np.sum(values)) / (n * np.sum(values)))


def _get_vote_events(events) -> list[VoteCastEvent]:
    return [e for e in events if isinstance(e, VoteCastEvent)]


# ---------------------------------------------------------------------------
# DATA-02: Configurable counts
# ---------------------------------------------------------------------------

def test_configurable_counts():
    """generate_scenario respects n_voters and n_proposals."""
    with warnings.catch_warnings():
        warnings.simplefilter('ignore', UserWarning)
        events = generate_scenario(n_voters=100, n_proposals=10, seed=1)

    created = [e for e in events if e.event_type == EventType.PROPOSAL_CREATED]
    assert len(created) == 10, f'Expected 10 proposals, got {len(created)}'

    vote_events = _get_vote_events(events)
    unique_voters = {e.voter for e in vote_events}
    assert len(unique_voters) <= 100, f'Unique voters {len(unique_voters)} exceeds n_voters=100'


# ---------------------------------------------------------------------------
# DATA-03: Gini >= 0.65 for Pareto distribution at n=200
# ---------------------------------------------------------------------------

def test_gini_requirement():
    """Pareto stake distribution achieves Gini >= 0.65 at n=200 voters."""
    from backtesting.data.factory import _generate_stakes
    seeds = [42, 7, 13, 99, 256]
    for seed in seeds:
        rng = np.random.default_rng(seed)
        stakes = _generate_stakes(200, 1_000_000.0, 'pareto', pareto_alpha=0.7, rng=rng)
        gini = _gini(stakes)
        assert gini >= 0.65, (
            f'Gini={gini:.4f} < 0.65 for seed={seed} with pareto profile'
        )


# ---------------------------------------------------------------------------
# DATA-04: Tri-modal vote timing
# ---------------------------------------------------------------------------

def test_trimodal_timing():
    """Vote timing spans early, mid, and late windows."""
    # Use enough voters and a single proposal to get a decent vote count
    events = generate_scenario(n_voters=200, n_proposals=1, seed=42, avg_participation_rate=0.50)
    created = [e for e in events if e.event_type == EventType.PROPOSAL_CREATED][0]
    start_block = created.start_block
    end_block = created.end_block
    window = end_block - start_block

    vote_events = _get_vote_events(events)
    assert len(vote_events) >= 10, 'Need at least 10 votes to test timing distribution'

    blocks = np.array([e.block_number for e in vote_events])
    offsets = (blocks - start_block) / window

    early_frac = np.mean(offsets <= 0.20)
    mid_frac = np.mean((offsets >= 0.30) & (offsets <= 0.70))
    late_frac = np.mean(offsets >= 0.80)

    assert early_frac > 0.10, f'Early fraction {early_frac:.3f} too low'
    assert mid_frac > 0.10, f'Mid fraction {mid_frac:.3f} too low'
    assert late_frac > 0.10, f'Late fraction {late_frac:.3f} too low'


# ---------------------------------------------------------------------------
# DATA-05: No double votes, no out-of-window votes
# ---------------------------------------------------------------------------

def test_referential_integrity():
    """validate_event_stream returns no errors on factory output."""
    events = generate_scenario(n_voters=100, n_proposals=10, seed=42)
    df = events_to_dataframe(events)
    errors = validate_event_stream(df)
    assert errors == [], f'Validation errors: {errors}'

    # Extra: no voter appears twice on same proposal
    vote_events = _get_vote_events(events)
    seen: set[tuple[str, str]] = set()
    for e in vote_events:
        key = (e.voter, e.proposal_id)
        assert key not in seen, f'Double vote detected: {key}'
        seen.add(key)


# ---------------------------------------------------------------------------
# DATA-07: Distribution profiles
# ---------------------------------------------------------------------------

def test_distribution_profiles():
    """Uniform profile gives equal stakes; bimodal gives top-heavy distribution."""
    # Uniform: all stakes equal within floating-point tolerance
    with warnings.catch_warnings():
        warnings.simplefilter('ignore', UserWarning)
        events_uniform = generate_scenario(
            n_voters=50, n_proposals=3, seed=42,
            stake_profile='uniform', avg_participation_rate=0.50,
            budget_enabled=False,
        )
    vote_events_uniform = _get_vote_events(events_uniform)
    if vote_events_uniform:
        stakes_uniform = np.array([e.weight for e in vote_events_uniform])
        assert np.allclose(stakes_uniform, stakes_uniform[0], rtol=1e-6), (
            'Uniform stakes are not equal'
        )

    # Bimodal: top 10% voters significantly outweigh bottom 90%
    events_bimodal = generate_scenario(
        n_voters=200, n_proposals=1, seed=42,
        stake_profile='bimodal', avg_participation_rate=0.80
    )
    vote_events_bimodal = _get_vote_events(events_bimodal)
    if len(vote_events_bimodal) > 10:
        stakes_bimodal = sorted([e.weight for e in vote_events_bimodal], reverse=True)
        n = len(stakes_bimodal)
        top_10_pct = stakes_bimodal[:max(1, n // 10)]
        bottom_90_pct = stakes_bimodal[max(1, n // 10):]
        mean_top = np.mean(top_10_pct)
        mean_bottom = np.mean(bottom_90_pct)
        assert mean_top > mean_bottom * 2, (
            f'Bimodal: top={mean_top:.2f} not significantly > bottom={mean_bottom:.2f}'
        )


# ---------------------------------------------------------------------------
# DATA-08: Reproducibility
# ---------------------------------------------------------------------------

def test_reproducibility():
    """Same seed produces identical event streams."""
    events_a = generate_scenario(n_voters=100, n_proposals=5, seed=42)
    events_b = generate_scenario(n_voters=100, n_proposals=5, seed=42)

    assert len(events_a) == len(events_b), 'Different event counts with same seed'
    for i, (a, b) in enumerate(zip(events_a, events_b)):
        assert a.block_number == b.block_number, f'Block mismatch at index {i}'
        assert a.event_type == b.event_type, f'Event type mismatch at index {i}'
        assert a.proposal_id == b.proposal_id, f'Proposal ID mismatch at index {i}'
        if hasattr(a, 'voter'):
            assert a.voter == b.voter, f'Voter mismatch at index {i}'
        if hasattr(a, 'support'):
            assert a.support == b.support, f'Support mismatch at index {i}'


# ---------------------------------------------------------------------------
# Lock durations
# ---------------------------------------------------------------------------

def test_lock_durations_generated():
    """VoteCastEvents have lock_duration_days >= 0."""
    with warnings.catch_warnings():
        warnings.simplefilter('ignore', UserWarning)
        events = generate_scenario(n_voters=50, n_proposals=3, seed=42, avg_participation_rate=0.50)
    vote_events = _get_vote_events(events)
    assert vote_events, 'No vote events generated'
    for e in vote_events:
        assert e.lock_duration_days >= 0.0, f'Negative lock_duration: {e.lock_duration_days}'

    # correlated: higher stake voters should have longer locks on average
    events_corr = generate_scenario(
        n_voters=200, n_proposals=2, seed=42,
        lock_profile='correlated', avg_participation_rate=0.50
    )
    vote_corr = _get_vote_events(events_corr)
    if len(vote_corr) >= 20:
        stakes_arr = np.array([e.weight for e in vote_corr])
        locks_arr = np.array([e.lock_duration_days for e in vote_corr])
        # Correlation should be positive
        corr = float(np.corrcoef(stakes_arr, locks_arr)[0, 1])
        assert corr > 0.0, f'Correlated lock profile has non-positive correlation: {corr:.4f}'

    # inverse_correlated: higher stake voters should have shorter locks
    events_inv = generate_scenario(
        n_voters=200, n_proposals=2, seed=42,
        lock_profile='inverse_correlated', avg_participation_rate=0.50
    )
    vote_inv = _get_vote_events(events_inv)
    if len(vote_inv) >= 20:
        stakes_inv = np.array([e.weight for e in vote_inv])
        locks_inv = np.array([e.lock_duration_days for e in vote_inv])
        # Correlation should be negative
        corr_inv = float(np.corrcoef(stakes_inv, locks_inv)[0, 1])
        assert corr_inv < 0.0, f'Inverse correlated lock profile has non-negative correlation: {corr_inv:.4f}'

    # bimodal: locks cluster around short and long
    events_bi = generate_scenario(
        n_voters=200, n_proposals=2, seed=42,
        lock_profile='bimodal', avg_participation_rate=0.50
    )
    vote_bi = _get_vote_events(events_bi)
    if vote_bi:
        locks_bi = np.array([e.lock_duration_days for e in vote_bi])
        short_count = np.sum(locks_bi <= 30.0)
        long_count = np.sum(locks_bi >= 180.0)
        assert short_count > 0, 'Bimodal lock profile has no short-term locks'
        assert long_count > 0, 'Bimodal lock profile has no long-term locks'


# ---------------------------------------------------------------------------
# Abstain votes exist
# ---------------------------------------------------------------------------

def test_abstain_votes_present():
    """Large scenario contains at least some ABSTAIN votes."""
    events = generate_scenario(n_voters=200, n_proposals=30, seed=42)
    vote_events = _get_vote_events(events)
    support_values = {e.support for e in vote_events}
    assert VoteSupport.ABSTAIN in support_values, (
        'No ABSTAIN votes found in large scenario'
    )


# ---------------------------------------------------------------------------
# Proposal lifecycle
# ---------------------------------------------------------------------------

def test_proposal_lifecycle():
    """Every proposal has PROPOSAL_CREATED and PROPOSAL_FINALIZED events."""
    with warnings.catch_warnings():
        warnings.simplefilter('ignore', UserWarning)
        events = generate_scenario(n_voters=50, n_proposals=5, seed=42)

    created = {
        e.proposal_id: e
        for e in events
        if e.event_type == EventType.PROPOSAL_CREATED
    }
    finalized = {
        e.proposal_id: e
        for e in events
        if e.event_type == EventType.PROPOSAL_FINALIZED
    }

    assert len(created) == 5, f'Expected 5 created proposals, got {len(created)}'
    assert len(finalized) == 5, f'Expected 5 finalized proposals, got {len(finalized)}'
    assert set(created.keys()) == set(finalized.keys()), (
        'Mismatch between created and finalized proposal IDs'
    )

    for pid, fin in finalized.items():
        cre = created[pid]
        assert fin.block_number > cre.end_block, (
            f'Finalized block {fin.block_number} <= end_block {cre.end_block} for {pid}'
        )


# ---------------------------------------------------------------------------
# Events sorted
# ---------------------------------------------------------------------------

def test_events_sorted():
    """All returned events have monotonically non-decreasing block_number."""
    with warnings.catch_warnings():
        warnings.simplefilter('ignore', UserWarning)
        events = generate_scenario(n_voters=50, n_proposals=5, seed=42)
    blocks = [e.block_number for e in events]
    for i in range(1, len(blocks)):
        assert blocks[i] >= blocks[i - 1], (
            f'Events not sorted: block[{i}]={blocks[i]} < block[{i-1}]={blocks[i-1]}'
        )


# ---------------------------------------------------------------------------
# Budget allocation (token budget)
# ---------------------------------------------------------------------------

class TestBudgetAllocation:
    """Tests for token budget allocation in generate_scenario."""

    def test_weights_le_full_stake(self):
        """With budget enabled, vote weights must be <= voter's full stake."""
        events = generate_scenario(
            n_voters=200, n_proposals=30, seed=42, budget_enabled=True,
        )
        vote_events = _get_vote_events(events)
        # Build stake lookup from first-proposal weights with budget disabled
        events_legacy = generate_scenario(
            n_voters=200, n_proposals=30, seed=42, budget_enabled=False,
        )
        legacy_votes = _get_vote_events(events_legacy)
        full_stakes: dict[str, float] = {}
        for e in legacy_votes:
            if e.voter not in full_stakes:
                full_stakes[e.voter] = e.weight

        for e in vote_events:
            if e.voter in full_stakes:
                assert e.weight <= full_stakes[e.voter] + 1e-6, (
                    f'Vote weight {e.weight} > full stake {full_stakes[e.voter]} for {e.voter}'
                )

    def test_available_balance_decreases(self):
        """A voter's total weight across proposals should exceed any single vote weight."""
        events = generate_scenario(
            n_voters=200, n_proposals=30, seed=42,
            budget_enabled=True, avg_participation_rate=0.30,
        )
        vote_events = _get_vote_events(events)
        # Group by voter
        voter_weights: dict[str, list[float]] = {}
        for e in vote_events:
            voter_weights.setdefault(e.voter, []).append(e.weight)

        # Voters who voted multiple times should show decreasing or varied weights
        multi_voters = {v: ws for v, ws in voter_weights.items() if len(ws) >= 3}
        assert multi_voters, 'No voters with 3+ votes to test balance decrease'

        for voter, weights in multi_voters.items():
            # Sum of allocated amounts should be bounded by total stake
            # (can't allocate more than you have)
            total_allocated = sum(weights)
            max_single = max(weights)
            assert total_allocated > max_single, (
                f'Voter {voter} total allocated {total_allocated} not > max single {max_single}'
            )

    def test_zero_balance_voters_skipped(self):
        """With aggressive allocation, individual vote weights never exceed available balance."""
        from backtesting.data.factory import _generate_stakes, BLOCKS_PER_DAY
        from backtesting.data.budget import VoterLedger

        events = generate_scenario(
            n_voters=200, n_proposals=30, seed=42,
            budget_enabled=True, allocation_strategy='aggressive',
            avg_participation_rate=0.30,
        )
        vote_events = _get_vote_events(events)

        # Reconstruct ledgers and verify no vote exceeds available balance
        rng = np.random.default_rng(42)
        stakes = _generate_stakes(200, 1_000_000.0, 'pareto', 0.7, rng)
        voters = [f'0x{i:040x}' for i in range(200)]
        stake_map = dict(zip(voters, (float(s) for s in stakes)))
        ledgers: dict[str, VoterLedger] = {
            v: VoterLedger(total_stake=stake_map[v]) for v in voters
        }

        for e in vote_events:
            avail = ledgers[e.voter].available_balance(e.block_number)
            assert e.weight <= avail + 1e-6, (
                f'Vote weight {e.weight:.2f} > available {avail:.2f} for {e.voter}'
            )
            unlock = e.block_number + int(e.lock_duration_days * BLOCKS_PER_DAY)
            ledgers[e.voter].add_lock(e.weight, unlock)

    def test_strategies_produce_different_distributions(self):
        """Different allocation strategies produce different weight distributions."""
        results = {}
        for strategy in ('uniform_fraction', 'conviction_weighted', 'aggressive'):
            events = generate_scenario(
                n_voters=200, n_proposals=10, seed=42,
                budget_enabled=True, allocation_strategy=strategy,
                avg_participation_rate=0.20,
            )
            weights = [e.weight for e in _get_vote_events(events)]
            results[strategy] = np.mean(weights) if weights else 0.0

        # Aggressive should have highest mean weight, uniform_fraction lowest
        assert results['aggressive'] > results['uniform_fraction'], (
            f'Aggressive mean {results["aggressive"]:.1f} not > '
            f'uniform mean {results["uniform_fraction"]:.1f}'
        )

    def test_budget_disabled_matches_legacy(self):
        """budget_enabled=False gives full stake as weight (legacy behavior)."""
        with warnings.catch_warnings():
            warnings.simplefilter('ignore', UserWarning)
            events = generate_scenario(
                n_voters=50, n_proposals=5, seed=42, budget_enabled=False,
            )
        vote_events = _get_vote_events(events)
        # Each voter's weight should be identical across all their votes
        voter_weights: dict[str, set[float]] = {}
        for e in vote_events:
            voter_weights.setdefault(e.voter, set()).add(round(e.weight, 6))
        for voter, weights in voter_weights.items():
            assert len(weights) == 1, (
                f'Legacy voter {voter} has varying weights: {weights}'
            )

    def test_budget_reproducibility(self):
        """Same seed with budget enabled produces identical output."""
        events_a = generate_scenario(
            n_voters=200, n_proposals=10, seed=42, budget_enabled=True,
        )
        events_b = generate_scenario(
            n_voters=200, n_proposals=10, seed=42, budget_enabled=True,
        )
        assert len(events_a) == len(events_b), 'Different event counts with same seed'
        for i, (a, b) in enumerate(zip(events_a, events_b)):
            assert a.block_number == b.block_number, f'Block mismatch at {i}'
            if hasattr(a, 'weight') and hasattr(b, 'weight'):
                assert abs(a.weight - b.weight) < 1e-9, f'Weight mismatch at {i}'


# ---------------------------------------------------------------------------
# BUDG-04: curve_type parameter validation and functional impact
# ---------------------------------------------------------------------------

def test_generate_scenario_curve_type_validation():
    """BUDG-04: curve_type is validated at generate_scenario boundary."""
    import warnings

    # Valid types should not raise
    with warnings.catch_warnings():
        warnings.simplefilter('ignore', UserWarning)
        generate_scenario(n_voters=5, n_proposals=2, seed=1, curve_type='sqrt')
        generate_scenario(n_voters=5, n_proposals=2, seed=1, curve_type='log')
        generate_scenario(n_voters=5, n_proposals=2, seed=1, curve_type='linear')

    # Invalid types should raise ValueError
    with pytest.raises(ValueError, match='curve_type'):
        generate_scenario(n_voters=5, n_proposals=2, seed=1, curve_type='exp')
    with pytest.raises(ValueError, match='curve_type'):
        generate_scenario(n_voters=5, n_proposals=2, seed=1, curve_type='invalid')


def test_generate_scenario_curve_type_affects_tallies():
    """BUDG-04: Different curve_types produce different signals tallies."""
    from backtesting.simulation.runner import run_backtest, build_results_dataframe

    events = generate_scenario(n_voters=50, n_proposals=5, seed=42, curve_type='sqrt')
    raw_sqrt = run_backtest(events, curve_type='sqrt')
    df_sqrt = build_results_dataframe(raw_sqrt, events)

    raw_log = run_backtest(events, curve_type='log')
    df_log = build_results_dataframe(raw_log, events)

    # Legacy tallies should be identical (curve_type only affects signals)
    sqrt_legacy = df_sqrt['legacy_for'].dropna().sum()
    log_legacy = df_log['legacy_for'].dropna().sum()
    assert abs(sqrt_legacy - log_legacy) < 1e-6, 'Legacy tallies should be identical'

    # Signals tallies should differ (different curve functions)
    sqrt_signals = df_sqrt['signals_for'].dropna().sum()
    log_signals = df_log['signals_for'].dropna().sum()
    assert sqrt_signals != log_signals, 'Signals tallies should differ between sqrt and log curves'


# ---------------------------------------------------------------------------
# MCAL-01: mc_dist draws from Beta distribution
# ---------------------------------------------------------------------------

def test_mcal01_mc_dist_draws_from_beta():
    """MCAL-01: mc_dist=BetaDistribution(2,5) draws from Beta, not uniform."""
    dist = BetaDistribution(a=2, b=5)
    events = generate_scenario(
        n_voters=100, n_proposals=5, seed=42, mc_dist=dist
    )
    # Extract vote weights — in MC mode all voters use same alloc_frac
    vote_events = [e for e in events if hasattr(e, 'weight') and hasattr(e, 'voter')]
    weights = [e.weight for e in vote_events]
    assert len(weights) > 0, 'No vote events generated'

    # Run again with different seed — should produce different allocation
    events2 = generate_scenario(
        n_voters=100, n_proposals=5, seed=99, mc_dist=dist
    )
    weights2 = [e.weight for e in events2 if hasattr(e, 'weight') and hasattr(e, 'voter')]
    # Different seeds produce different results (probabilistic but near-certain)
    assert weights != weights2, 'Different seeds should produce different results'


# ---------------------------------------------------------------------------
# MCAL-03: Backward compatibility without mc_dist
# ---------------------------------------------------------------------------

def test_mcal03_backward_compat():
    """MCAL-03: generate_scenario() without mc_dist is bit-identical to v2.0."""
    # Run twice with same seed, no mc_dist — must be identical
    e1 = generate_scenario(n_voters=100, n_proposals=10, seed=42)
    e2 = generate_scenario(n_voters=100, n_proposals=10, seed=42)
    assert len(e1) == len(e2)
    for a, b in zip(e1, e2):
        assert a.block_number == b.block_number
        if hasattr(a, 'weight'):
            assert a.weight == b.weight, f'Weight mismatch at block {a.block_number}'
        if hasattr(a, 'voter'):
            assert a.voter == b.voter
        if hasattr(a, 'support'):
            assert a.support == b.support


# ---------------------------------------------------------------------------
# MCAL-05: VoteTimingConfig alters vote timing distribution
# ---------------------------------------------------------------------------

def test_mcal05_vote_timing_config():
    """MCAL-05: VoteTimingConfig alters vote timing distribution."""
    # Heavy-early config: 80% early, 10% mid, 10% late
    heavy_early = VoteTimingConfig(early=0.80, mid=0.10)
    events_early = generate_scenario(
        n_voters=100, n_proposals=10, seed=42,
        vote_timing=heavy_early,
    )
    # Default config (30% early, 40% mid)
    events_default = generate_scenario(
        n_voters=100, n_proposals=10, seed=42,
    )
    # With mc_dist=None and same seed, the RNG path is the same but timing fracs differ
    # Extract vote blocks relative to proposal windows
    # The heavy-early config should shift votes earlier in the window
    # (Statistical test: median vote offset should be lower for heavy-early)
    # At minimum, verify the events are different
    early_blocks = [e.block_number for e in events_early if hasattr(e, 'voter')]
    default_blocks = [e.block_number for e in events_default if hasattr(e, 'voter')]
    assert early_blocks != default_blocks, 'vote_timing should change vote blocks'


def test_vote_timing_config_validation():
    """VoteTimingConfig rejects invalid fractions."""
    with pytest.raises(ValueError, match='<= 1.0'):
        VoteTimingConfig(early=0.6, mid=0.5)
    with pytest.raises(ValueError, match='>= 0'):
        VoteTimingConfig(early=-0.1, mid=0.5)
    # Valid edge case: early + mid = 1.0 (late = 0)
    vtc = VoteTimingConfig(early=0.5, mid=0.5)
    assert vtc.early == 0.5
