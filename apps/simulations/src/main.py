import random
from cadCAD.configuration import Configuration
from cadCAD.engine import ExecutionMode, ExecutionContext, Executor
from collections import deque
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt

# Initialize an empty list for configurations
configs = []

# State Variables
genesis_states = {
    'initiatives': {},
    'users': {},
    'current_time': 0,
    'total_weight': 0,
}

# System Parameters
system_params = {
    'acceptanceThreshold': [100],
    'lockDurationCap': [12],
    'proposalCap': [100],
    'decayCurveType': [0],
    'inactivityThreshold': [60],
    'simulation_days': 180,
    'num_users': 100000,
}

def propose_initiative_policy(params, step, sL, s):
    num_users = params['num_users']
    proposal_chance = 0.01  # 1% chance
    proposed_initiatives = {}
    for user_id in range(num_users):
        if random.random() < proposal_chance:
            # Create a new initiative
            initiative_id = f"initiative_{step}_{user_id}"
            proposed_initiatives[initiative_id] = {
                'proposer': user_id,
                'time': step,
            }
    return {'new_initiatives': proposed_initiatives}

def update_initiatives(params, step, sL, s, inputs):
    initiatives = s['initiatives'].copy()
    # Update initiatives based on inputs from policies
    new_initiatives = inputs.get('new_initiatives', {})
    initiatives.update(new_initiatives)
    return ('initiatives', initiatives)

# Define partial state update blocks
partial_state_update_blocks = [
    {
        'policies': {
            'propose_initiative': propose_initiative_policy,
        },
        'variables': {
            'initiatives': update_initiatives,
        }
    },
]

# Create configuration
sim_config = {
    'N': 1,
    'T': range(system_params['simulation_days']),
    'M': system_params,
}

# Assign values for the required arguments
user_id = 'user_1'
model_id = 'model_1'
subset_id = 'subset_1'
subset_window = deque()

config = Configuration(
    user_id=user_id,
    model_id=model_id,
    subset_id=subset_id,
    subset_window=subset_window,
    initial_state=genesis_states,
    partial_state_update_blocks=partial_state_update_blocks,
    sim_config=sim_config
)

configs.append(config)

# Execute
exec_mode = ExecutionMode()
exec_context = ExecutionContext(context=exec_mode.local_mode)
simulation = Executor(exec_context=exec_context, configs=configs)

# Unpack the results
raw_result, tensor_field, sessions = simulation.execute()

# Convert results to DataFrame
df = pd.DataFrame(raw_result)

print(df.head())

# Calculate number of initiatives
df['num_initiatives'] = df['initiatives'].apply(lambda x: len(x))

# # Calculate cumulative initiatives
df['cumulative_initiatives'] = df['num_initiatives'].cumsum()

# Plot number of initiatives over time
sns.set_style('whitegrid')
# plt.figure(figsize=(12, 6))
# sns.lineplot(data=df, x='timestep', y='num_initiatives', marker='o')
# plt.title('Number of Initiatives Over Time')
# plt.xlabel('Timestep')
# plt.ylabel('Number of Initiatives')
# plt.show()

# Plot cumulative initiatives over time
plt.figure(figsize=(12, 6))
sns.lineplot(data=df, x='timestep', y='cumulative_initiatives', marker='o', color='green')
plt.title('Cumulative Number of Initiatives Over Time')
plt.xlabel('Timestep')
plt.ylabel('Cumulative Number of Initiatives')
plt.show()
