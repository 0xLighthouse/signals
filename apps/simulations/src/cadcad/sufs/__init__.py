"""
State Update Functions (SUFs) package for cadCAD simulation.

This package organizes SUFs into logical modules:
- base: Common functionality and base classes
- user_actions: SUFs handling user-initiated actions
- governance: SUFs handling governance mechanics
- lifecycle: SUFs handling initiative and support lifecycles
- time: SUFs handling time progression
"""

# Import base utilities
from .base import SUFBase, get_state_obj, create_suf_function, log_epoch_transition, log_action

# Import all SUFs for easy access
from .user_actions import (
    s_apply_user_actions_initiatives,
    s_apply_user_actions_supporters,
    s_apply_user_actions_balances,
    s_apply_user_actions_circulating_supply,
)

from .governance import (
    s_apply_support_decay,
    s_update_initiative_aggregate_weights,
    s_process_accepted_initiatives,
    s_process_expired_initiatives,
)

from .lifecycle import (
    s_process_support_lifecycle_balances,
    s_process_support_lifecycle_circulating_supply,
    s_process_support_lifecycle_supporters,
)

from .time import (
    s_update_current_epoch,
    s_update_current_time,
)

__all__ = [
    # Base utilities
    "SUFBase",
    "get_state_obj",
    "create_suf_function",
    "log_epoch_transition",
    "log_action",
    # User actions
    "s_apply_user_actions_initiatives",
    "s_apply_user_actions_supporters",
    "s_apply_user_actions_balances",
    "s_apply_user_actions_circulating_supply",
    # Governance
    "s_apply_support_decay",
    "s_update_initiative_aggregate_weights",
    "s_process_accepted_initiatives",
    "s_process_expired_initiatives",
    # Lifecycle
    "s_process_support_lifecycle_balances",
    "s_process_support_lifecycle_circulating_supply",
    "s_process_support_lifecycle_supporters",
    # Time
    "s_update_current_epoch",
    "s_update_current_time",
]
