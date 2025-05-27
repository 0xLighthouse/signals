"""
Governance State Update Functions (SUFs).

This module contains SUFs that handle governance mechanics:
- Support decay
- Initiative weight updates
- Initiative acceptance
- Initiative expiration
"""

from typing import Dict, List, Any, Tuple, Set
from .base import StateUpdateFunction, log_action, create_suf


class CalculateCurrentSupport(StateUpdateFunction):
    """SUF for applying decay to the current_weight of all active supports."""

    def execute(
        self,
        params: Dict[str, Any],
        substep: int,
        state_history: List[Dict[str, Any]],
        previous_state: Dict[str, Any],
        policy_input: Dict[str, Any],
    ) -> Tuple[str, Any]:
        state = self.get_state_obj(previous_state)
        decay_multiplier = params["decay_multiplier"]

        log_action(
            state.current_epoch,
            "process",
            f"Decay SUF - received {len(state.initiatives)} initiatives",
        )

        active_supports_count = 0
        for support in state.supporters.values():
            if (
                state.current_epoch < support.expiry_epoch
            ):  # Only decay active, non-expired supports
                old_weight = support.current_weight
                support.decay(decay_multiplier, state.current_epoch)
                active_supports_count += 1

        if active_supports_count > 0:
            log_action(
                state.current_epoch,
                "decay",
                f"Applied decay (×{decay_multiplier}) to {active_supports_count} active supports",
            )

        # Convert dataclass objects to dictionaries for cadCAD compatibility
        supporters_dict = {k: self.to_cadcad_dict(v) for k, v in state.supporters.items()}
        return ("supporters", supporters_dict)


class UpdateInitiativeAggregateWeightsSUF(StateUpdateFunction):
    """SUF for recalculating the total weight for each initiative based on its current supports."""

    def execute(
        self,
        params: Dict[str, Any],
        substep: int,
        state_history: List[Dict[str, Any]],
        previous_state: Dict[str, Any],
        policy_input: Dict[str, Any],
    ) -> Tuple[str, Any]:
        state = self.get_state_obj(previous_state)
        state.update_initiative_weights()  # This method is in the State class

        # Debug: Show initiative weights
        if state.initiatives:
            log_action(state.current_epoch, "update", "Initiative weights updated:")
            for init_id, initiative in state.initiatives.items():
                log_action(
                    state.current_epoch,
                    "update",
                    f"Initiative {init_id[:8]}...: weight = {initiative.weight:.1f}",
                )

        # Convert dataclass objects to dictionaries for cadCAD compatibility
        initiatives_dict = {k: self.to_cadcad_dict(v) for k, v in state.initiatives.items()}
        return ("initiatives", initiatives_dict)


class ProcessAcceptedInitiativesSUF(StateUpdateFunction):
    """SUF for handling initiative acceptance."""

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

        newly_accepted_initiatives_this_step: Set[str] = set()

        # Check for Initiative Acceptance
        for init_id, initiative in list(state.initiatives.items()):
            if (
                init_id not in state.accepted_initiatives
                and init_id not in state.expired_initiatives
            ):
                if initiative.weight >= acceptance_threshold:
                    state.accepted_initiatives.add(init_id)
                    newly_accepted_initiatives_this_step.add(init_id)
                    log_action(
                        state.current_epoch,
                        "accept",
                        f"Initiative {init_id[:8]}... ACCEPTED! (weight: {initiative.weight:.1f} >= threshold: {acceptance_threshold})",
                    )

        if newly_accepted_initiatives_this_step:
            log_action(
                state.current_epoch,
                "accept",
                f"{len(newly_accepted_initiatives_this_step)} initiatives accepted this epoch",
            )

        return ("accepted_initiatives", state.accepted_initiatives)


class ProcessExpiredInitiativesSUF(StateUpdateFunction):
    """SUF for handling initiative expiration due to inactivity."""

    def execute(
        self,
        params: Dict[str, Any],
        substep: int,
        state_history: List[Dict[str, Any]],
        previous_state: Dict[str, Any],
        policy_input: Dict[str, Any],
    ) -> Tuple[str, Any]:
        state = self.get_state_obj(previous_state)
        inactivity_period = params["inactivity_period"]

        log_action(
            state.current_epoch,
            "process",
            f"Expiration SUF - received {len(state.initiatives)} initiatives",
        )

        newly_expired_initiatives = []

        # Check for Initiative Expiration (Inactivity)
        for init_id, initiative in list(state.initiatives.items()):
            if (
                init_id not in state.accepted_initiatives
                and init_id not in state.expired_initiatives
            ):
                # Check if initiative still has any active support
                has_active_support = any(
                    s.initiative_id == init_id for s in state.supporters.values()
                )
                epochs_since_last_support = state.current_epoch - initiative.last_support_epoch

                log_action(
                    state.current_epoch,
                    "process",
                    f"Checking initiative {init_id[:8]}... - has_support: {has_active_support}, epochs_since_last: {epochs_since_last_support}, threshold: {inactivity_period}",
                )

                if not has_active_support and epochs_since_last_support >= inactivity_period:
                    state.expired_initiatives.add(init_id)
                    newly_expired_initiatives.append(init_id)
                    log_action(
                        state.current_epoch,
                        "expire",
                        f"Initiative {init_id[:8]}... EXPIRED! (no support for {epochs_since_last_support} epochs >= {inactivity_period})",
                    )

        if newly_expired_initiatives:
            log_action(
                state.current_epoch,
                "expire",
                f"{len(newly_expired_initiatives)} initiatives expired this epoch",
            )

        return ("expired_initiatives", state.expired_initiatives)


# Create function-based SUFs for cadCAD compatibility

s_calculate_current_support = create_suf(CalculateCurrentSupport)
s_update_initiative_aggregate_weights = create_suf(UpdateInitiativeAggregateWeightsSUF)
s_process_accepted_initiatives = create_suf(ProcessAcceptedInitiativesSUF)
s_process_expired_initiatives = create_suf(ProcessExpiredInitiativesSUF)
