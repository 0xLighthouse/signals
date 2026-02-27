"""Policy functions for cadCAD event-replay simulation."""
from typing import Any


def policy_event_replay(
    params: dict[str, Any],
    substep: int,
    state_history: list[dict[str, Any]],
    prev_state: dict[str, Any],
) -> dict[str, Any]:
    """Read the next event from params['event_stream'] by step index.

    Returns {'event': evt} where evt is the event record dict at
    index prev_state['step'], or None if step is past end of stream.
    """
    step = prev_state['step']
    stream = params['event_stream']
    evt = stream[step] if step < len(stream) else None
    return {'event': evt}
