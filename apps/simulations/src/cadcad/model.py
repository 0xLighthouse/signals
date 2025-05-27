from collections import deque
from typing import Dict, List
from datetime import datetime
from cadCAD.engine import ExecutionMode, ExecutionContext, Executor
from cadCAD.configuration import Configuration
from cadCAD.configuration.utils import config_sim

from .state import State
from .policies import (
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
    s_apply_user_actions_locked_supply,
    s_calculate_current_support,
    s_update_initiative_aggregate_weights,
    s_process_accepted_initiatives,
    s_process_expired_initiatives,
    s_process_support_lifecycle_balances,
    s_process_support_lifecycle_circulating_supply,
    s_process_support_lifecycle_locked_supply,
    s_process_support_lifecycle_supporters,
)


# Define the simulation parameters
simulation_parameters = {
    "T": range(744),  # Total timesteps (31 days = 744 hours)
    "N": 1,  # Number of monte carlo runs
    "M": {  # Model parameters
        # Time configuration
        "time_unit": "hours",  # Each timestep is 1 hour
        "simulation_duration": 744,  # 31 days in hours
        # Governance thresholds
        "acceptance_threshold": 75000.0,  # ~75k units
        "decay_multiplier": 0.999,  # 0.1% decay per hour
        "initiative_creation_stake": 120.0,  # Increased stake to reduce total from 208 to 80-90
        "prob_create_initiative": 0.00025,  # Probability to create an initiative
        "prob_support_initiative": 0.005,  # Probability to give support to an initiative
        # Economic constraints
        "max_support_tokens_fraction": 0.3,  # How much of the user's balance can be used to support an initiative?
        "min_lock_duration_epochs": 24,  # Minimum lock duration (24 hours)
        "max_lock_duration_epochs": 336,  # Maximum lock duration (2 weeks)
        # Lifecycle parameters
        "inactivity_period": 720,  # Inactivity period (30 days) before expiration
        # Reward system parameters
        "reward_enabled": True,  # Whether to enable the reward system
        "max_reward_rate": 0.1,  # Maximum reward rate (10% of support amount)
        "min_reward_rate": 0.01,  # Minimum reward rate (1% of support amount)
        "reward_steepness": 5.0,  # Controls how quickly the reward rate decreases
        "reward_midpoint": 0.2,  # Weight percentage at which reward rate is halfway between min and max
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
    # PSUB 1a: Time advancement
    {
        "policies": {
            "time_advancement_policy": p_advance_time,
        },
        "variables": {
            "current_epoch": s_update_current_epoch,
            "current_time": s_update_current_time,
        },
    },
    # PSUB 1b: User actions
    {
        "policies": {
            "user_behavior_policy": p_user_actions,
        },
        "variables": {
            "initiatives": s_apply_user_actions_initiatives,
            "locks": s_apply_user_actions_supporters,
            "balances": s_apply_user_actions_balances,
            "circulating_supply": s_apply_user_actions_circulating_supply,
            "locked_supply": s_apply_user_actions_locked_supply,
        },
    },
    # PSUB 2: Support decay and weight updates
    {
        "policies": {},  # No policies needed, just state updates
        "variables": {
            "locks": s_calculate_current_support,
            "initiatives": s_update_initiative_aggregate_weights,
        },
    },
    # PSUB 3: Lifecycle management
    # PSUB 3a: Process accepted initiatives
    {
        "policies": {},  # No policies needed, just state updates
        "variables": {
            "accepted_initiatives": s_process_accepted_initiatives,
        },
    },
    # PSUB 3b: Process expired initiatives
    {
        "policies": {},  # No policies needed, just state updates
        "variables": {
            "expired_initiatives": s_process_expired_initiatives,
        },
    },
    {
        "policies": {},  # No policies needed, just state updates
        "variables": {
            "balances": s_process_support_lifecycle_balances,
            "circulating_supply": s_process_support_lifecycle_circulating_supply,
            "locked_supply": s_process_support_lifecycle_locked_supply,
            "locks": s_process_support_lifecycle_supporters,
        },
    },
]


def run_simulation(initial_state: Dict, num_epochs: int = None) -> List[Dict]:
    """Run the cadCAD simulation and return the results."""
    try:
        print("Initializing simulation...")

        # Use custom num_epochs if provided, otherwise use default
        if num_epochs is not None:
            custom_simulation_parameters = simulation_parameters.copy()
            custom_simulation_parameters["T"] = range(num_epochs)
        else:
            custom_simulation_parameters = simulation_parameters

        # Create the cadCAD configuration
        # Note: config object is now created inside run_simulation to use dynamic initial_state
        # initial_state is already a dict from generate_initial_state, no need to call asdict()
        live_config = Configuration(
            initial_state=initial_state,
            partial_state_update_blocks=psubs,
            sim_config=config_sim(custom_simulation_parameters),
            user_id="signals-sim",
            model_id="signals-v1",
            subset_id="default",
            subset_window=deque([0, custom_simulation_parameters["T"].stop]),  # Use T from params
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
