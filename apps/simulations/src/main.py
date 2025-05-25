from cadcad.helpers import results_to_dataframe
from cadcad.model import run_simulation
from cadcad.state import generate_initial_state


def main():
    """Main entry point for running the simulation."""
    print("Starting Signals simulation...")

    # Generate initial state
    initial_state = generate_initial_state(num_users=50, total_supply=1_000_000, randomize=True)
    print(f"Initial state generated with {len(initial_state['balances'])} users.")

    # Run the simulation
    results = run_simulation(initial_state=initial_state)

    print(initial_state)

    df = results_to_dataframe(results)
    print(df.head())

    # Print the final state
    if results:
        final_state = results[-1]
        print("\nFinal state:")
        print(final_state)

    print("\nSummary: Successfully simulated initiative dynamics over 10 epochs.")


if __name__ == "__main__":
    main()
