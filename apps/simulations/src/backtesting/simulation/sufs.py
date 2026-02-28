"""State update functions (SUFs) for cadCAD event-replay simulation."""
import copy
from typing import Any

from backtesting.weighting.signals import compute_legacy_weight, compute_signals_weight
from backtesting.simulation.policies import policy_event_replay


def suf_step(
    params: dict[str, Any],
    substep: int,
    state_history: list[dict[str, Any]],
    prev_state: dict[str, Any],
    policy_input: dict[str, Any],
) -> tuple[str, int]:
    """Increment the step counter by 1."""
    return ('step', prev_state['step'] + 1)


def suf_tallies(
    params: dict[str, Any],
    substep: int,
    state_history: list[dict[str, Any]],
    prev_state: dict[str, Any],
    policy_input: dict[str, Any],
) -> tuple[str, dict]:
    """Update vote tallies based on the current event.

    Always returns a deepcopy of tallies — never mutates prev_state.
    """
    evt = policy_input['event']
    tallies = copy.deepcopy(prev_state['tallies'])

    if evt is None:
        return ('tallies', tallies)

    etype = evt.get('event_type')

    if etype == 'PROPOSAL_CREATED':
        tallies[evt['proposal_id']] = {
            'legacy': {'FOR': 0.0, 'AGAINST': 0.0, 'ABSTAIN': 0.0},
            'signals': {'FOR': 0.0, 'AGAINST': 0.0, 'ABSTAIN': 0.0},
        }

    elif etype == 'VOTE_CAST':
        pid = evt.get('proposal_id')
        support = evt.get('support')
        stake = float(evt.get('weight', 0.0))
        lock_days = float(evt.get('lock_duration_days') or 0.0)

        curve_type = params.get('curve_type', 'sqrt')
        floor = params.get('floor', 0.1)
        if pid in tallies and support in ('FOR', 'AGAINST', 'ABSTAIN'):
            tallies[pid]['legacy'][support] += compute_legacy_weight(stake)
            tallies[pid]['signals'][support] += compute_signals_weight(stake, lock_days, curve_type=curve_type, floor=floor)

    elif etype == 'PROPOSAL_FINALIZED':
        # No change — deepcopy passthrough
        pass

    return ('tallies', tallies)


PSUBS = [
    {
        'policies': {'event_replay': policy_event_replay},
        'variables': {'step': suf_step, 'tallies': suf_tallies},
    }
]
