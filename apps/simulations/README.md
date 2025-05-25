# Initiative Dynamics Simulation

This package contains a simulation of initiative dynamics for the Signals platform. It demonstrates how initiatives are created, supported, and accepted over time.

## Features

- Simulates initiative creation and support over time
- Tracks initiative acceptance when support crosses a threshold
- Displays detailed logs of simulation progress
- Provides summary statistics at the end of the simulation

## Running the Simulation

```shell
# Install dependencies
poetry install

# Run the simulation
poetry run python src/main.py
```

## Simulation Overview

The simulation models a system where:

1. New initiatives are created randomly over time
2. Existing initiatives receive varying levels of support
3. Initiatives that reach a support threshold are accepted
4. The state of all initiatives is tracked and summarized

## Implementation Notes

This is a simplified version that does not use the full cadCAD framework due to compatibility issues. Future versions may incorporate more sophisticated modeling techniques.