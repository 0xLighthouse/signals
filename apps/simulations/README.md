# Initiative Dynamics Simulation

This package contains a cadCAD-based simulation of initiative dynamics for the Signals platform. It demonstrates how initiatives are created, supported, and accepted over time using a token-based governance mechanism.

## Features

- **Token-based governance**: Users stake tokens to support initiatives
- **Weight decay**: Support weights decay over time, creating urgency
- **Acceptance thresholds**: Initiatives are accepted when they reach sufficient support
- **Token lifecycle**: Proper locking and unlocking of tokens based on outcomes
- **Support expiration**: Individual supports expire after their lock duration
- **Initiative expiration**: Initiatives expire if they receive no support for too long
- **Detailed debugging**: Comprehensive logging of all state transitions

## Quick Start

```shell
# Install dependencies
poetry install

# Run the complete simulation pipeline
poetry run python src/main.py

# Generate visualizations and analysis
poetry run python src/visualize.py

# Run the test suite
poetry run pytest
```

## Running the Scripts

### 1. Main Simulation (`src/main.py`)

Runs the complete cadCAD simulation and exports results:

```shell
poetry run python src/main.py
```

**What it does:**

- Generates initial state with 50 users and 1M tokens
- Runs 10-epoch simulation with governance dynamics
- Exports results to `results/` directory:
  - `simulation_results_TIMESTAMP.csv` - Main data for analysis
  - `simulation_raw_TIMESTAMP.json` - Complete cadCAD output
  - `initial_state_TIMESTAMP.json` - Starting conditions
  - `summary_TIMESTAMP.json` - Key statistics

**Output example:**

```
📊 Simulation completed with 31 timesteps
🏁 Final state summary:
   - Total initiatives: 38
   - Accepted initiatives: 35
   - Expired initiatives: 0
   - Circulating supply: 100,000
   - Final epoch: 10
```

### 2. Visualization & Analysis (`src/visualize.py`)

Generates charts and analysis reports from the latest simulation:

```shell
poetry run python src/visualize.py
```

**What it generates:**

- `timeline_TIMESTAMP.png` - Initiative creation and acceptance over time
- `governance_metrics_TIMESTAMP.png` - Acceptance rates and participation
- `user_behavior_TIMESTAMP.png` - Balance distribution and activity patterns
- `analysis_report_TIMESTAMP.txt` - Comprehensive text analysis

**Features:**

- Automatically finds the latest simulation results
- Creates publication-ready charts with seaborn styling
- Generates detailed analysis with governance insights
- Saves all outputs to `results/visualizations/`

### 3. Testing (`pytest`)

Comprehensive test suite with 49 tests covering all components:

```shell
# Run all tests
poetry run pytest

# Run with coverage report
poetry run pytest --cov=src --cov-report=term-missing

# Run specific test categories
poetry run pytest -m unit          # Unit tests only
poetry run pytest -m integration   # Integration tests only
poetry run pytest tests/test_sufs.py  # Specific test file

# Verbose output
poetry run pytest -v
```

**Test coverage:**

- **State management**: Data structures and initialization
- **State Update Functions**: All SUFs with various scenarios
- **Policy functions**: User behavior and time advancement
- **Integration tests**: Full simulation workflows
- **Edge cases**: Error handling and boundary conditions

### 4. Development Workflow

```shell
# 1. Make changes to the code
# 2. Run tests to ensure nothing breaks
poetry run pytest

# 3. Run simulation to test changes
poetry run python src/main.py

# 4. Generate visualizations to see results
poetry run python src/visualize.py

# 5. Check test coverage
poetry run pytest --cov=src
```

## Project Structure

```
src/
├── cadcad/
│   ├── __init__.py
│   ├── allocate.py          # Token allocation logic
│   ├── helpers.py           # Data processing utilities
│   ├── model.py            # cadCAD simulation configuration
│   ├── policies.py         # Policy functions (user behavior)
│   ├── state.py            # State dataclasses and initialization
│   └── sufs.py             # State Update Functions
├── main.py                 # Main simulation runner
└── visualize.py           # Visualization and analysis

tests/
├── conftest.py            # Pytest configuration and fixtures
├── test_policies.py       # Policy function tests
├── test_simulation.py     # Integration tests
├── test_state.py          # State management tests
└── test_sufs.py           # SUF tests

results/                   # Generated simulation outputs
├── simulation_results_*.csv
├── simulation_raw_*.json
├── summary_*.json
├── initial_state_*.json
└── visualizations/
    ├── timeline_*.png
    ├── governance_metrics_*.png
    ├── user_behavior_*.png
    └── analysis_report_*.txt
```

## Key Files

- **`src/cadcad/model.py`**: Core cadCAD configuration with multi-PSUB architecture
- **`src/cadcad/sufs.py`**: State Update Functions handling all governance logic
- **`src/cadcad/state.py`**: Dataclasses for Initiative, Support, and State objects
- **`src/main.py`**: Main entry point with result export functionality
- **`src/visualize.py`**: Automated chart generation and analysis
- **`tests/`**: Comprehensive test suite with 49 tests (100% pass rate)

## Simulation Overview

The simulation models a token-based governance system where:

1. **Initiative Creation**: Users randomly create new initiatives, paying a creation stake
2. **Support Actions**: Users lock tokens to support initiatives for specified durations
3. **Weight Calculation**: Support weight = token_amount × lock_duration_epochs
4. **Support Decay**: All support weights decay by a multiplier each epoch
5. **Acceptance**: Initiatives with weight ≥ threshold are accepted
6. **Token Unlocking**: Tokens are unlocked when initiatives are accepted or supports expire
7. **Initiative Expiration**: Initiatives expire if inactive for too long

