# Helper function for distributing tokens within a group
from typing import Dict, List, Optional
import random


def _distribute_tokens_to_group(
    user_ids_subset: List[str], tokens_to_distribute: int, balances_dict: Dict[str, int]
) -> None:
    """Helper to distribute a given amount of tokens as evenly as possible to a subset of users."""
    if not user_ids_subset or tokens_to_distribute < 0:
        return

    num_target_users = len(user_ids_subset)
    if num_target_users == 0:
        if tokens_to_distribute > 0:
            print(f"Warning: No users in subset to distribute {tokens_to_distribute} tokens to.")
        return

    base_tokens = tokens_to_distribute // num_target_users
    remainder_tokens = tokens_to_distribute % num_target_users

    for i, user_id in enumerate(user_ids_subset):
        # Ensure user_id is initialized in balances_dict if this function could be called first
        # For current design, balances_dict is progressively filled, so direct assignment is okay.
        balances_dict[user_id] = base_tokens + (1 if i < remainder_tokens else 0)


def allocate_tokens(
    user_ids: List[str],
    total_supply: int,
    circulating_supply: int,
    distribution: Optional[List[int]] = None,
    randomize: bool = True,
) -> Dict[str, int]:
    """Allocate tokens to users based on a distribution rule."""

    balances: Dict[str, int] = {}
    num_users = len(user_ids)

    # Initialize all users with 0 balance
    for user_id in user_ids:
        balances[user_id] = 0

    if randomize:
        raw_allocations = [random.random() for _ in range(num_users)]
        total_allocation_sum = sum(raw_allocations) if sum(raw_allocations) > 0 else 1
        current_total_distributed = 0
        if num_users > 0:
            for i, uid in enumerate(user_ids[:-1]):
                bal = int((raw_allocations[i] / total_allocation_sum) * total_supply)
                balances[uid] = bal
                current_total_distributed += bal
            balances[user_ids[-1]] = (
                total_supply - current_total_distributed
            )  # Ensure total supply is met for the last user
        elif total_supply > 0:  # No users but supply exists
            print(
                f"Warning: {total_supply} tokens to distribute but num_users is 0 in randomize mode."
            )

    elif (
        distribution
        and len(distribution) == 2
        and 0 < distribution[0] < 100
        and 0 <= distribution[1] <= 100
        and num_users > 0
    ):
        percent_users_control = distribution[0]
        percent_tokens_control = distribution[1]

        # Calculate number of users in the controlling group
        # Use round() for percentages and ensure at least 1 if not 0%, and not more than total users
        num_control_users = min(
            num_users, max(1, round(num_users * (percent_users_control / 100.0)))
        )
        num_other_users = num_users - num_control_users

        control_user_ids = user_ids[:num_control_users]
        other_user_ids = user_ids[num_control_users:]

        # Calculate tokens for the controlling group (use round for better accuracy with percentages)
        intended_tokens_for_control_group = round(total_supply * (percent_tokens_control / 100.0))

        # Distribute to controlling group
        _distribute_tokens_to_group(control_user_ids, intended_tokens_for_control_group, balances)

        # Calculate actual tokens distributed to control group to handle rounding precisely
        actual_tokens_in_control_group = sum(balances.get(uid, 0) for uid in control_user_ids)

        # Remaining tokens go to the other group
        tokens_for_other_group = total_supply - actual_tokens_in_control_group

        if num_other_users > 0:
            _distribute_tokens_to_group(other_user_ids, tokens_for_other_group, balances)
        elif (
            tokens_for_other_group > 0
        ):  # No other users, but tokens remain (should be rare if logic is correct)
            # This could happen if num_control_users == num_users but intended_tokens_for_control_group was rounded down.
            # Distribute remaining tokens among the control group again (or last user of control group for simplicity here).
            # For robustness, _distribute_tokens_to_group should handle adding to existing balances if called again.
            # However, simpler to add to last user of the only group.
            if control_user_ids:  # Ensure there is at least one user to give the remainder to
                balances[control_user_ids[-1]] += tokens_for_other_group
            else:  # Should not happen if num_users > 0
                print(
                    f"Warning: Remaining tokens {tokens_for_other_group} but no users to assign them to."
                )

    else:  # Fallback for no (valid) distribution_rule and randomize=False (equal distribution)
        if num_users > 0:
            _distribute_tokens_to_group(user_ids, total_supply, balances)
        elif total_supply > 0:
            print(
                f"Warning: {total_supply} tokens to distribute but num_users is 0 in default mode."
            )

    return balances
