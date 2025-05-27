import pandas as pd
from cadCAD.configuration import Experiment
from cadCAD.configuration.utils import config_sim
from cadCAD.engine import ExecutionMode, ExecutionContext, Executor
import json

# Import our simulation components
from .state import generate_initial_state  # For creating the initial state dict
from .parameters import (
    simulation_config,
    initial_state_params,
)  # Sim configs and params
from .policies import p_user_actions, p_advance_time  # Our policy functions
from .sufs import (
    s_update_current_epoch,
    s_update_current_time,
    s_apply_user_actions_initiatives,
    s_apply_user_actions_supporters,
    s_apply_user_actions_balances,
    s_apply_user_actions_circulating_supply,
    s_calculate_current_support,
    s_update_initiative_aggregate_weights,
    s_process_accepted_initiatives,
    s_process_expired_initiatives,
    s_process_support_lifecycle_balances,
    s_process_support_lifecycle_circulating_supply,
    s_process_support_lifecycle_supporters,
)  # Our modular state update functions

# 1. Generate Initial State
# We use system_params directly here if generate_initial_state needs them,
# or it uses its own defaults which can be based on initial_state_params.
# The State class itself will pick up defaults for acceptance_threshold etc. from its kwargs if not in initial_state_params
initial_state_dict = generate_initial_state(
    num_users=initial_state_params["num_users"],
    total_supply=initial_state_params["total_supply"],
    randomize=initial_state_params["randomize_balances"],
    distribution_rule=initial_state_params.get("distribution_rule"),
)
# Add other system parameters from system_params to the initial_state_dict
# if they are not already handled by generate_initial_state or State constructor defaults.
# For instance, if State's __init__ doesn't use a default for these that matches system_params[param][0]
# initial_state_dict['acceptance_threshold'] = system_params['acceptance_threshold'][0]
# initial_state_dict['decay_multiplier'] = system_params['decay_multiplier'][0]
# These are handled by State.__init__ if passed in generate_initial_state or if State defines them.
# generate_initial_state already passes these based on its defaults, so this might be redundant
# but explicit for clarity if needed.

# DEBUG: Print the initial_state_dict to verify its content
print("\n--- Debug: initial_state_dict ---")


def set_default(obj):
    if isinstance(obj, set):
        return list(obj)
    raise TypeError


print(json.dumps(initial_state_dict, indent=2, default=set_default))
print("---------------------------------\n")

# DEBUG: Try a minimal initial state
# minimal_initial_state = {'current_epoch': 0, 'current_time': '2024-01-01T00:00:00'}
# actual_initial_state_to_use = minimal_initial_state
actual_initial_state_to_use = initial_state_dict

