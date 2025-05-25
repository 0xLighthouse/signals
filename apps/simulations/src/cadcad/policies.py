from dataclasses import asdict
from typing import Dict, List, Tuple, Any, Optional, Set
from datetime import datetime, timedelta
import uuid
from .state import State, Initiative, Support
import random


def submit_initiative(params: Dict, step: int, sL: List, s: Dict) -> Dict:
    """Add a new initiative to the system."""
    state = State(**s)  # Convert dict to State object
    initiative_id = str(uuid.uuid4())
    initiative = Initiative(
        id=initiative_id, title=params["title"], description=params["description"], created_at=state.current_time
    )
    state.initiatives[initiative_id] = initiative
    return asdict(state)


def support_initiative(params: Dict, step: int, sL: List, s: Dict) -> Dict:
    """User stakes tokens to support an initiative."""
    state = State(**s)  # Convert dict to State object
    user_id = params["user_id"]
    initiative_id = params["initiative_id"]
    amount = params["amount"]
    duration = params["duration"]

    # If initiative_id is None, support the most recently created initiative
    if initiative_id is None:
        if state.initiatives:
            # Get the most recently created initiative
            initiative_id = max(state.initiatives, key=lambda k: state.initiatives[k].created_at)
        else:
            raise ValueError("No initiatives exist to support")

    if initiative_id not in state.initiatives:
        raise ValueError(f"Initiative {initiative_id} does not exist")

    # Create or update support
    support = Support(
        amount=amount,
        lock_duration=duration,
        start_time=state.current_time,
        weight=amount * duration,  # W = T * D
    )

    state.supporters[(user_id, initiative_id)] = support
    state.initiatives[initiative_id].last_support_time = state.current_time
    state.update_initiative_weights()

    return asdict(state)


def decay_weights(params: Dict, step: int, sL: List, s: Dict) -> Dict:
    """Apply decay to all support weights."""
    state = State(**s)  # Convert dict to State object
    decay_type = params.get("decay_type", "exponential")

    for (user_id, initiative_id), support in state.supporters.items():
        epochs_passed = (state.current_time - support.start_time).days

        if decay_type == "linear":
            # Linear decay: cW = W - I * T * M
            decay = epochs_passed * support.amount * state.decay_multiplier
            support.weight = max(0, support.weight - decay)
        else:  # exponential
            # Exponential decay: cW = W * M^I
            support.weight = support.amount * support.lock_duration * (state.decay_multiplier**epochs_passed)

    state.update_initiative_weights()
    return asdict(state)


def check_acceptance(params: Dict, step: int, sL: List, s: Dict) -> Dict:
    """Check and accept initiatives that exceed the threshold."""
    state = State(**s)  # Convert dict to State object
    for initiative_id, initiative in state.initiatives.items():
        if initiative.weight >= state.acceptance_threshold and initiative_id not in state.accepted_initiatives:
            state.accepted_initiatives.add(initiative_id)
    return asdict(state)


def check_expiration(params: Dict, step: int, sL: List, s: Dict) -> Dict:
    """Expire initiatives with no recent support."""
    state = State(**s)  # Convert dict to State object
    current_time = state.current_time
    for initiative_id, initiative in state.initiatives.items():
        if initiative_id not in state.accepted_initiatives and initiative_id not in state.expired_initiatives:
            time_since_last_support = (current_time - initiative.last_support_time).days
            if time_since_last_support >= state.inactivity_period:
                state.expired_initiatives.add(initiative_id)
    return asdict(state)


def advance_block(_params, _step, _sL, s: Dict) -> Dict:
    """Policy function to advance the simulation by one epoch (one day)."""

    return {
        "current_epoch": s["current_epoch"] + 1,
        "current_time": s["current_time"] + timedelta(days=1),
    }


def p_create_initiative(
    params: Dict[str, Any], substep: int, state_history: List[Dict[str, Any]], previous_state: Dict[str, Any]
) -> Dict[str, Any]:
    """
    Policy for users creating new initiatives.
    A user might decide to create an initiative based on a probability.
    Requires a certain stake.
    """
    actions = []  # List of new initiative objects to be created

    # Example: Iterate through users, each has a chance to create an initiative
    # For simplicity, this example might have one user attempt per step, or select one user.
    # A more robust version would use `previous_state['balances'].keys()` for user_ids

    # This policy will be developed further.
    # For now, it returns an empty list of actions.
    return {"new_initiatives_actions": actions}


def p_support_initiative(
    params: Dict[str, Any], substep: int, state_history: List[Dict[str, Any]], previous_state: Dict[str, Any]
) -> Dict[str, Any]:
    """
    Policy for users supporting existing initiatives.
    A user might decide to support an initiative based on a probability,
    locking a certain amount of tokens for a chosen duration.
    """
    actions = []  # List of new support actions (e.g., dicts with support details)

    # Example: Iterate through users, each has a chance to support an active initiative.
    # This policy will be developed further.
    return {"new_support_actions": actions}


