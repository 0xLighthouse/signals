import uuid
from datetime import datetime, timedelta
from typing import Dict, List, Any, Tuple, Set
import math

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
            # Also handle legacy field names
            init_fields = {}
            for k, v in sup_data.items():
                if k not in ["initial_weight", "current_weight", "expiry_epoch"]:
                    # Handle legacy field name mapping
                    if k == "creation_epoch":
                        init_fields["start_epoch"] = v
                    else:
                        init_fields[k] = v

            # Create the Support object
            support_obj = Support(**init_fields)

            # Preserve existing calculated fields if they exist in the data
            if "initial_weight" in sup_data:
                support_obj.initial_weight = sup_data["initial_weight"]
            if "current_weight" in sup_data:
                support_obj.current_weight = sup_data["current_weight"]
            if "expiry_epoch" in sup_data:
                support_obj.expiry_epoch = sup_data["expiry_epoch"]

            supporters_dict_of_obj[key] = support_obj
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

    # Debug: Show epoch transition and current state summary
    print(f"\n🕐 === EPOCH {new_epoch} STARTING ===")
    print(f"📈 Current state summary:")
    print(f"   - Initiatives: {len(previous_state.get('initiatives', {}))}")
    print(f"   - Supporters: {len(previous_state.get('supporters', {}))}")
    print(f"   - Accepted: {len(previous_state.get('accepted_initiatives', set()))}")
    print(f"   - Expired: {len(previous_state.get('expired_initiatives', set()))}")
    print(f"   - Circulating supply: {previous_state.get('circulating_supply', 0)}")

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
                print(
                    f"🆕 EPOCH {state.current_epoch}: User {user_id} created initiative '{initiative.title}' (ID: {new_initiative_id[:8]}...)"
                )

    # Convert dataclass objects to dictionaries for cadCAD compatibility
    initiatives_dict = {k: v.__dict__ for k, v in state.initiatives.items()}
    print(
        f"📊 EPOCH {state.current_epoch}: Total initiatives after creation: {len(initiatives_dict)}"
    )
    return ("initiatives", initiatives_dict)


def calculate_support_reward(
    params: Dict[str, Any],
    initiative: Initiative,
    support: Support,
    current_epoch: int,
    initiative_weight: float,
) -> float:
    """
    Calculate reward using a sigmoid function based on initiative weight.
    Higher rewards for early/risky supporters, smoothly decreasing as initiative gains support.

    Args:
        params: Simulation parameters
        initiative: The initiative being supported
        support: The support action
        current_epoch: Current simulation epoch
        initiative_weight: Current total weight of the initiative

    Returns:
        float: Reward amount to apply
    """
    if not params.get("reward_enabled", False):
        return 0.0

    # Calculate weight percentage relative to acceptance threshold
    weight_percentage = initiative_weight / params["acceptance_threshold"]

    # Sigmoid function to calculate reward rate
    # f(x) = min_rate + (max_rate - min_rate) / (1 + e^(steepness * (x - midpoint)))
    x = weight_percentage
    steepness = params["reward_steepness"]
    midpoint = params["reward_midpoint"]
    min_rate = params["min_reward_rate"]
    max_rate = params["max_reward_rate"]

    # Calculate reward rate using sigmoid
    reward_rate = min_rate + (max_rate - min_rate) / (1 + math.exp(steepness * (x - midpoint)))

    # Calculate final reward
    reward = support.amount * reward_rate

    return reward


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
                # Calculate initiative weight before new support
                initiative = state.initiatives[initiative_id]
                current_weight = state.get_initiative_weight(initiative_id)

                # Create support object
                support_key = (user_id, initiative_id)
                support = Support(
                    user_id=user_id,
                    initiative_id=initiative_id,
                    amount=amount,
                    lock_duration_epochs=lock_duration_epochs,
                    start_epoch=state.current_epoch,
                )

                # Calculate and apply reward if enabled
                reward = 0.0
                if params.get("reward_enabled", False):
                    reward = calculate_support_reward(
                        params, initiative, support, state.current_epoch, current_weight
                    )
                    if reward > 0:
                        # Add reward to user's balance
                        state.balances[user_id] = state.balances.get(user_id, 0) + reward
                        state.circulating_supply += reward

                        # Record the reward with detailed information
                        state.record_reward(
                            user_id=user_id,
                            amount=reward,
                            initiative_id=initiative_id,
                            initiative_weight=current_weight,
                            support_amount=amount,
                            lock_duration=lock_duration_epochs,
                        )

                        # Log detailed reward information
                        weight_percentage = current_weight / params["acceptance_threshold"]
                        print(
                            f"🎁 EPOCH {state.current_epoch}: User {user_id} received {reward:.2f} reward tokens"
                            f" (support: {amount:.2f}, lock: {lock_duration_epochs}h,"
                            f" weight: {weight_percentage:.1%}, total earned: {state.reward_earnings.get(user_id, 0):.2f})"
                        )

                # Add the support
                state.supporters[support_key] = support
                # Combined support and reward log
                print(
                    f"💰 EPOCH {state.current_epoch}: User {user_id} supported initiative {initiative_id[:8]}... with {amount:.2f} tokens for {lock_duration_epochs} epochs and received {reward:.2f} reward tokens."
                )

                # Update initiative's last support epoch
                if initiative_id in state.initiatives:
                    state.initiatives[initiative_id].last_support_time = state.current_time
                    state.initiatives[initiative_id].last_support_epoch = state.current_epoch

    # Convert dataclass objects to dictionaries for cadCAD compatibility
    supporters_dict = {k: v.__dict__ for k, v in state.supporters.items()}
    print(f"🤝 EPOCH {state.current_epoch}: Total supporters after actions: {len(supporters_dict)}")
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

    print(
        f"🔍 EPOCH {state.current_epoch}: Decay SUF - received {len(state.initiatives)} initiatives"
    )

    active_supports_count = 0
    for support in state.supporters.values():
        if state.current_epoch < support.expiry_epoch:  # Only decay active, non-expired supports
            old_weight = support.current_weight
            support.decay(decay_multiplier, state.current_epoch)
            active_supports_count += 1

    if active_supports_count > 0:
        print(
            f"📉 EPOCH {state.current_epoch}: Applied decay (×{decay_multiplier}) to {active_supports_count} active supports"
        )

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

    # Debug: Show initiative weights
    if state.initiatives:
        print(f"⚖️  EPOCH {state.current_epoch}: Initiative weights updated:")
        for init_id, initiative in state.initiatives.items():
            print(f"   Initiative {init_id[:8]}...: weight = {initiative.weight:.1f}")

    # Convert dataclass objects to dictionaries for cadCAD compatibility
    initiatives_dict = {k: v.__dict__ for k, v in state.initiatives.items()}
    return ("initiatives", initiatives_dict)


