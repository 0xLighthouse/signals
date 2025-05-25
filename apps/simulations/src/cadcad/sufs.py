import uuid
from datetime import datetime, timedelta
from typing import Dict, List, Any, Tuple, Set

# Import the dataclasses from state.py to properly cast and work with them
from .state import State, Initiative, Support


# Helper to reconstruct State object from dict, useful in SUFs
def get_state_obj(previous_state_dict: Dict[str, Any]) -> State:
    # cadCAD passes state as a dict. We need to reconstruct our State object
    # and its nested dataclasses if we want to use their methods.
    # This is a simplified version; a robust one would handle nested structures more deeply.
    # For now, we rely on the __init__ of State to handle dicts for initiatives/supporters if passed directly.

    # Create Initiative objects from dicts
    initiatives_dict_of_obj = {}
    for init_id, init_data in previous_state_dict.get("initiatives", {}).items():
        if isinstance(init_data, dict):  # If it's a dict, convert to Initiative object
            initiatives_dict_of_obj[init_id] = Initiative(**init_data)
        elif isinstance(
            init_data, Initiative
        ):  # If already an object (e.g. from previous SUF in same timestep)
            initiatives_dict_of_obj[init_id] = init_data
        else:
            raise TypeError(f"Unexpected type for initiative data: {type(init_data)}")

    # Create Support objects from dicts
    supporters_dict_of_obj = {}
    for sup_key_tuple, sup_data in previous_state_dict.get("supporters", {}).items():
        # Ensure sup_key_tuple is a tuple if it comes from JSON-like state in some cadCAD versions
        key = tuple(sup_key_tuple) if isinstance(sup_key_tuple, list) else sup_key_tuple
        if isinstance(sup_data, dict):
            # Filter out fields that have init=False to avoid passing them to __init__
            init_fields = {
                k: v
                for k, v in sup_data.items()
                if k not in ["initial_weight", "current_weight", "expiry_epoch"]
            }
            supporters_dict_of_obj[key] = Support(**init_fields)
        elif isinstance(sup_data, Support):
            supporters_dict_of_obj[key] = sup_data
        else:
            raise TypeError(f"Unexpected type for support data: {type(sup_data)}")

    # Create a new State instance, ensuring nested dicts are also appropriately handled or converted
    # The State.__init__ is designed to take kwargs, so this should mostly work.
    # However, for nested dataclasses within initiatives/supporters, explicit conversion is better.
    current_state_params = previous_state_dict.copy()
    current_state_params["initiatives"] = initiatives_dict_of_obj
    current_state_params["supporters"] = supporters_dict_of_obj

    # Ensure datetime is parsed correctly if it's a string
    if isinstance(current_state_params.get("current_time"), str):
        current_state_params["current_time"] = datetime.fromisoformat(
            current_state_params["current_time"]
        )

    return State(**current_state_params)


def s_update_current_epoch(
    params: Dict[str, Any],
    substep: int,
    state_history: List[Dict[str, Any]],
    previous_state: Dict[str, Any],
    policy_input: Dict[str, Any],
) -> Tuple[str, Any]:
    """Update the current epoch."""
    new_epoch = previous_state["current_epoch"] + 1
    return ("current_epoch", new_epoch)


def s_update_current_time(
    params: Dict[str, Any],
    substep: int,
    state_history: List[Dict[str, Any]],
    previous_state: Dict[str, Any],
    policy_input: Dict[str, Any],
) -> Tuple[str, Any]:
    """Update the current time."""
    # previous_state['current_time'] might be string if from initial state via __dict__
    current_time_dt = previous_state["current_time"]
    if isinstance(current_time_dt, str):
        current_time_dt = datetime.fromisoformat(current_time_dt)
    new_time = current_time_dt + timedelta(days=1)  # Assuming 1 epoch = 1 day
    return ("current_time", new_time.isoformat())


