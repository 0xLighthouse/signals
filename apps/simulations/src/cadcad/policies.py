from typing import Dict, List, Tuple
from datetime import datetime, timedelta
import uuid
from .state import State, Initiative, Support


def submit_initiative(params, step, sL, s):
    """Add a new initiative to the system."""
    # In cadCAD, s is a dictionary representing the state
    state_dict = s
    
    # Convert the dictionary state to a State object
    state = State(
        current_epoch=state_dict['current_epoch'],
        current_time=state_dict['current_time'],
        initiatives=state_dict['initiatives'],
        accepted_initiatives=state_dict['accepted_initiatives'],
        expired_initiatives=state_dict['expired_initiatives'],
        supporters=state_dict['supporters'],
        acceptance_threshold=state_dict['acceptance_threshold'],
        inactivity_period=state_dict['inactivity_period'],
        decay_multiplier=state_dict['decay_multiplier']
    )
    
    initiative_id = str(uuid.uuid4())
    # Default values for simulation
    title = params.get("title", f"Initiative {initiative_id[:8]}")
    description = params.get("description", f"Auto-generated initiative {initiative_id[:8]}")
    
    initiative = Initiative(
        id=initiative_id, title=title, description=description, created_at=state.current_time
    )
    state.initiatives[initiative_id] = initiative
    
    # Update the dictionary state with our changes
    state_dict['initiatives'] = state.initiatives
    
    return state_dict


def support_initiative(params, step, sL, s):
    """User stakes tokens to support an initiative."""
    # In cadCAD, s is a dictionary representing the state
    state_dict = s
    
    # Convert the dictionary state to a State object
    state = State(
        current_epoch=state_dict['current_epoch'],
        current_time=state_dict['current_time'],
        initiatives=state_dict['initiatives'],
        accepted_initiatives=state_dict['accepted_initiatives'],
        expired_initiatives=state_dict['expired_initiatives'],
        supporters=state_dict['supporters'],
        acceptance_threshold=state_dict['acceptance_threshold'],
        inactivity_period=state_dict['inactivity_period'],
        decay_multiplier=state_dict['decay_multiplier']
    )
    
    # Default values for simulation
    user_id = params.get("user_id", f"user_{str(uuid.uuid4())[:8]}")
    
    # If no initiative_id is specified, pick the first one or create a new one
    initiative_id = params.get("initiative_id")
    if not initiative_id:
        if state.initiatives:
            initiative_id = list(state.initiatives.keys())[0]
        else:
            # Just return the state without changes if no initiatives exist
            return state_dict
    
    # Default amount and duration
    amount = params.get("amount", 100.0)
    duration = params.get("duration", 30)

    if initiative_id not in state.initiatives:
        # Just return the state without changes if initiative doesn't exist
        return state_dict

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

    # Update the dictionary state with our changes
    state_dict['supporters'] = state.supporters
    state_dict['initiatives'] = state.initiatives
    
    return state_dict


def decay_weights(params, step, sL, s):
    """Apply decay to all support weights."""
    # In cadCAD, s is a dictionary representing the state
    state_dict = s
    
    # Convert the dictionary state to a State object
    state = State(
        current_epoch=state_dict['current_epoch'],
        current_time=state_dict['current_time'],
        initiatives=state_dict['initiatives'],
        accepted_initiatives=state_dict['accepted_initiatives'],
        expired_initiatives=state_dict['expired_initiatives'],
        supporters=state_dict['supporters'],
        acceptance_threshold=state_dict['acceptance_threshold'],
        inactivity_period=state_dict['inactivity_period'],
        decay_multiplier=state_dict['decay_multiplier']
    )
    
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
    
    # Update the dictionary state with our changes
    state_dict['supporters'] = state.supporters
    state_dict['initiatives'] = state.initiatives
    
    return state_dict


def check_acceptance(params, step, sL, s):
    """Check and accept initiatives that exceed the threshold."""
    # In cadCAD, s is a dictionary representing the state
    state_dict = s
    
    # Convert the dictionary state to a State object
    state = State(
        current_epoch=state_dict['current_epoch'],
        current_time=state_dict['current_time'],
        initiatives=state_dict['initiatives'],
        accepted_initiatives=state_dict['accepted_initiatives'],
        expired_initiatives=state_dict['expired_initiatives'],
        supporters=state_dict['supporters'],
        acceptance_threshold=state_dict['acceptance_threshold'],
        inactivity_period=state_dict['inactivity_period'],
        decay_multiplier=state_dict['decay_multiplier']
    )
    
    for initiative_id, initiative in state.initiatives.items():
        if initiative.weight >= state.acceptance_threshold and initiative_id not in state.accepted_initiatives:
            state.accepted_initiatives.add(initiative_id)
    
    # Update the dictionary state with our changes
    state_dict['accepted_initiatives'] = state.accepted_initiatives
    
    return state_dict


def check_expiration(params, step, sL, s):
    """Expire initiatives with no recent support."""
    # In cadCAD, s is a dictionary representing the state
    state_dict = s
    
    # Convert the dictionary state to a State object
    state = State(
        current_epoch=state_dict['current_epoch'],
        current_time=state_dict['current_time'],
        initiatives=state_dict['initiatives'],
        accepted_initiatives=state_dict['accepted_initiatives'],
        expired_initiatives=state_dict['expired_initiatives'],
        supporters=state_dict['supporters'],
        acceptance_threshold=state_dict['acceptance_threshold'],
        inactivity_period=state_dict['inactivity_period'],
        decay_multiplier=state_dict['decay_multiplier']
    )
    
    current_time = state.current_time
    for initiative_id, initiative in state.initiatives.items():
        if initiative_id not in state.accepted_initiatives and initiative_id not in state.expired_initiatives:
            time_since_last_support = (current_time - initiative.last_support_time).days
            if time_since_last_support >= state.inactivity_period:
                state.expired_initiatives.add(initiative_id)
    
    # Update the dictionary state with our changes
    state_dict['expired_initiatives'] = state.expired_initiatives
    
    return state_dict


def advance_time(params, step, sL, s):
    """Advance the simulation time by one epoch."""
    # In cadCAD, s is a dictionary representing the state
    state_dict = s
    
    # Convert the dictionary state to a State object
    state = State(
        current_epoch=state_dict['current_epoch'],
        current_time=state_dict['current_time'],
        initiatives=state_dict['initiatives'],
        accepted_initiatives=state_dict['accepted_initiatives'],
        expired_initiatives=state_dict['expired_initiatives'],
        supporters=state_dict['supporters'],
        acceptance_threshold=state_dict['acceptance_threshold'],
        inactivity_period=state_dict['inactivity_period'],
        decay_multiplier=state_dict['decay_multiplier']
    )
    
    state.current_epoch += 1
    state.current_time += timedelta(days=1)
    
    # Update the dictionary state with our changes
    state_dict['current_epoch'] = state.current_epoch
    state_dict['current_time'] = state.current_time
    
    return state_dict