# Add separate SUFs for lifecycle management
def s_process_accepted_initiatives(
    params: Dict[str, Any],
    substep: int,
    state_history: List[Dict[str, Any]],
    previous_state: Dict[str, Any],
    policy_input: Dict[str, Any],
) -> Tuple[str, Any]:
    """Handle initiative acceptance."""
    state = get_state_obj(previous_state)
    acceptance_threshold = params["acceptance_threshold"]

    newly_accepted_initiatives_this_step: Set[str] = set()

    # Check for Initiative Acceptance
    for init_id, initiative in list(state.initiatives.items()):
        if init_id not in state.accepted_initiatives and init_id not in state.expired_initiatives:
            if initiative.weight >= acceptance_threshold:
                state.accepted_initiatives.add(init_id)
                newly_accepted_initiatives_this_step.add(init_id)
                print(
                    f"✅ EPOCH {state.current_epoch}: Initiative {init_id[:8]}... ACCEPTED! (weight: {initiative.weight:.1f} >= threshold: {acceptance_threshold})"
                )

    if newly_accepted_initiatives_this_step:
        print(
            f"🎉 EPOCH {state.current_epoch}: {len(newly_accepted_initiatives_this_step)} initiatives accepted this epoch"
        )

    return ("accepted_initiatives", state.accepted_initiatives)


def s_process_expired_initiatives(
    params: Dict[str, Any],
    substep: int,
    state_history: List[Dict[str, Any]],
    previous_state: Dict[str, Any],
    policy_input: Dict[str, Any],
) -> Tuple[str, Any]:
    """Handle initiative expiration due to inactivity."""
    state = get_state_obj(previous_state)
    inactivity_period = params["inactivity_period"]

    print(
        f"🔍 EPOCH {state.current_epoch}: Expiration SUF - received {len(state.initiatives)} initiatives"
    )

    newly_expired_initiatives = []

    # Check for Initiative Expiration (Inactivity)
    for init_id, initiative in list(state.initiatives.items()):
        if init_id not in state.accepted_initiatives and init_id not in state.expired_initiatives:
            # Check if initiative still has any active support
            has_active_support = any(s.initiative_id == init_id for s in state.supporters.values())
            epochs_since_last_support = state.current_epoch - initiative.last_support_epoch

            print(
                f"🔍 EPOCH {state.current_epoch}: Checking initiative {init_id[:8]}... - has_support: {has_active_support}, epochs_since_last: {epochs_since_last_support}, threshold: {inactivity_period}"
            )

            if not has_active_support and epochs_since_last_support >= inactivity_period:
                state.expired_initiatives.add(init_id)
                newly_expired_initiatives.append(init_id)
                print(
                    f"❌ EPOCH {state.current_epoch}: Initiative {init_id[:8]}... EXPIRED! (no support for {epochs_since_last_support} epochs >= {inactivity_period})"
                )

    if newly_expired_initiatives:
        print(
            f"💀 EPOCH {state.current_epoch}: {len(newly_expired_initiatives)} initiatives expired this epoch"
        )

    return ("expired_initiatives", state.expired_initiatives)