def p_apply_decay_to_supports(
    params: Dict[str, Any], substep: int, state_history: List[Dict[str, Any]], previous_state: Dict[str, Any]
) -> Dict[str, Any]:
    """
    Policy to apply decay to all active supports.
    This policy signals that decay should be applied. The SUF will handle the state change.
    Alternatively, this policy could return the set of supporters that had decay applied.
    """
    # The actual decay logic is in Support.decay() and will be called by a SUF.
    # This policy function can be simple, perhaps just triggering the SUF.
    # Or it can identify which supports to decay if not all are decayed every step.
    # For this setup, we'll assume a SUF handles iterating and decaying.
    # This policy might determine IF decay happens in this step, based on params.

    # For now, this policy doesn't need to output anything complex if SUF is comprehensive.
    return {"trigger_decay_application": True}


def p_check_initiative_status(
    params: Dict[str, Any], substep: int, state_history: List[Dict[str, Any]], previous_state: Dict[str, Any]
) -> Dict[str, Any]:
    """
    Policy to check initiatives for acceptance, expiration, and support lock expiration.
    """
    initiatives_to_accept: Set[str] = set()
    initiatives_to_expire: Set[str] = set()
    supports_to_unlock_details: List[Dict[str, Any]] = []  # e.g. [{'user_id':x, 'amount':y, 'support_key': (uid,iid)}]

    # Logic to iterate through initiatives and supports to determine status changes.
    # - Check acceptance_threshold
    # - Check support.expiry_epoch for lock expiration
    # This policy will be developed further.

    return {
        "initiatives_to_accept": initiatives_to_accept,
        "initiatives_to_expire": initiatives_to_expire,
        "supports_to_unlock_details": supports_to_unlock_details,
    }


def p_user_actions(
    params: Dict[str, Any], substep: int, state_history: List[Dict[str, Any]], previous_state: Dict[str, Any]
) -> Dict[str, List[Dict[str, Any]]]:
    """
    Policy to determine actions taken by users in a given timestep.
    Users can decide to create new initiatives or support existing ones.
    """
    current_epoch = previous_state["current_epoch"]
    user_ids = list(previous_state["balances"].keys())
    actions: List[Dict[str, Any]] = []

    random.shuffle(user_ids)

    for user_id in user_ids:
        if random.random() < params["prob_create_initiative"]:
            user_balance = previous_state["balances"].get(user_id, 0)
            creation_stake = params["initiative_creation_stake"]
            if user_balance >= creation_stake:
                actions.append(
                    {
                        "type": "create_initiative",
                        "user_id": user_id,
                        "title": f"Initiative by {user_id} at epoch {current_epoch}",
                        "description": f"A new idea proposed by {user_id}.",
                    }
                )

        if random.random() < params["prob_support_initiative"]:
            user_balance = previous_state["balances"].get(user_id, 0)
            if user_balance > 0:
                active_initiatives = {
                    init_id: init_obj
                    for init_id, init_obj in previous_state["initiatives"].items()
                    if init_id not in previous_state["accepted_initiatives"]
                    and init_id not in previous_state["expired_initiatives"]
                }
                if active_initiatives:
                    chosen_initiative_id = random.choice(list(active_initiatives.keys()))
                    max_tokens_to_lock = user_balance * params["max_support_tokens_fraction"]
                    tokens_to_lock = random.uniform(1, max_tokens_to_lock)
                    tokens_to_lock = max(1.0, min(tokens_to_lock, user_balance))
                    min_dur = params["min_lock_duration_epochs"]
                    max_dur = params["max_lock_duration_epochs"]
                    lock_duration = random.randint(min_dur, max_dur)
                    actions.append(
                        {
                            "type": "support_initiative",
                            "user_id": user_id,
                            "initiative_id": chosen_initiative_id,
                            "amount": tokens_to_lock,
                            "lock_duration_epochs": lock_duration,
                        }
                    )

    return {"user_actions": actions}


# We might add other policies here later, e.g., p_delegate_actions, etc.
# For now, p_user_actions is the main behavioral policy.


# A policy to signal that time should advance.
# While the SUF s_update_current_epoch will do the work, this policy can be explicit if needed
# or if other time-related policy decisions were to be made.
# For simplicity, often the time update SUF is just called directly without a specific policy output.
# However, to be explicit for now:
def p_advance_time(
    params: Dict[str, Any], substep: int, state_history: List[Dict[str, Any]], previous_state: Dict[str, Any]
) -> Dict[str, bool]:
    """
    Policy that signals the intent to advance time by one epoch.
    """
    return {"advance_epoch": True}
