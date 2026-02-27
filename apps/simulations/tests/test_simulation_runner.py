"""
Unit tests for cadCAD simulation runner components — SIM-01 through SIM-08.

SIM-01 and SIM-08 require a running cadCAD simulation (runner.py from Plan 02)
and are marked skip. SIM-02 through SIM-07 are pure unit tests of policies.py
and sufs.py that run without cadCAD.
"""
import pytest

from backtesting.simulation.policies import policy_event_replay
from backtesting.simulation.sufs import suf_step, suf_tallies
from backtesting.weighting.signals import compute_signals_weight


# ---------------------------------------------------------------------------
# Shared test data — module-level so unit tests can use directly without pytest
# ---------------------------------------------------------------------------

minimal_event_records = [
    {
        'event_type': 'PROPOSAL_CREATED',
        'proposal_id': 'p1',
        'block_number': 100,
        'voter': None,
        'support': None,
        'weight': None,
        'lock_duration_days': None,
    },
    {
        'event_type': 'VOTE_CAST',
        'proposal_id': 'p1',
        'block_number': 110,
        'voter': '0xA',
        'support': 'FOR',
        'weight': 1000.0,
        'lock_duration_days': 90.0,
    },
    {
        'event_type': 'VOTE_CAST',
        'proposal_id': 'p1',
        'block_number': 120,
        'voter': '0xB',
        'support': 'AGAINST',
        'weight': 500.0,
        'lock_duration_days': 0.0,
    },
    {
        'event_type': 'VOTE_CAST',
        'proposal_id': 'p1',
        'block_number': 130,
        'voter': '0xC',
        'support': 'ABSTAIN',
        'weight': 200.0,
        'lock_duration_days': 365.0,
    },
    {
        'event_type': 'PROPOSAL_FINALIZED',
        'proposal_id': 'p1',
        'block_number': 200,
        'voter': None,
        'support': None,
        'weight': None,
        'lock_duration_days': None,
    },
]


# ---------------------------------------------------------------------------
# Helper: minimal initial tallies state for p1
# ---------------------------------------------------------------------------

def _make_prev_state_with_p1():
    """Return a prev_state dict with p1 initialized in tallies."""
    return {
        'step': 0,
        'tallies': {
            'p1': {
                'legacy': {'FOR': 0.0, 'AGAINST': 0.0, 'ABSTAIN': 0.0},
                'signals': {'FOR': 0.0, 'AGAINST': 0.0, 'ABSTAIN': 0.0},
            }
        },
    }


# ---------------------------------------------------------------------------
# SIM-01 — requires runner.py (Plan 02)
# ---------------------------------------------------------------------------

@pytest.mark.skip(reason='requires runner.py — implemented in Plan 02')
def test_sim01_no_errors():
    """Full cadCAD simulation runs without errors end-to-end."""
    pass


# ---------------------------------------------------------------------------
# SIM-02 — policy reads event by step index
# ---------------------------------------------------------------------------

def test_sim02_policy_reads_by_step():
    """policy_event_replay returns the event at index prev_state['step']."""
    stream = tuple(minimal_event_records)
    params = {'event_stream': stream}

    # step=1 — first VOTE_CAST
    result = policy_event_replay(params, 0, [], {'step': 1})
    assert result == {'event': minimal_event_records[1]}

    # step=0 — PROPOSAL_CREATED
    result = policy_event_replay(params, 0, [], {'step': 0})
    assert result == {'event': minimal_event_records[0]}

    # step past end — returns None event
    result = policy_event_replay(params, 0, [], {'step': 99})
    assert result == {'event': None}


# ---------------------------------------------------------------------------
# SIM-03 — event dispatch correctness
# ---------------------------------------------------------------------------

def test_sim03_event_dispatch():
    """suf_tallies dispatches PROPOSAL_CREATED, VOTE_CAST, PROPOSAL_FINALIZED."""
    empty_state = {'step': 0, 'tallies': {}}

    # PROPOSAL_CREATED — creates p1 key with both sub-dicts initialized to 0.0
    created_evt = {'event_type': 'PROPOSAL_CREATED', 'proposal_id': 'p1'}
    key, tallies = suf_tallies({}, 0, [], empty_state, {'event': created_evt})
    assert key == 'tallies'
    assert 'p1' in tallies
    assert 'legacy' in tallies['p1']
    assert 'signals' in tallies['p1']
    assert tallies['p1']['legacy'] == {'FOR': 0.0, 'AGAINST': 0.0, 'ABSTAIN': 0.0}
    assert tallies['p1']['signals'] == {'FOR': 0.0, 'AGAINST': 0.0, 'ABSTAIN': 0.0}

    # VOTE_CAST — FOR totals increased
    prev_state_with_p1 = _make_prev_state_with_p1()
    vote_evt = minimal_event_records[1]  # FOR, 1000.0 stake, 90 days
    key, tallies_after_vote = suf_tallies({}, 0, [], prev_state_with_p1, {'event': vote_evt})
    assert tallies_after_vote['p1']['legacy']['FOR'] > 0.0
    assert tallies_after_vote['p1']['signals']['FOR'] > 0.0

    # PROPOSAL_FINALIZED — tallies pass through unchanged (same values, new object)
    finalized_evt = minimal_event_records[4]
    prev_finalize = {'step': 4, 'tallies': tallies_after_vote}
    tallies_before_values = {
        'legacy_for': tallies_after_vote['p1']['legacy']['FOR'],
        'signals_for': tallies_after_vote['p1']['signals']['FOR'],
    }
    key, tallies_finalized = suf_tallies({}, 0, [], prev_finalize, {'event': finalized_evt})
    # Values unchanged
    assert tallies_finalized['p1']['legacy']['FOR'] == tallies_before_values['legacy_for']
    assert tallies_finalized['p1']['signals']['FOR'] == tallies_before_values['signals_for']
    # Different object (deepcopy)
    assert id(tallies_finalized) != id(tallies_after_vote)


