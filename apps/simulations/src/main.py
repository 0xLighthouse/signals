import os
import sys

# Import helpers first
from helpers import save_simulation_results

from cadcad.helpers import results_to_dataframe
from cadcad.model import run_simulation
from cadcad.state import generate_initial_state


def main():
    """Main entry point for running the simulation."""
    print("Starting Signals simulation...")

    # Generate initial state
    initial_state = generate_initial_state(num_users=1000, total_supply=1_000_000, randomize=True)
    print(f"Initial state generated with {len(initial_state['balances'])} users.")

    # Run the simulation
    results = run_simulation(initial_state=initial_state)

    # Save results to files
    if results:
        file_paths = save_simulation_results(results, initial_state)

        # Display summary
        df = results_to_dataframe(results)
        print(f"\n📊 Simulation completed with {len(results)} timesteps")
        print(df.head())

        # Print the final state summary
        final_state = results[-1]
        print(f"\n🏁 Final state summary:")
        print(f"   - Total initiatives: {len(final_state.get('initiatives', {}))}")
        print(f"   - Accepted initiatives: {len(final_state.get('accepted_initiatives', set()))}")
        print(f"   - Expired initiatives: {len(final_state.get('expired_initiatives', set()))}")
        print(f"   - Circulating supply: {final_state.get('circulating_supply', 0):,.0f}")
        print(f"   - Locked supply: {final_state.get('locked_supply', 0):,.0f}")
        print(f"   - Rewards distributed: {final_state.get('rewards_distributed', 0):,.0f}")
        print(f"   - Final epoch: {final_state.get('current_epoch', 0)}")

        print(f"\n✅ All results saved with timestamp: {file_paths['timestamp']}")
        print("📈 Run 'python src/visualize.py' to generate charts and analysis!")
    else:
        print("❌ No results to save - simulation may have failed")

    print("\n🎉 Summary: Successfully simulated initiative dynamics over 10 epochs.")


if __name__ == "__main__":
    main()
