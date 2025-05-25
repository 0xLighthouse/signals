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

## Running the Simulation

```shell
# Install dependencies
poetry install

# Run the simulation
poetry run python src/main.py
```

## Simulation Overview

The simulation models a token-based governance system where:

1. **Initiative Creation**: Users randomly create new initiatives, paying a creation stake
2. **Support Actions**: Users lock tokens to support initiatives for specified durations
3. **Weight Calculation**: Support weight = token_amount × lock_duration_epochs
4. **Support Decay**: All support weights decay by a multiplier each epoch
5. **Acceptance**: Initiatives with weight ≥ threshold are accepted
6. **Token Unlocking**: Tokens are unlocked when initiatives are accepted or supports expire
7. **Initiative Expiration**: Initiatives expire if inactive for too long

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