def s_apply_user_actions_initiatives(
    params: Dict[str, Any],
    substep: int,
    state_history: List[Dict[str, Any]],
    previous_state: Dict[str, Any],
    policy_input: Dict[str, Any],
) -> Tuple[str, Any]:
    """Apply user actions that affect initiatives."""
    state = get_state_obj(previous_state)
    actions = policy_input.get("user_actions", [])

    for action in actions:
        action_type = action.get("type")
        user_id = action.get("user_id")

        if action_type == "create_initiative":
            creation_stake = params["initiative_creation_stake"]
            if state.balances.get(user_id, 0) >= creation_stake:
                new_initiative_id = str(uuid.uuid4())
                initiative = Initiative(
                    id=new_initiative_id,
                    title=action.get("title", "Untitled Initiative"),
                    description=action.get("description", ""),
                    created_at=state.current_time,
                    last_support_epoch=state.current_epoch,
                )
                state.initiatives[new_initiative_id] = initiative

    # Convert dataclass objects to dictionaries for cadCAD compatibility
    initiatives_dict = {k: v.__dict__ for k, v in state.initiatives.items()}
    return ("initiatives", initiatives_dict)


def s_apply_user_actions_supporters(
    params: Dict[str, Any],
    substep: int,
    state_history: List[Dict[str, Any]],
    previous_state: Dict[str, Any],
    policy_input: Dict[str, Any],
) -> Tuple[str, Any]:
    """Apply user actions that affect supporters."""
    state = get_state_obj(previous_state)
    actions = policy_input.get("user_actions", [])

    for action in actions:
        action_type = action.get("type")
        user_id = action.get("user_id")

        if action_type == "support_initiative":
            initiative_id = action.get("initiative_id")
            amount = action.get("amount")
            lock_duration_epochs = action.get("lock_duration_epochs")

            if initiative_id in state.initiatives and state.balances.get(user_id, 0) >= amount:
                support_key = (user_id, initiative_id)
                support = Support(
                    user_id=user_id,
                    initiative_id=initiative_id,
                    amount=amount,
                    lock_duration_epochs=lock_duration_epochs,
                    start_epoch=state.current_epoch,
                )
                state.supporters[support_key] = support

                # Update initiative's last support epoch
                if initiative_id in state.initiatives:
                    state.initiatives[initiative_id].last_support_time = state.current_time
                    state.initiatives[initiative_id].last_support_epoch = state.current_epoch

    # Convert dataclass objects to dictionaries for cadCAD compatibility
    supporters_dict = {k: v.__dict__ for k, v in state.supporters.items()}
    return ("supporters", supporters_dict)


def s_apply_user_actions_balances(
    params: Dict[str, Any],
    substep: int,
    state_history: List[Dict[str, Any]],
    previous_state: Dict[str, Any],
    policy_input: Dict[str, Any],
) -> Tuple[str, Any]:
    """Apply user actions that affect balances."""
    state = get_state_obj(previous_state)
    actions = policy_input.get("user_actions", [])

    for action in actions:
        action_type = action.get("type")
        user_id = action.get("user_id")

        if action_type == "create_initiative":
            creation_stake = params["initiative_creation_stake"]
            if state.balances.get(user_id, 0) >= creation_stake:
                state.balances[user_id] -= creation_stake

        elif action_type == "support_initiative":
            initiative_id = action.get("initiative_id")
            amount = action.get("amount")

            if initiative_id in state.initiatives and state.balances.get(user_id, 0) >= amount:
                state.balances[user_id] -= amount

    return ("balances", state.balances)


def s_apply_user_actions_circulating_supply(
    params: Dict[str, Any],
    substep: int,
    state_history: List[Dict[str, Any]],
    previous_state: Dict[str, Any],
    policy_input: Dict[str, Any],
) -> Tuple[str, Any]:
    """Apply user actions that affect circulating supply."""
    state = get_state_obj(previous_state)
    actions = policy_input.get("user_actions", [])

    for action in actions:
        action_type = action.get("type")
        user_id = action.get("user_id")

        if action_type == "support_initiative":
            initiative_id = action.get("initiative_id")
            amount = action.get("amount")

            if initiative_id in state.initiatives and state.balances.get(user_id, 0) >= amount:
                state.circulating_supply -= amount  # Tokens are locked

    return ("circulating_supply", state.circulating_supply)


