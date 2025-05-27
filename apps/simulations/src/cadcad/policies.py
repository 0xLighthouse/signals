from typing import Dict, List, Any
import random


def p_user_actions(
    params: Dict[str, Any],
    substep: int,
    state_history: List[Dict[str, Any]],
    previous_state: Dict[str, Any],
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

    print(f"User actions generated: {len(actions)}")
    return {"user_actions": actions}


# We might add other policies here later, e.g., p_delegate_actions, etc.
# For now, p_user_actions is the main behavioral policy.


# A policy to signal that time should advance.
# While the SUF s_update_current_epoch will do the work, this policy can be explicit if needed
# or if other time-related policy decisions were to be made.
# For simplicity, often the time update SUF is just called directly without a specific policy output.
# However, to be explicit for now:
def p_advance_time(
    params: Dict[str, Any],
    substep: int,
    state_history: List[Dict[str, Any]],
    previous_state: Dict[str, Any],
) -> Dict[str, bool]:
    """
    Policy that signals the intent to advance time by one epoch.
    """
    return {"advance_epoch": True}
