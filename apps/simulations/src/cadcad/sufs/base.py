"""
Base functionality for State Update Functions (SUFs).

This module provides common utilities and base classes to reduce
code duplication across SUF implementations.
"""

import uuid
from datetime import datetime, timedelta
from typing import Dict, List, Any, Tuple, Callable, TypeVar
from abc import ABC, abstractmethod

from ..state import State, Initiative, Support

# Type variable for SUF return types
SUFReturn = TypeVar("SUFReturn", Tuple[str, Any], List[Tuple[str, Any]])


def get_state_obj(previous_state_dict: Dict[str, Any]) -> State:
    """
    Reconstruct State object from cadCAD dict representation.

    This is a critical utility that handles the conversion between
    cadCAD's dict-based state and our dataclass-based State objects.
    """
    # Create Initiative objects from dicts
    initiatives_dict_of_obj = {}
    for init_id, init_data in previous_state_dict.get("initiatives", {}).items():
        if isinstance(init_data, dict):
            initiatives_dict_of_obj[init_id] = Initiative(**init_data)
        elif isinstance(init_data, Initiative):
            initiatives_dict_of_obj[init_id] = init_data
        else:
            raise TypeError(f"Unexpected type for initiative data: {type(init_data)}")

    # Create Support objects from dicts
    supporters_dict_of_obj = {}
    for sup_key_tuple, sup_data in previous_state_dict.get("supporters", {}).items():
        key = tuple(sup_key_tuple) if isinstance(sup_key_tuple, list) else sup_key_tuple
        if isinstance(sup_data, dict):
            # Handle field mapping and filtering
            init_fields = {}
            for k, v in sup_data.items():
                if k not in ["initial_weight", "current_weight", "expiry_epoch"]:
                    if k == "creation_epoch":
                        init_fields["start_epoch"] = v
                    else:
                        init_fields[k] = v

            support_obj = Support(**init_fields)

            # Preserve calculated fields
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

    # Create State instance
    current_state_params = previous_state_dict.copy()
    current_state_params["initiatives"] = initiatives_dict_of_obj
    current_state_params["supporters"] = supporters_dict_of_obj

    # Handle datetime parsing
    if isinstance(current_state_params.get("current_time"), str):
        current_state_params["current_time"] = datetime.fromisoformat(
            current_state_params["current_time"]
        )

    return State(**current_state_params)


class StateUpdateFunction(ABC):
    """Base class for State Update Functions with common functionality."""

    @staticmethod
    def get_state_obj(previous_state_dict: Dict[str, Any]) -> State:
        """
        Reconstruct State object from cadCAD dict representation.

        This method delegates to the standalone get_state_obj function
        for backward compatibility with existing SUF implementations.
        """
        return get_state_obj(previous_state_dict)

    @staticmethod
    def to_cadcad_dict(obj: Any) -> Any:
        """Convert dataclass objects to dictionaries for cadCAD compatibility."""
        if hasattr(obj, "__dict__"):
            return obj.__dict__
        elif isinstance(obj, dict):
            return {k: StateUpdateFunction.to_cadcad_dict(v) for k, v in obj.items()}
        elif isinstance(obj, (list, tuple)):
            return [StateUpdateFunction.to_cadcad_dict(item) for item in obj]
        else:
            return obj

    @abstractmethod
    def execute(
        self,
        params: Dict[str, Any],
        substep: int,
        state_history: List[Dict[str, Any]],
        previous_state: Dict[str, Any],
        policy_input: Dict[str, Any],
    ) -> SUFReturn:
        """Execute the SUF logic. Must be implemented by subclasses."""
        pass


def create_suf_function(suf_class: type) -> Callable:
    """
    Factory function to create SUF functions from SUF classes.

    This allows us to use class-based SUFs while maintaining
    compatibility with cadCAD's function-based interface.
    """

    def suf_function(
        params: Dict[str, Any],
        substep: int,
        state_history: List[Dict[str, Any]],
        previous_state: Dict[str, Any],
        policy_input: Dict[str, Any],
    ) -> SUFReturn:
        suf_instance = suf_class()
        return suf_instance.execute(params, substep, state_history, previous_state, policy_input)

    # Preserve function name for debugging
    suf_function.__name__ = suf_class.__name__.lower()
    return suf_function


def log_epoch_transition(state: State, message: str = "") -> None:
    """Utility function for consistent epoch transition logging."""
    print(f"\n🕐 === EPOCH {state.current_epoch} {message} ===")
    print(f"📈 Current state summary:")
    print(f"   - Initiatives: {len(state.initiatives)}")
    print(f"   - Supporters: {len(state.supporters)}")
    print(f"   - Accepted: {len(state.accepted_initiatives)}")
    print(f"   - Expired: {len(state.expired_initiatives)}")
    print(f"   - Circulating supply: {state.circulating_supply}")


def log_action(epoch: int, action_type: str, details: str) -> None:
    """Utility function for consistent action logging."""
    icons = {
        "create": "🆕",
        "support": "💰",
        "accept": "✅",
        "expire": "⏰",
        "decay": "📉",
        "unlock": "🔓",
        "update": "⚖️",
        "process": "🔍",
    }
    icon = icons.get(action_type, "📊")
    print(f"{icon} EPOCH {epoch}: {details}")