# Keep the original function for reference but rename it
def s_apply_user_actions_original(
    params: Dict[str, Any],
    substep: int,
    state_history: List[Dict[str, Any]],
    previous_state: Dict[str, Any],
    policy_input: Dict[str, Any],
) -> List[Tuple[str, Any]]:
    """Apply actions from users: creating initiatives and supporting initiatives."""
    state = get_state_obj(previous_state)  # Work with the State object
    actions = policy_input.get("user_actions", [])

    for action in actions:
        action_type = action.get("type")
        user_id = action.get("user_id")

        if action_type == "create_initiative":
            creation_stake = params["initiative_creation_stake"]
            if state.balances.get(user_id, 0) >= creation_stake:
                state.balances[user_id] -= creation_stake
                # state.circulating_supply -= creation_stake # If stake is burned or locked long-term

                new_initiative_id = str(uuid.uuid4())
                initiative = Initiative(
                    id=new_initiative_id,
                    title=action.get("title", "Untitled Initiative"),
                    description=action.get("description", ""),
                    created_at=state.current_time,  # Use datetime object from state
                    last_support_epoch=state.current_epoch,  # Initialized
                )
                state.initiatives[new_initiative_id] = initiative

        elif action_type == "support_initiative":
            initiative_id = action.get("initiative_id")
            amount = action.get("amount")
            lock_duration_epochs = action.get("lock_duration_epochs")

            if initiative_id in state.initiatives and state.balances.get(user_id, 0) >= amount:
                state.balances[user_id] -= amount
                state.circulating_supply -= amount  # Tokens are locked

                support_key = (user_id, initiative_id)
                # If user already supports this, this will overwrite. Paper implies unique ERC721 bonds.
                # For simplicity, one support entry per user per initiative for now.
                support = Support(
                    user_id=user_id,
                    initiative_id=initiative_id,
                    amount=amount,
                    lock_duration_epochs=lock_duration_epochs,
                    start_epoch=state.current_epoch,
                )
                state.supporters[support_key] = support

                # Update initiative's last support epoch
                if initiative_id in state.initiatives:
                    state.initiatives[
                        initiative_id
                    ].last_support_time = state.current_time  # Update datetime too
                    state.initiatives[initiative_id].last_support_epoch = state.current_epoch

    # Return the updated parts of the state as a list of tuples
    # cadCAD expects ('variable_name', new_value)
    # Convert dataclass objects to dictionaries for cadCAD compatibility
    initiatives_dict = {k: v.__dict__ for k, v in state.initiatives.items()}
    supporters_dict = {k: v.__dict__ for k, v in state.supporters.items()}

    return [
        ("initiatives", initiatives_dict),
        ("supporters", supporters_dict),
        ("balances", state.balances),
        ("circulating_supply", state.circulating_supply),
    ]


def s_apply_support_decay(
    params: Dict[str, Any],
    substep: int,
    state_history: List[Dict[str, Any]],
    previous_state: Dict[str, Any],
    policy_input: Dict[str, Any],
) -> Tuple[str, Any]:
    """Apply decay to the current_weight of all active supports."""
    state = get_state_obj(previous_state)
    decay_multiplier = params["decay_multiplier"]

    for support in state.supporters.values():
        if state.current_epoch < support.expiry_epoch:  # Only decay active, non-expired supports
            support.decay(decay_multiplier, state.current_epoch)

    # Convert dataclass objects to dictionaries for cadCAD compatibility
    supporters_dict = {k: v.__dict__ for k, v in state.supporters.items()}
    return ("supporters", supporters_dict)


