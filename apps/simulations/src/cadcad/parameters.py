# System Parameters
# These are parameters that define the rules of the system.
# They can be swept in Monte Carlo runs if multiple values are provided in lists.
system_params = {
    # Parameter to sweep: Acceptance Threshold
    "acceptance_threshold": [50000, 100000],
    "decay_multiplier": [0.95],  # Example value from generate_initial_state
    "initiative_creation_stake": [10.0],  # Minimum tokens required to create an initiative
    # Parameter to sweep: Probability of creating an initiative
    "prob_create_initiative": [0.08, 0.12],  # Sweeping two values
    # Probability parameters for stochastic policies
    "prob_support_initiative": [0.2],  # Chance per user per epoch to support an initiative
    "max_support_tokens_fraction": [0.5, 0.9],  # Max fraction of user's balance they'll lock
    "min_lock_duration_epochs": [5],  # Min epochs for locking
    "max_lock_duration_epochs": [20],  # Max epochs for locking
}

# Simulation Configuration
# Defines how the simulation will run.
simulation_config = {
    "T": range(100),  # Number of timesteps (epochs) for the simulation to run
    "N": 1,  # Number of Monte Carlo runs (simulation repetitions) for EACH parameter combination
    "M": system_params,  # This dictionary links to system_params for parameter sweeping
}

# Initial State Configuration Parameters
# These parameters are used by the `generate_initial_state` function.
initial_state_params = {
    "num_users": 100,
    "total_supply": 1_000_000,
    "randomize_balances": True,
    "distribution_rule": None,  # Example: 25% of users control 75% of tokens. Set to None for equal distribution.
    # To sweep this, it would need to be part of system_params and simulation.py adjusted.
}
