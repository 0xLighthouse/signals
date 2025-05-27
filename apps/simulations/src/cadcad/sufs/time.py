"""
Time progression State Update Functions (SUFs).

This module contains SUFs that handle time-related updates:
- Current epoch updates
- Current time updates
"""

from datetime import datetime, timedelta
from typing import Dict, List, Any, Tuple

from .base import StateUpdateFunction, log_epoch_transition


class UpdateCurrentEpoch(StateUpdateFunction):
    """SUF for updating the current epoch."""

    def execute(
        self,
        params: Dict[str, Any],
        substep: int,
        state_history: List[Dict[str, Any]],
        previous_state: Dict[str, Any],
        policy_input: Dict[str, Any],
    ) -> Tuple[str, Any]:
        new_epoch = previous_state["current_epoch"] + 1

        # Use the logging utility for consistent epoch transition logging
        state = self.get_state_obj(previous_state)
        state.current_epoch = new_epoch
        log_epoch_transition(state, "STARTING")

        return ("current_epoch", new_epoch)


class UpdateCurrentTime(StateUpdateFunction):
    """SUF for updating the current time."""

    def execute(
        self,
        params: Dict[str, Any],
        substep: int,
        state_history: List[Dict[str, Any]],
        previous_state: Dict[str, Any],
        policy_input: Dict[str, Any],
    ) -> Tuple[str, Any]:
        # previous_state['current_time'] might be string if from initial state via __dict__
        current_time_dt = previous_state["current_time"]
        if isinstance(current_time_dt, str):
            current_time_dt = datetime.fromisoformat(current_time_dt)
        new_time = current_time_dt + timedelta(days=1)  # Assuming 1 epoch = 1 day
        return ("current_time", new_time.isoformat())


# Create function-based SUFs for cadCAD compatibility
from .base import create_suf

s_update_current_epoch = create_suf(UpdateCurrentEpoch)
s_update_current_time = create_suf(UpdateCurrentTime)