def s_update_initiative_aggregate_weights(
    params: Dict[str, Any],
    substep: int,
    state_history: List[Dict[str, Any]],
    previous_state: Dict[str, Any],
    policy_input: Dict[str, Any],
) -> Tuple[str, Any]:
    """Recalculate the total weight for each initiative based on its current supports."""
    state = get_state_obj(previous_state)
    state.update_initiative_weights()  # This method is in the State class
    # Convert dataclass objects to dictionaries for cadCAD compatibility
    initiatives_dict = {k: v.__dict__ for k, v in state.initiatives.items()}
    return ("initiatives", initiatives_dict)


def s_process_initiative_and_support_lifecycles(
    params: Dict[str, Any],
    substep: int,
    state_history: List[Dict[str, Any]],
    previous_state: Dict[str, Any],
    policy_input: Dict[str, Any],
) -> List[Tuple[str, Any]]:
    """Handle initiative acceptance, support expiration, and initiative inactivity."""
    state = get_state_obj(previous_state)
    acceptance_threshold = params["acceptance_threshold"]
    inactivity_period = params["inactivity_period"]

    newly_accepted_initiatives_this_step: Set[str] = set()
    supports_to_remove: List[Tuple[str, str]] = []

    # 1. Check for Initiative Acceptance
    for init_id, initiative in list(
        state.initiatives.items()
    ):  # Use list for safe iteration if modifying
        if init_id not in state.accepted_initiatives and init_id not in state.expired_initiatives:
            if initiative.weight >= acceptance_threshold:
                state.accepted_initiatives.add(init_id)
                newly_accepted_initiatives_this_step.add(init_id)
                # Unlock all tokens for this accepted initiative
                for sup_key, support_obj in list(
                    state.supporters.items()
                ):  # Use list for safe iteration
                    if support_obj.initiative_id == init_id:
                        state.balances[support_obj.user_id] = (
                            state.balances.get(support_obj.user_id, 0) + support_obj.amount
                        )
                        state.circulating_supply += support_obj.amount
                        supports_to_remove.append(sup_key)

    # Remove supports for accepted initiatives
    for sup_key in supports_to_remove:
        if sup_key in state.supporters:
            del state.supporters[sup_key]
    supports_to_remove.clear()  # Reset for next section

    # 2. Check for Support Expiration (for non-accepted initiatives)
    for sup_key, support_obj in list(state.supporters.items()):  # Use list for safe iteration
        if (
            support_obj.initiative_id not in state.accepted_initiatives
        ):  # Only if initiative not already handled
            if state.current_epoch >= support_obj.expiry_epoch:
                state.balances[support_obj.user_id] = (
                    state.balances.get(support_obj.user_id, 0) + support_obj.amount
                )
                state.circulating_supply += support_obj.amount
                supports_to_remove.append(sup_key)

    # Remove expired supports
    for sup_key in supports_to_remove:
        if sup_key in state.supporters:
            del state.supporters[sup_key]

    # 3. Check for Initiative Expiration (Inactivity)
    for init_id, initiative in list(state.initiatives.items()):  # Use list for safe iteration
        if init_id not in state.accepted_initiatives and init_id not in state.expired_initiatives:
            # Check if initiative still has any active support after previous removals
            has_active_support = any(s.initiative_id == init_id for s in state.supporters.values())

            if not has_active_support and (
                state.current_epoch - initiative.last_support_epoch >= inactivity_period
            ):
                state.expired_initiatives.add(init_id)
            # Alternative: an initiative might expire if its weight is 0 for too long, even if last_support_epoch is recent
            # This would require tracking how long weight has been 0.
            # For now, using last_support_epoch and no active support is simpler.

    # Convert dataclass objects to dictionaries for cadCAD compatibility
    supporters_dict = {k: v.__dict__ for k, v in state.supporters.items()}

    return [
        ("accepted_initiatives", state.accepted_initiatives),
        ("expired_initiatives", state.expired_initiatives),
        ("supporters", supporters_dict),
        ("balances", state.balances),
        ("circulating_supply", state.circulating_supply),
    ]