# 2. Define Partial State Update Blocks (PSUBs)
# This defines the order of operations within each timestep (epoch).
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
            "supporters": s_apply_user_actions_supporters,
            "balances": s_apply_user_actions_balances,
            "circulating_supply": s_apply_user_actions_circulating_supply,
        },
    },
    # PSUB 2: Support decay and weight updates
    {
        "policies": {},  # No policies needed, just state updates
        "variables": {
            "supporters": s_calculate_current_support,
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
    # PSUB 3c: Process support lifecycle
    {
        "policies": {},  # No policies needed, just state updates
        "variables": {
            "balances": s_process_support_lifecycle_balances,
            "circulating_supply": s_process_support_lifecycle_circulating_supply,
            "supporters": s_process_support_lifecycle_supporters,
        },
    },
]

# 3. Configure Simulation Execution
# Uses 'T', 'N', 'M' from parameters.py
sim_config_obj = config_sim(simulation_config)

# 4. Create Experiment
exp = Experiment()
exp.append_configs(
    initial_states=actual_initial_state_to_use,  # Use the potentially overridden initial state
    partial_state_update_blocks=psubs,
    sim_configs=sim_config_obj,
)

# 5. Execute the Simulation
print("Starting cadCAD simulation...")
exec_mode = ExecutionMode()
# Execute in single_proc mode by default.
# For parallel, use: local_mode_ctx = ExecutionContext(context=exec_mode.multi_proc)
local_mode_ctx = ExecutionContext(context=exec_mode.single_proc)

simulation = Executor(exec_context=local_mode_ctx, configs=exp.configs)

# raw_system_events: list of dicts, one per timestep, containing full state
# tensor_field: Transposed version for easier analysis, if configured (less common for complex states)
# sessions: metadata about the simulation runs
raw_system_events, tensor_field, sessions = simulation.execute()
print("Simulation complete.")

# 6. Process and Output Results
# Convert raw_system_events to a pandas DataFrame for analysis
df = pd.DataFrame(raw_system_events)

print("\n--- Simulation Run Summary ---")
print(f"Total simulation configurations (subsets) run: {len(sessions)}")
print(f"Monte Carlo runs per subset (N): {simulation_config['N']}")
print(f"Timesteps per run (T): {len(simulation_config['T'])}")

# Create a DataFrame from sessions to easily access parameters for each subset
params_df_data = []
for session_info in sessions:
    # session_info['subset_id'] should be the same as subset index from M key
    # However, cadCAD may use 'subset' or 'simulation_subset' in the main df.
    # The key for subset ID in session_info can be 'subset_id' or derived.
    # Let's use the index of the session in the sessions list as a reliable subset identifier.
    params_df_data.append(
        {
            "subset": session_info.get("subset_id", sessions.index(session_info)),
            **session_info["params"],
        }
    )
params_df = pd.DataFrame(params_df_data)

# Display some results
print("\n--- Simulation Results DataFrame (first 5 rows) ---")
print(df.head())

# Ensure 'subset' column exists from simulation output (usually it does)
if "subset" not in df.columns and "simulation_subset" in df.columns:
    df["subset"] = df["simulation_subset"]
elif "subset" not in df.columns:
    # If neither exists, try to derive it if only one subset was run
    if len(sessions) == 1:
        df["subset"] = 0
    else:
        print(
            "Warning: 'subset' column not found in DataFrame. Parameter-specific analysis might be limited."
        )

# Calculate number of accepted initiatives at the end of each run
if (
    "accepted_initiatives" in df.columns
    and "subset" in df.columns
    and "run" in df.columns
    and "timestep" in df.columns
):
    # Get the state at the last timestep for each run and subset
    final_states_df = df.loc[df.groupby(["subset", "run"])["timestep"].idxmax()]
    final_states_df["num_accepted"] = final_states_df["accepted_initiatives"].apply(
        lambda x: len(x) if isinstance(x, set) else 0
    )

    # Average over Monte Carlo runs (N) for each subset
    avg_results_per_subset = final_states_df.groupby("subset")["num_accepted"].mean().reset_index()

    # Merge with parameters to show which params led to which results
    results_with_params = pd.merge(avg_results_per_subset, params_df, on="subset", how="left")

    print(
        "\n--- Average Number of Accepted Initiatives (at final timestep) per Parameter Subset ---"
    )
    print(results_with_params)
else:
    print(
        "\nSkipping detailed results per subset: Required columns ('accepted_initiatives', 'subset', 'run', 'timestep') not found or issue with 'subset' column."
    )


print("\nExample: Initiative weights over time (last 5 steps of first run of first subset):")
# Filter for subset 0, run 1 (or the first available run if N > 1)
first_subset_df = df[(df.get("subset", 0) == 0) & (df["run"] == 1)]
for i, row in first_subset_df.tail(5).iterrows():
    print(f"Epoch: {row['current_epoch']}")
    initiatives_data = row.get("initiatives", {})
    if initiatives_data:
        for init_id, init_obj in initiatives_data.items():
            weight = init_obj.get("weight") if isinstance(init_obj, dict) else init_obj.weight
            print(f"  Initiative {init_id[:8]}: Weight = {weight:.2f}")
    else:
        print("  No initiatives data.")

print(
    "\nTo run this simulation, save the code and execute this file (e.g., python -m src.cadcad.simulation)"
)
print(
    "Ensure all dependent files (state.py, parameters.py, policies.py, sufs.py) are in the same directory or PYTHONPATH."
)
