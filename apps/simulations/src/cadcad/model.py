from collections import deque
from typing import Dict, List
from datetime import datetime
from cadCAD.engine import ExecutionMode, ExecutionContext, Executor
from cadCAD.configuration import Configuration
from cadCAD.configuration.utils import config_sim

from .state import State
from .policies import (
    submit_initiative,
    support_initiative,
    decay_weights,
    check_acceptance,
    check_expiration,
    advance_time,
)

# Define the initial state
initial_state = State(
    current_epoch=0,
    current_time=datetime.now(),
    acceptance_threshold=1000.0,
    inactivity_period=10,
    decay_multiplier=0.95,
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
    },
}

# Define the partial state update blocks
psubs = [
    {
        "policies": {
            "submit_initiative": submit_initiative,
            "support_initiative": support_initiative,
        },
        "variables": {
            "initiatives": lambda state, params: (state['initiatives'], state['initiatives']),
            "supporters": lambda state, params: (state['supporters'], state['supporters']),
        },
    },
    {
        "policies": {
            "decay_weights": decay_weights,
        },
        "variables": {
            "supporters": lambda state, params: (state['supporters'], state['supporters']),
            "initiatives": lambda state, params: (state['initiatives'], state['initiatives']),
        },
    },
    {
        "policies": {
            "check_acceptance": check_acceptance,
            "check_expiration": check_expiration,
        },
        "variables": {
            "accepted_initiatives": lambda state, params: (state['accepted_initiatives'], state['accepted_initiatives']),
            "expired_initiatives": lambda state, params: (state['expired_initiatives'], state['expired_initiatives']),
        },
    },
    {
        "policies": {
            "advance_time": advance_time,
        },
        "variables": {
            "current_epoch": lambda state, params: (state['current_epoch'], state['current_epoch']),
            "current_time": lambda state, params: (state['current_time'], state['current_time']),
        },
    },
]

# Custom policy operation that knows how to handle datetime objects
def policy_ops(a, b):
    # Handle datetime objects
    if isinstance(a, datetime) and isinstance(b, datetime):
        return b  # For datetime, we just want to use the latest value, not add them
    elif isinstance(a, dict) and isinstance(b, dict):
        # For dictionaries, merge them
        c = a.copy()
        c.update(b)
        return c
    elif isinstance(a, set) and isinstance(b, set):
        # For sets, merge them
        return a.union(b)
    else:
        # Default operation
        try:
            return a + b
        except TypeError:
            # If addition fails, just return the second value
            return b

# Create the cadCAD configuration
config = Configuration(
    initial_state=initial_state.__dict__,
    partial_state_update_blocks=psubs,
    sim_config=config_sim(simulation_parameters),
    user_id="signals-sim",  # Required parameter
    model_id="signals-v1",  # Required parameter
    subset_id="default",  # Required parameter
    subset_window=deque([0, 100]),  # Required parameter - simulation window
    policy_ops=[policy_ops]  # Use our custom policy operation
)


def run_simulation() -> List[Dict]:
    """Run the cadCAD simulation and return the results."""
    exec_mode = ExecutionMode()
    exec_context = ExecutionContext(exec_mode.single_mode)
    executor = Executor(exec_context, [config])
    raw_result, tensor_field, sessions = executor.execute()

    return raw_result


if __name__ == "__main__":
    # Example usage
    results = run_simulation()
    print(f"Simulation completed with {len(results)} timesteps")
