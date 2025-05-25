from collections import deque
from typing import Dict, List
from datetime import datetime
from cadCAD.engine import ExecutionMode, ExecutionContext, Executor
from cadCAD.configuration import Configuration
from cadCAD.configuration.utils import config_sim

from .state import State
from .policies import (
    advance_block,
    p_user_actions,
    p_advance_time,
)
from .sufs import (
    s_update_current_epoch,
    s_update_current_time,
    s_apply_user_actions_initiatives,
    s_apply_user_actions_supporters,
    s_apply_user_actions_balances,
    s_apply_user_actions_circulating_supply,
    s_apply_support_decay,
    s_update_initiative_aggregate_weights,
    s_process_accepted_initiatives,
    s_process_expired_initiatives,
    s_process_support_lifecycle_balances,
    s_process_support_lifecycle_circulating_supply,
    s_process_support_lifecycle_supporters,
)


# Define the simulation parameters
simulation_parameters = {
    "T": range(10),  # Number of timesteps
    "N": 1,  # Number of monte carlo runs
    "M": {  # Model parameters
        "acceptance_threshold": 1000.0,
        "decay_multiplier": 0.95,
        "initiative_creation_stake": 10.0,
        "prob_create_initiative": 0.08,
        "prob_support_initiative": 0.2,
        "max_support_tokens_fraction": 0.5,
        "min_lock_duration_epochs": 5,
        "max_lock_duration_epochs": 20,
        "inactivity_period": 10,
    },
}

# Define the state keys for dynamic SUF creation
state_keys = [
    "current_epoch",
    "current_time",
]


def standard_state_update(key):
    """
    Standard state update function that takes the policy output for the key if available, otherwise passes through the previous state value.
    It always returns (new_value, old_value) tuple.
    The outer lambda(key) captures the 'key' for the inner lambda.
    """

    def state_update(params, substep, history, state, policy_input):
        # Handle the case where policy_input might return dictionaries that can't be hashed
        if key in policy_input:
            return policy_input[key], state[key]
        return state[key], state[key]

    return state_update


# Define the partial state update blocks with our explicit update functions
# Split into multiple PSUBs so state updates are visible between blocks
psubs = [
    # PSUB 1: Time advancement and user actions
    {
        "policies": {
            "time_advancement_policy": p_advance_time,
            "user_behavior_policy": p_user_actions,
        },
        "variables": {
            "current_epoch": s_update_current_epoch,
            "current_time": s_update_current_time,
            "initiatives": s_apply_user_actions_initiatives,
            "supporters": s_apply_user_actions_supporters,
            "balances": s_apply_user_actions_balances,
            "circulating_supply": s_apply_user_actions_circulating_supply,
        },
    },
    # PSUB 2: Support decay and weight updates
    {
        "policies": {},  # No policies needed, just state updates
        "variables": {
            "supporters": s_apply_support_decay,
            "initiatives": s_update_initiative_aggregate_weights,
        },
    },
    # PSUB 3: Lifecycle management
    {
        "policies": {},  # No policies needed, just state updates
        "variables": {
            "accepted_initiatives": s_process_accepted_initiatives,
            "expired_initiatives": s_process_expired_initiatives,
            "balances": s_process_support_lifecycle_balances,
            "circulating_supply": s_process_support_lifecycle_circulating_supply,
            "supporters": s_process_support_lifecycle_supporters,
        },
    },
]


def run_simulation(initial_state: Dict) -> List[Dict]:
    """Run the cadCAD simulation and return the results."""
    try:
        print("Initializing simulation...")

        # Create the cadCAD configuration
        # Note: config object is now created inside run_simulation to use dynamic initial_state
        # initial_state is already a dict from generate_initial_state, no need to call asdict()
        live_config = Configuration(
            initial_state=initial_state,
            partial_state_update_blocks=psubs,
            sim_config=config_sim(simulation_parameters),
            user_id="signals-sim",
            model_id="signals-v1",
            subset_id="default",
            subset_window=deque([0, simulation_parameters["T"].stop]),  # Use T from params
        )

        exec_mode = ExecutionMode()
        exec_context = ExecutionContext(exec_mode.single_mode)
        executor = Executor(exec_context, [live_config])  # Use live_config

        print("Executing simulation...")
        raw_result, tensor_field, sessions = executor.execute()

        print(f"Simulation completed with {len(raw_result)} timesteps")
        return raw_result
    except Exception as e:
        print(f"Error during simulation: {e}")
        # Print more detailed error info
        import traceback

        traceback.print_exc()
        return []  # Return empty list instead of raising to allow partial processing


if __name__ == "__main__":
    # Example usage
    # results = run_simulation() # Old way
    print("Running model.py directly with its default initial state:")
    default_results = run_simulation()  # Test with default
    print(f"Simulation completed with {len(default_results)} timesteps")

    print("\nRunning model.py with a custom state (example):")
    custom_initial_state_example = State(
        current_epoch=10,  # Example of a different start
        current_time=datetime.now(),
        initiatives={"init_custom": "custom_data"},
        total_supply=5000,
    ).__dict__()
    custom_initial_state_example["balances"] = {"user_custom": 5000}  # Add balances for consistency

    custom_results = run_simulation(initial_state=custom_initial_state_example)
    print(f"Simulation with custom state completed with {len(custom_results)} timesteps")
