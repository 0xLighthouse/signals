"""
User action State Update Functions (SUFs).

This module contains SUFs that handle user-initiated actions:
- Initiative creation
- Initiative support
- Balance updates from user actions
- Circulating supply updates from user actions
"""

import uuid
from typing import Dict, List, Any, Tuple

from .base import StateUpdateFunction, log_action, create_suf_function
from ..state import Initiative, Support


class ApplyUserActionsInitiativesSUF(StateUpdateFunction):
    """SUF for applying user actions that affect initiatives."""

    def execute(
        self,
        params: Dict[str, Any],
        substep: int,
        state_history: List[Dict[str, Any]],
        previous_state: Dict[str, Any],
        policy_input: Dict[str, Any],
    ) -> Tuple[str, Any]:
        state = self.get_state_obj(previous_state)
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
                    log_action(
                        state.current_epoch,
                        "create",
                        f"User {user_id} created initiative '{initiative.title}' (ID: {new_initiative_id[:8]}...)",
                    )

        # Convert dataclass objects to dictionaries for cadCAD compatibility
        initiatives_dict = {k: self.to_cadcad_dict(v) for k, v in state.initiatives.items()}
        log_action(
            state.current_epoch,
            "process",
            f"Total initiatives after creation: {len(initiatives_dict)}",
        )
        return ("initiatives", initiatives_dict)


class ApplyUserActionsSupportersSUF(StateUpdateFunction):
    """SUF for applying user actions that affect supporters."""

    def execute(
        self,
        params: Dict[str, Any],
        substep: int,
        state_history: List[Dict[str, Any]],
        previous_state: Dict[str, Any],
        policy_input: Dict[str, Any],
    ) -> Tuple[str, Any]:
        state = self.get_state_obj(previous_state)
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
                    log_action(
                        state.current_epoch,
                        "support",
                        f"User {user_id} supported initiative {initiative_id[:8]}... with {amount:.1f} tokens for {lock_duration_epochs} epochs",
                    )

                    # Update initiative's last support epoch
                    if initiative_id in state.initiatives:
                        state.initiatives[initiative_id].last_support_time = state.current_time
                        state.initiatives[initiative_id].last_support_epoch = state.current_epoch

        # Convert dataclass objects to dictionaries for cadCAD compatibility
        supporters_dict = {k: self.to_cadcad_dict(v) for k, v in state.supporters.items()}
        log_action(
            state.current_epoch,
            "process",
            f"Total supporters after actions: {len(supporters_dict)}",
        )
        return ("supporters", supporters_dict)


class ApplyUserActionsBalancesSUF(StateUpdateFunction):
    """SUF for applying user actions that affect balances."""

    def execute(
        self,
        params: Dict[str, Any],
        substep: int,
        state_history: List[Dict[str, Any]],
        previous_state: Dict[str, Any],
        policy_input: Dict[str, Any],
    ) -> Tuple[str, Any]:
        state = self.get_state_obj(previous_state)
        actions = policy_input.get("user_actions", [])

        for action in actions:
            action_type = action.get("type")
            user_id = action.get("user_id")

            if action_type == "create_initiative":
                creation_stake = params["initiative_creation_stake"]
                if state.balances.get(user_id, 0) >= creation_stake:
                    state.balances[user_id] -= creation_stake
                    log_action(
                        state.current_epoch,
                        "process",
                        f"Deducted {creation_stake} tokens from user {user_id} for initiative creation",
                    )

            elif action_type == "support_initiative":
                initiative_id = action.get("initiative_id")
                amount = action.get("amount")

                if initiative_id in state.initiatives and state.balances.get(user_id, 0) >= amount:
                    state.balances[user_id] -= amount
                    log_action(
                        state.current_epoch,
                        "process",
                        f"Locked {amount} tokens from user {user_id} for supporting initiative",
                    )

        return ("balances", state.balances)


class ApplyUserActionsCirculatingSupplySUF(StateUpdateFunction):
    """SUF for applying user actions that affect circulating supply."""

    def execute(
        self,
        params: Dict[str, Any],
        substep: int,
        state_history: List[Dict[str, Any]],
        previous_state: Dict[str, Any],
        policy_input: Dict[str, Any],
    ) -> Tuple[str, Any]:
        state = self.get_state_obj(previous_state)
        actions = policy_input.get("user_actions", [])

        total_locked = 0
        for action in actions:
            action_type = action.get("type")
            user_id = action.get("user_id")

            if action_type == "support_initiative":
                initiative_id = action.get("initiative_id")
                amount = action.get("amount")

                if initiative_id in state.initiatives and state.balances.get(user_id, 0) >= amount:
                    total_locked += amount

        new_circulating_supply = state.circulating_supply - total_locked
        if total_locked > 0:
            log_action(
                state.current_epoch,
                "process",
                f"Locked {total_locked} tokens, new circulating supply: {new_circulating_supply}",
            )

        return ("circulating_supply", new_circulating_supply)


# Create function-based SUFs for cadCAD compatibility
s_apply_user_actions_initiatives = create_suf_function(ApplyUserActionsInitiativesSUF)
s_apply_user_actions_supporters = create_suf_function(ApplyUserActionsSupportersSUF)
s_apply_user_actions_balances = create_suf_function(ApplyUserActionsBalancesSUF)
s_apply_user_actions_circulating_supply = create_suf_function(ApplyUserActionsCirculatingSupplySUF)
