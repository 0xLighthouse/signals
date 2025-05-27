"""
Lifecycle State Update Functions (SUFs).

This module contains SUFs that handle initiative and support lifecycles:
- Token unlocking for accepted initiatives and expired supports
- Support removal for completed lifecycles
"""

from typing import Dict, List, Any, Tuple

from .base import StateUpdateFunction, log_action


class ProcessSupportLifecycleBalancesSUF(StateUpdateFunction):
    """SUF for handling token unlocking for accepted initiatives and expired supports."""

    def execute(
        self,
        params: Dict[str, Any],
        substep: int,
        state_history: List[Dict[str, Any]],
        previous_state: Dict[str, Any],
        policy_input: Dict[str, Any],
    ) -> Tuple[str, Any]:
        state = self.get_state_obj(previous_state)
        acceptance_threshold = params["acceptance_threshold"]

        total_unlocked = 0

        # 1. Unlock tokens for accepted initiatives
        for init_id in state.accepted_initiatives:
            # Unlock all tokens for this accepted initiative
            for sup_key, support_obj in list(state.supporters.items()):
                if support_obj.initiative_id == init_id:
                    state.balances[support_obj.user_id] = (
                        state.balances.get(support_obj.user_id, 0) + support_obj.amount
                    )
                    total_unlocked += support_obj.amount

        # 2. Unlock tokens for expired supports (for non-accepted initiatives)
        for sup_key, support_obj in list(state.supporters.items()):
            if support_obj.initiative_id not in state.accepted_initiatives:
                if state.current_epoch >= support_obj.expiry_epoch:
                    state.balances[support_obj.user_id] = (
                        state.balances.get(support_obj.user_id, 0) + support_obj.amount
                    )
                    total_unlocked += support_obj.amount

        if total_unlocked > 0:
            log_action(
                state.current_epoch,
                "unlock",
                f"Unlocked {total_unlocked} tokens from lifecycle processing",
            )

        return ("balances", state.balances)


class ProcessSupportLifecycleCirculatingSupplySUF(StateUpdateFunction):
    """SUF for handling circulating supply updates for accepted initiatives and expired supports."""

    def execute(
        self,
        params: Dict[str, Any],
        substep: int,
        state_history: List[Dict[str, Any]],
        previous_state: Dict[str, Any],
        policy_input: Dict[str, Any],
    ) -> Tuple[str, Any]:
        state = self.get_state_obj(previous_state)
        acceptance_threshold = params["acceptance_threshold"]

        total_unlocked = 0

        # 1. Unlock tokens for accepted initiatives
        for init_id in state.accepted_initiatives:
            # Unlock all tokens for this accepted initiative
            for sup_key, support_obj in list(state.supporters.items()):
                if support_obj.initiative_id == init_id:
                    state.circulating_supply += support_obj.amount
                    total_unlocked += support_obj.amount

        # 2. Unlock tokens for expired supports (for non-accepted initiatives)
        for sup_key, support_obj in list(state.supporters.items()):
            if support_obj.initiative_id not in state.accepted_initiatives:
                if state.current_epoch >= support_obj.expiry_epoch:
                    state.circulating_supply += support_obj.amount
                    total_unlocked += support_obj.amount

        if total_unlocked > 0:
            log_action(
                state.current_epoch,
                "unlock",
                f"Added {total_unlocked} tokens back to circulating supply",
            )

        return ("circulating_supply", state.circulating_supply)


class ProcessSupportLifecycleSupportersSUF(StateUpdateFunction):
    """SUF for handling support removal for accepted initiatives and expired supports."""

    def execute(
        self,
        params: Dict[str, Any],
        substep: int,
        state_history: List[Dict[str, Any]],
        previous_state: Dict[str, Any],
        policy_input: Dict[str, Any],
    ) -> Tuple[str, Any]:
        state = self.get_state_obj(previous_state)
        acceptance_threshold = params["acceptance_threshold"]

        supports_to_remove = []

        # 1. Remove supports for accepted initiatives
        for init_id in state.accepted_initiatives:
            # Remove all supports for this accepted initiative
            for sup_key, support_obj in list(state.supporters.items()):
                if support_obj.initiative_id == init_id:
                    supports_to_remove.append(sup_key)

        # 2. Remove expired supports (for non-accepted initiatives)
        for sup_key, support_obj in list(state.supporters.items()):
            if support_obj.initiative_id not in state.accepted_initiatives:
                if state.current_epoch >= support_obj.expiry_epoch:
                    supports_to_remove.append(sup_key)

        # Remove the supports
        for sup_key in supports_to_remove:
            if sup_key in state.supporters:
                del state.supporters[sup_key]

        if supports_to_remove:
            log_action(
                state.current_epoch,
                "process",
                f"Removed {len(supports_to_remove)} completed supports",
            )

        # Convert dataclass objects to dictionaries for cadCAD compatibility
        supporters_dict = {k: self.to_cadcad_dict(v) for k, v in state.supporters.items()}
        return ("supporters", supporters_dict)


# Create function-based SUFs for cadCAD compatibility
from .base import create_suf

s_process_support_lifecycle_balances = create_suf(ProcessSupportLifecycleBalancesSUF)
s_process_support_lifecycle_circulating_supply = create_suf(
    ProcessSupportLifecycleCirculatingSupplySUF
)
s_process_support_lifecycle_supporters = create_suf(ProcessSupportLifecycleSupportersSUF)
