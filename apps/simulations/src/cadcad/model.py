from collections import deque
from dataclasses import asdict
from typing import Dict, List
from datetime import datetime
from cadCAD.engine import ExecutionMode, ExecutionContext, Executor
from cadCAD.configuration import Configuration
from cadCAD.configuration.utils import config_sim

from .state import State
from .policies import (
    advance_block,
    submit_initiative,
    support_initiative,
    decay_weights,
    check_acceptance,
    check_expiration,
)


# Define the simulation parameters
simulation_parameters = {
    "T": range(100),  # Number of timesteps
    "N": 1,  # Number of monte carlo runs
    "M": {  # Model parameters
        "decay_type": "exponential",  # Can be 'linear' or 'exponential'
        "acceptance_threshold": 1000.0,
        "inactivity_period": 10,
        "decay_multiplier": 0.95,
        # Add initiative parameters
        "title": "Test Initiative",
        "description": "A test initiative for simulation",
        "user_id": "test_user",
        "initiative_id": None,  # Will be generated in the policy
        "amount": 100.0,
        "duration": 30,
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
psubs = [
    # {
    #     "policies": {
    #         "submit_initiative": submit_initiative,
    #     },
    #     "variables": {
    #         "current_epoch": update_current_epoch,
    #         "current_time": update_current_time,
    #         "initiatives": update_initiatives,
    #         "accepted_initiatives": update_accepted_initiatives,
    #         "expired_initiatives": update_expired_initiatives,
    #         "supporters": update_supporters,
    #         "acceptance_threshold": update_acceptance_threshold,
    #         "inactivity_period": update_inactivity_period,
    #         "decay_multiplier": update_decay_multiplier,
    #     },
    # },
    # {
    #     "policies": {
    #         "support_initiative": support_initiative,
    #     },
    #     "variables": {
    #         "current_epoch": update_current_epoch,
    #         "current_time": update_current_time,
    #         "initiatives": update_initiatives,
    #         "accepted_initiatives": update_accepted_initiatives,
    #         "expired_initiatives": update_expired_initiatives,
    #         "supporters": update_supporters,
    #         "acceptance_threshold": update_acceptance_threshold,
    #         "inactivity_period": update_inactivity_period,
    #         "decay_multiplier": update_decay_multiplier,
    #     },
    # },
    # {
    #     "policies": {
    #         "decay_weights": decay_weights,
    #     },
    #     "variables": {
    #         "current_epoch": update_current_epoch,
    #         "current_time": update_current_time,
    #         "initiatives": update_initiatives,
    #         "accepted_initiatives": update_accepted_initiatives,
    #         "expired_initiatives": update_expired_initiatives,
    #         "supporters": update_supporters,
    #         "acceptance_threshold": update_acceptance_threshold,
    #         "inactivity_period": update_inactivity_period,
    #         "decay_multiplier": update_decay_multiplier,
    #     },
    # },
    # {
    #     "policies": {
    #         "check_acceptance": check_acceptance,
    #         "check_expiration": check_expiration,
    #     },
    #     "variables": {
    #         "current_epoch": update_current_epoch,
    #         "current_time": update_current_time,
    #         "initiatives": update_initiatives,
    #         "accepted_initiatives": update_accepted_initiatives,
    #         "expired_initiatives": update_expired_initiatives,
    #         "supporters": update_supporters,
    #         "acceptance_threshold": update_acceptance_threshold,
    #         "inactivity_period": update_inactivity_period,
    #         "decay_multiplier": update_decay_multiplier,
    #     },
    # },
    {
        "policies": {
            "advance_block": advance_block,
        },
        "variables": {
            "current_epoch": standard_state_update("current_epoch"),
            "current_time": standard_state_update("current_time"),
        },
    },
]


def run_simulation(initial_state: Dict) -> List[Dict]:
    """Run the cadCAD simulation and return the results."""
    try:
        print("Initializing simulation...")

        # Create the cadCAD configuration
        # Note: config object is now created inside run_simulation to use dynamic initial_state
        live_config = Configuration(
            initial_state=asdict(initial_state),
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
        raw_result = executor.execute()

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