## Simulation Parameters

The simulation can be configured by modifying parameters in `src/cadcad/model.py`:

```python
simulation_parameters = {
    "T": range(10),  # Number of timesteps (epochs)
    "N": 1,          # Number of monte carlo runs
    "M": {           # Model parameters
        "acceptance_threshold": 1000.0,           # Weight needed for acceptance
        "decay_multiplier": 0.95,                 # Support decay per epoch
        "initiative_creation_stake": 10.0,        # Cost to create initiative
        "prob_create_initiative": 0.08,           # Probability per user per epoch
        "prob_support_initiative": 0.2,           # Probability per user per epoch
        "max_support_tokens_fraction": 0.5,       # Max % of balance to support with
        "min_lock_duration_epochs": 5,            # Minimum support duration
        "max_lock_duration_epochs": 20,           # Maximum support duration
        "inactivity_period": 10,                  # Epochs before initiative expires
    },
}
```

**Key Parameters:**

- **`acceptance_threshold`**: Higher values make acceptance harder
- **`decay_multiplier`**: Lower values create more urgency (faster decay)
- **`prob_create_initiative`**: Controls initiative creation rate
- **`prob_support_initiative`**: Controls community engagement level
- **`inactivity_period`**: How long initiatives survive without support

## Initial State Configuration

Modify initial conditions in `src/main.py`:

```python
initial_state = generate_initial_state(
    num_users=50,           # Number of participants
    total_supply=1_000_000, # Total token supply
    randomize=True          # Random vs equal token distribution
)
```

## Critical cadCAD Implementation Insights

### State Transition Architecture

This simulation revealed crucial insights about cadCAD's state update mechanics that are essential for complex simulations:

#### The Problem: Intra-Timestep State Isolation

**Issue**: When multiple State Update Functions (SUFs) are defined in the same Partial State Update Block (PSUB), each SUF only receives the state from the **beginning** of the timestep, not the intermediate updates from other SUFs in the same PSUB.

**Example of the Problem**:

```python
# ❌ BROKEN: Single PSUB with multiple SUFs
psubs = [{
    "policies": {"user_actions": p_user_actions},
    "variables": {
        "initiatives": s_create_initiatives,      # Creates initiatives
        "supporters": s_create_supporters,        # Can't see new initiatives!
        "weights": s_calculate_weights,           # Can't see new supporters!
    }
}]
```

In this broken structure:

- `s_create_initiatives` creates new initiatives
- `s_create_supporters` receives the state from the beginning of the timestep (no new initiatives)
- `s_calculate_weights` also receives the original state (no new supporters)

#### The Solution: Multi-PSUB Architecture

**Fix**: Split SUFs into multiple PSUBs so that state updates from one PSUB are visible to the next PSUB within the same timestep.

```python
# ✅ WORKING: Multiple PSUBs with proper state flow
psubs = [
    # PSUB 1: User actions and state creation
    {
        "policies": {"user_actions": p_user_actions},
        "variables": {
            "initiatives": s_create_initiatives,
            "supporters": s_create_supporters,
            "balances": s_update_balances,
        }
    },
    # PSUB 2: Calculations based on updated state
    {
        "policies": {},  # No policies needed
        "variables": {
            "supporters": s_apply_decay,           # Sees new supporters from PSUB 1
            "initiatives": s_calculate_weights,    # Sees decayed supporters
        }
    },
    # PSUB 3: Lifecycle management
    {
        "policies": {},
        "variables": {
            "accepted_initiatives": s_process_acceptance,  # Sees updated weights
            "expired_initiatives": s_process_expiration,
            "supporters": s_cleanup_supporters,
        }
    }
]
```

#### Key Principles for cadCAD State Management

1. **PSUB Boundaries**: State updates are only visible across PSUB boundaries, not within the same PSUB
2. **Execution Order**: PSUBs execute sequentially, SUFs within a PSUB execute in parallel conceptually
3. **State Dependency**: If SUF B needs to see updates from SUF A, they must be in different PSUBs
4. **Policy Placement**: Policies should be in the first PSUB that needs their output
5. **Empty Policies**: Later PSUBs can have empty policy dictionaries if they only do state updates

#### Debugging State Flow

To debug state transition issues:

1. **Add state inspection**: Log the state received by each SUF

```python
def s_my_function(params, substep, history, previous_state, policy_input):
    print(f"SUF received {len(previous_state.get('my_key', {}))} items")
    # ... rest of function
```

2. **Check PSUB structure**: Ensure dependent SUFs are in later PSUBs
3. **Verify state keys**: Make sure SUFs return the correct state variable names
4. **Test incrementally**: Add SUFs one at a time to isolate issues

#### Performance Considerations

- **More PSUBs = More Timesteps**: Each PSUB creates a substep, so 3 PSUBs × 10 epochs = 30 timesteps
- **State Serialization**: Each PSUB boundary requires state serialization/deserialization
- **Memory Usage**: More intermediate states are stored in the simulation results

This architecture enables complex, multi-stage state updates while maintaining cadCAD's deterministic execution model.

## Implementation Notes

This simulation uses the full cadCAD framework with proper state management. The multi-PSUB architecture ensures that complex state dependencies are handled correctly, enabling realistic modeling of token-based governance dynamics.