def s_process_support_lifecycle_balances(
    params: Dict[str, Any],
    substep: int,
    state_history: List[Dict[str, Any]],
    previous_state: Dict[str, Any],
    policy_input: Dict[str, Any],
) -> Tuple[str, Any]:
    """Handle token unlocking for accepted initiatives and expired supports."""
    state = get_state_obj(previous_state)
    acceptance_threshold = params["acceptance_threshold"]

    # 1. Unlock tokens for accepted initiatives
    for init_id, initiative in list(state.initiatives.items()):
        if init_id not in state.accepted_initiatives and init_id not in state.expired_initiatives:
            if initiative.weight >= acceptance_threshold:
                # Unlock all tokens for this accepted initiative
                for sup_key, support_obj in list(state.supporters.items()):
                    if support_obj.initiative_id == init_id:
                        state.balances[support_obj.user_id] = (
                            state.balances.get(support_obj.user_id, 0) + support_obj.amount
                        )

    # 2. Unlock tokens for expired supports (for non-accepted initiatives)
    for sup_key, support_obj in list(state.supporters.items()):
        if support_obj.initiative_id not in state.accepted_initiatives:
            if state.current_epoch >= support_obj.expiry_epoch:
                state.balances[support_obj.user_id] = (
                    state.balances.get(support_obj.user_id, 0) + support_obj.amount
                )

    return ("balances", state.balances)


def s_process_support_lifecycle_circulating_supply(
    params: Dict[str, Any],
    substep: int,
    state_history: List[Dict[str, Any]],
    previous_state: Dict[str, Any],
    policy_input: Dict[str, Any],
) -> Tuple[str, Any]:
    """Handle circulating supply updates for accepted initiatives and expired supports."""
    state = get_state_obj(previous_state)
    acceptance_threshold = params["acceptance_threshold"]

    # 1. Unlock tokens for accepted initiatives
    for init_id, initiative in list(state.initiatives.items()):
        if init_id not in state.accepted_initiatives and init_id not in state.expired_initiatives:
            if initiative.weight >= acceptance_threshold:
                # Unlock all tokens for this accepted initiative
                for sup_key, support_obj in list(state.supporters.items()):
                    if support_obj.initiative_id == init_id:
                        state.circulating_supply += support_obj.amount

    # 2. Unlock tokens for expired supports (for non-accepted initiatives)
    for sup_key, support_obj in list(state.supporters.items()):
        if support_obj.initiative_id not in state.accepted_initiatives:
            if state.current_epoch >= support_obj.expiry_epoch:
                state.circulating_supply += support_obj.amount

    return ("circulating_supply", state.circulating_supply)


def s_process_support_lifecycle_supporters(
    params: Dict[str, Any],
    substep: int,
    state_history: List[Dict[str, Any]],
    previous_state: Dict[str, Any],
    policy_input: Dict[str, Any],
) -> Tuple[str, Any]:
    """Handle support removal for accepted initiatives and expired supports."""
    state = get_state_obj(previous_state)
    acceptance_threshold = params["acceptance_threshold"]

    supports_to_remove: List[Tuple[str, str]] = []
    supports_removed_for_acceptance = 0
    supports_removed_for_expiry = 0

    # 1. Remove supports for accepted initiatives
    for init_id, initiative in list(state.initiatives.items()):
        if init_id not in state.accepted_initiatives and init_id not in state.expired_initiatives:
            if initiative.weight >= acceptance_threshold:
                # Remove all supports for this accepted initiative
                for sup_key, support_obj in list(state.supporters.items()):
                    if support_obj.initiative_id == init_id:
                        supports_to_remove.append(sup_key)
                        supports_removed_for_acceptance += 1

    # 2. Remove expired supports (for non-accepted initiatives)
    for sup_key, support_obj in list(state.supporters.items()):
        if support_obj.initiative_id not in state.accepted_initiatives:
            if state.current_epoch >= support_obj.expiry_epoch:
                supports_to_remove.append(sup_key)
                supports_removed_for_expiry += 1

    # Remove the supports
    for sup_key in supports_to_remove:
        if sup_key in state.supporters:
            del state.supporters[sup_key]

    if supports_removed_for_acceptance > 0:
        print(
            f"🔓 EPOCH {state.current_epoch}: Removed {supports_removed_for_acceptance} supports for accepted initiatives"
        )
    if supports_removed_for_expiry > 0:
        print(
            f"⏰ EPOCH {state.current_epoch}: Removed {supports_removed_for_expiry} expired supports"
        )

    # Convert dataclass objects to dictionaries for cadCAD compatibility
    supporters_dict = {k: v.__dict__ for k, v in state.supporters.items()}
    print(
        f"🤝 EPOCH {state.current_epoch}: Supporters remaining after lifecycle: {len(supporters_dict)}"
    )
    return ("supporters", supporters_dict)


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