# ---------------------------------------------------------------------------
# SIM-04 — legacy tally accumulates raw stake
# ---------------------------------------------------------------------------

def test_sim04_legacy_tally():
    """suf_tallies accumulates raw stake for legacy weight (identity function)."""
    prev_state = _make_prev_state_with_p1()
    vote_evt = {
        'event_type': 'VOTE_CAST',
        'proposal_id': 'p1',
        'support': 'FOR',
        'weight': 1000.0,
        'lock_duration_days': 90.0,
    }
    _, tallies = suf_tallies({}, 0, [], prev_state, {'event': vote_evt})

    assert tallies['p1']['legacy']['FOR'] == 1000.0
    assert tallies['p1']['legacy']['AGAINST'] == 0.0
    assert tallies['p1']['legacy']['ABSTAIN'] == 0.0


# ---------------------------------------------------------------------------
# SIM-05 — signals tally applies commitment weighting
# ---------------------------------------------------------------------------

def test_sim05_signals_tally():
    """suf_tallies applies lock curve for signals weight."""
    prev_state = _make_prev_state_with_p1()

    # Partial lock — signals weight < stake
    vote_evt_partial = {
        'event_type': 'VOTE_CAST',
        'proposal_id': 'p1',
        'support': 'FOR',
        'weight': 1000.0,
        'lock_duration_days': 90.0,
    }
    _, tallies_partial = suf_tallies({}, 0, [], prev_state, {'event': vote_evt_partial})
    signals_for_partial = tallies_partial['p1']['signals']['FOR']
    expected = compute_signals_weight(1000.0, 90.0)
    assert abs(signals_for_partial - expected) < 1e-9
    assert signals_for_partial < 1000.0  # partial lock reduces weight

    # Full lock (365 days) — signals weight == stake
    prev_state_2 = _make_prev_state_with_p1()
    vote_evt_full = {
        'event_type': 'VOTE_CAST',
        'proposal_id': 'p1',
        'support': 'FOR',
        'weight': 1000.0,
        'lock_duration_days': 365.0,
    }
    _, tallies_full = suf_tallies({}, 0, [], prev_state_2, {'event': vote_evt_full})
    signals_for_full = tallies_full['p1']['signals']['FOR']
    assert abs(signals_for_full - 1000.0) < 1e-9


# ---------------------------------------------------------------------------
# SIM-06 — dual tally present after VOTE_CAST
# ---------------------------------------------------------------------------

def test_sim06_dual_tally_present():
    """After VOTE_CAST, both legacy and signals dicts are present with correct keys."""
    prev_state = _make_prev_state_with_p1()
    vote_evt = {
        'event_type': 'VOTE_CAST',
        'proposal_id': 'p1',
        'support': 'FOR',
        'weight': 500.0,
        'lock_duration_days': 90.0,  # partial lock
    }
    _, tallies = suf_tallies({}, 0, [], prev_state, {'event': vote_evt})

    # Both sub-dicts present
    assert 'legacy' in tallies['p1']
    assert 'signals' in tallies['p1']

    # Both have all three support keys
    for side in ('legacy', 'signals'):
        assert 'FOR' in tallies['p1'][side]
        assert 'AGAINST' in tallies['p1'][side]
        assert 'ABSTAIN' in tallies['p1'][side]

    # FOR values differ between legacy and signals for partial-lock voter
    assert tallies['p1']['legacy']['FOR'] != tallies['p1']['signals']['FOR']


# ---------------------------------------------------------------------------
# SIM-07 — no mutation of prev_state (deepcopy guarantee)
# ---------------------------------------------------------------------------

def test_sim07_no_mutation():
    """suf_tallies returns a new dict and never mutates prev_state['tallies']."""
    prev_state = _make_prev_state_with_p1()
    original_tallies = prev_state['tallies']
    id_before = id(original_tallies)

    vote_evt = {
        'event_type': 'VOTE_CAST',
        'proposal_id': 'p1',
        'support': 'FOR',
        'weight': 100.0,
        'lock_duration_days': 60.0,
    }
    result = suf_tallies({}, 0, [], prev_state, {'event': vote_evt})
    key, new_tallies = result
    id_after = id(new_tallies)

    # Different object returned
    assert id_before != id_after

    # Mutate returned tallies — prev_state must be unaffected
    new_tallies['p1']['legacy']['FOR'] = 999999.0
    assert prev_state['tallies']['p1']['legacy']['FOR'] == 0.0


# ---------------------------------------------------------------------------
# SIM-08 — requires runner.py (Plan 02)
# ---------------------------------------------------------------------------

@pytest.mark.skip(reason='requires runner.py — implemented in Plan 02')
def test_sim08_results_dataframe():
    """build_results_dataframe produces a DataFrame with expected shape."""
    pass
