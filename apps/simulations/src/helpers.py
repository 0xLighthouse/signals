import json
import os
from datetime import datetime

from cadcad.helpers import results_to_dataframe


def save_simulation_results(results, initial_state, output_dir="results"):
    """Save simulation results to files for analysis."""
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)

    # Generate timestamp for unique filenames
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    # Convert to DataFrame and save as CSV
    df = results_to_dataframe(results)
    csv_path = os.path.join(output_dir, f"simulation_results_{timestamp}.csv")
    df.to_csv(csv_path, index=False)
    print(f"📄 Simulation results saved to: {csv_path}")

    # Save raw results as JSON (with datetime serialization and tuple key handling)
    def json_serializer(obj):
        if isinstance(obj, datetime):
            return obj.isoformat()
        elif isinstance(obj, set):
            return list(obj)
        raise TypeError(f"Object of type {type(obj)} is not JSON serializable")

    # Convert tuple keys to strings for JSON compatibility
    def convert_tuple_keys(data):
        if isinstance(data, dict):
            new_dict = {}
            for key, value in data.items():
                if isinstance(key, tuple):
                    # Convert tuple to string representation
                    new_key = f"{key[0]}_{key[1]}" if len(key) == 2 else str(key)
                else:
                    new_key = key
                new_dict[new_key] = convert_tuple_keys(value)
            return new_dict
        elif isinstance(data, list):
            return [convert_tuple_keys(item) for item in data]
        else:
            return data

    # Convert the results to handle tuple keys
    json_compatible_results = convert_tuple_keys(results)

    json_path = os.path.join(output_dir, f"simulation_raw_{timestamp}.json")
    with open(json_path, "w") as f:
        json.dump(json_compatible_results, f, indent=2, default=json_serializer)
    print(f"📁 Raw results saved to: {json_path}")

    # Save initial state
    initial_state_path = os.path.join(output_dir, f"initial_state_{timestamp}.json")
    with open(initial_state_path, "w") as f:
        json.dump(initial_state, f, indent=2, default=json_serializer)
    print(f"🏁 Initial state saved to: {initial_state_path}")

    # Save summary statistics
    summary = print_summary(results, df)
    summary_path = os.path.join(output_dir, f"summary_{timestamp}.json")
    with open(summary_path, "w") as f:
        json.dump(summary, f, indent=2, default=json_serializer)
    print(f"📈 Summary statistics saved to: {summary_path}")

    return {
        "csv_path": csv_path,
        "json_path": json_path,
        "initial_state_path": initial_state_path,
        "summary_path": summary_path,
        "timestamp": timestamp,
    }


def print_summary(results, df):
    """Generate summary statistics from simulation results."""
    if not results:
        return {}

    final_state = results[-1]

    # Count initiatives by status
    total_initiatives = len(final_state.get("initiatives", {}))
    accepted_initiatives = len(final_state.get("accepted_initiatives", set()))
    expired_initiatives = len(final_state.get("expired_initiatives", set()))
    pending_initiatives = total_initiatives - accepted_initiatives - expired_initiatives

    # Token statistics
    final_balances = final_state.get("balances", {})
    total_user_tokens = sum(final_balances.values())
    circulating_supply = final_state.get("circulating_supply", 0)

    # Reward statistics
    reward_earnings = final_state.get("reward_earnings", {})
    reward_history = final_state.get("reward_history", [])

    # Calculate reward statistics
    total_rewards = sum(reward_earnings.values())
    avg_reward_per_user = total_rewards / len(reward_earnings) if reward_earnings else 0

    # Analyze reward distribution
    reward_earnings_list = list(reward_earnings.values())
    reward_earnings_list.sort()
    median_reward = (
        reward_earnings_list[len(reward_earnings_list) // 2] if reward_earnings_list else 0
    )

    # Calculate reward concentration (Gini-like metric)
    if reward_earnings_list:
        total_reward = sum(reward_earnings_list)
        cumulative_reward = 0
        concentration_score = 0
        for i, reward in enumerate(reward_earnings_list):
            cumulative_reward += reward
            concentration_score += (i + 1) * reward
        concentration_score = (2 * concentration_score) / (
            len(reward_earnings_list) * total_reward
        ) - 1
    else:
        concentration_score = 0

    # Analyze reward patterns
    reward_by_weight = {}
    reward_by_lock = {}
    for entry in reward_history:
        weight_bucket = round(entry["weight_percentage"] * 10) / 10  # Round to nearest 0.1
        lock_bucket = entry["lock_duration"]

        reward_by_weight[weight_bucket] = (
            reward_by_weight.get(weight_bucket, 0) + entry["reward_amount"]
        )
        reward_by_lock[lock_bucket] = reward_by_lock.get(lock_bucket, 0) + entry["reward_amount"]

    summary = {
        "simulation_metadata": {
            "total_timesteps": len(results),
            "final_epoch": final_state.get("current_epoch", 0),
            "total_users": len(final_balances),
            "simulation_completed": datetime.now().isoformat(),
        },
        "initiative_statistics": {
            "total_created": total_initiatives,
            "accepted": accepted_initiatives,
            "expired": expired_initiatives,
            "pending": pending_initiatives,
            "acceptance_rate": accepted_initiatives / total_initiatives
            if total_initiatives > 0
            else 0,
        },
        "token_statistics": {
            "total_supply": final_state.get("total_supply", 0),
            "circulating_supply": circulating_supply,
            "total_user_tokens": total_user_tokens,
            "locked_tokens": final_state.get("total_supply", 0) - circulating_supply,
            "average_user_balance": total_user_tokens / len(final_balances)
            if final_balances
            else 0,
        },
        "reward_statistics": {
            "total_rewards_distributed": total_rewards,
            "users_earning_rewards": len(reward_earnings),
            "average_reward_per_user": avg_reward_per_user,
            "median_reward": median_reward,
            "reward_concentration": concentration_score,  # 0 = equal distribution, 1 = highly concentrated
            "reward_by_initiative_weight": reward_by_weight,
            "reward_by_lock_duration": reward_by_lock,
            "top_reward_earners": dict(
                sorted(reward_earnings.items(), key=lambda x: x[1], reverse=True)[:10]
            ),
        },
        "governance_parameters": {
            "acceptance_threshold": final_state.get("acceptance_threshold", 0),
            "inactivity_period": final_state.get("inactivity_period", 0),
            "decay_multiplier": final_state.get("decay_multiplier", 0),
        },
    }

    return summary
