#!/usr/bin/env python3
"""
Governance Analysis Insights

This script provides detailed insights and interpretations from the
statistical analysis of the governance system.
"""

import pandas as pd
import numpy as np
import os


def load_latest_results():
    """Load the latest experiment results."""
    csv_files = [f for f in os.listdir("quick_experiments") if f.endswith(".csv")]
    if not csv_files:
        print("No CSV files found in quick_experiments/")
        return None

    latest_csv = max(csv_files, key=lambda x: os.path.getctime(f"quick_experiments/{x}"))
    df = pd.read_csv(f"quick_experiments/{latest_csv}")
    return df[df["success"] == True].copy()


def analyze_governance_attributes(df):
    """Analyze the four key governance attributes."""
    print("🎯 GOVERNANCE ATTRIBUTES ANALYSIS")
    print("=" * 50)

    # Group by distribution
    for dist in df["dist_description"].unique():
        dist_data = df[df["dist_description"] == dist]
        print(f"\n📊 {dist.upper()}:")

        # Preference Intensity
        pref_mean = dist_data["metric_preference_intensity_score"].mean()
        pref_std = dist_data["metric_preference_intensity_score"].std()
        print(f"   🎨 Preference Intensity: {pref_mean:.3f} ± {pref_std:.3f}")
        if pref_mean > 1.0:
            print("      ✅ HIGH - Strong voter preference expression")
        elif pref_mean > 0.5:
            print("      ⚠️  MEDIUM - Moderate preference expression")
        else:
            print("      ❌ LOW - Weak preference expression")

        # Opportunity Cost
        opp_mean = dist_data["metric_opportunity_cost_score"].mean()
        opp_std = dist_data["metric_opportunity_cost_score"].std()
        print(f"   💰 Opportunity Cost: {opp_mean:.3f} ± {opp_std:.3f}")
        if opp_mean > 0.05:
            print("      ✅ HIGH - Strong economic incentives")
        elif opp_mean > 0.01:
            print("      ⚠️  MEDIUM - Moderate economic risk")
        else:
            print("      ❌ LOW - Minimal economic commitment")

        # Sybil Resistance
        sybil_mean = dist_data["metric_sybil_resistance_score"].mean()
        sybil_std = dist_data["metric_sybil_resistance_score"].std()
        print(f"   🛡️  Sybil Resistance: {sybil_mean:.3f} ± {sybil_std:.3f}")
        if sybil_mean > 0.5:
            print("      ✅ HIGH - Strong attack resistance")
        elif sybil_mean > 0.2:
            print("      ⚠️  MEDIUM - Moderate protection")
        else:
            print("      ❌ LOW - Vulnerable to manipulation")

        # Inclusivity
        incl_mean = dist_data["metric_inclusivity_score"].mean()
        incl_std = dist_data["metric_inclusivity_score"].std()
        print(f"   🤝 Inclusivity: {incl_mean:.3f} ± {incl_std:.3f}")
        if incl_mean > 0.5:
            print("      ✅ HIGH - Small holders well represented")
        elif incl_mean > 0.2:
            print("      ⚠️  MEDIUM - Some small holder influence")
        else:
            print("      ❌ LOW - Dominated by large holders")


def analyze_parameter_effects(df):
    """Analyze the effects of different parameters."""
    print("\n\n📈 PARAMETER SENSITIVITY ANALYSIS")
    print("=" * 50)

    # Acceptance Threshold Effects
    print(f"\n🎯 Acceptance Threshold Impact:")
    threshold_corr = df["param_acceptance_threshold"].corr(df["metric_acceptance_rate"])
    print(f"   Correlation with acceptance rate: {threshold_corr:.3f}")

    if threshold_corr < -0.3:
        print("   ✅ STRONG NEGATIVE - Higher thresholds significantly reduce acceptance")
    elif threshold_corr < -0.1:
        print("   ⚠️  MODERATE NEGATIVE - Higher thresholds somewhat reduce acceptance")
    elif threshold_corr > 0.1:
        print("   ❌ POSITIVE - Unexpected: higher thresholds increase acceptance")
    else:
        print("   ➡️  NEUTRAL - Threshold has minimal impact on acceptance")

    # Decay Multiplier Effects
    print(f"\n⏰ Decay Multiplier Impact:")
    decay_corr = df["param_decay_multiplier"].corr(df["metric_preference_intensity_score"])
    print(f"   Correlation with preference intensity: {decay_corr:.3f}")

    if decay_corr > 0.3:
        print("   ✅ STRONG POSITIVE - Slower decay increases preference expression")
    elif decay_corr > 0.1:
        print("   ⚠️  MODERATE POSITIVE - Slower decay somewhat increases intensity")
    elif decay_corr < -0.1:
        print("   ❌ NEGATIVE - Faster decay increases intensity (unexpected)")
    else:
        print("   ➡️  NEUTRAL - Decay rate has minimal impact")


def analyze_distribution_effects(df):
    """Analyze the effects of different token distributions."""
    print("\n\n🏛️  TOKEN DISTRIBUTION IMPACT ANALYSIS")
    print("=" * 50)

    equal_data = df[df["dist_description"] == "Equal distribution"]
    pareto_data = df[df["dist_description"] == "Pareto 80/20"]

    if len(equal_data) > 0 and len(pareto_data) > 0:
        print(f"\n📊 Comparative Analysis:")

        # Acceptance Rate Comparison
        equal_acc = equal_data["metric_acceptance_rate"].mean()
        pareto_acc = pareto_data["metric_acceptance_rate"].mean()
        acc_diff = equal_acc - pareto_acc

        print(f"   🎯 Acceptance Rate:")
        print(f"      Equal: {equal_acc:.3f}")
        print(f"      Pareto: {pareto_acc:.3f}")
        print(f"      Difference: {acc_diff:.3f}")

        if acc_diff > 0.2:
            print("      ✅ Equal distribution significantly more successful")
        elif acc_diff > 0.1:
            print("      ⚠️  Equal distribution moderately more successful")
        elif acc_diff < -0.1:
            print("      ❌ Pareto distribution more successful (unexpected)")
        else:
            print("      ➡️  Similar success rates")

        # Preference Intensity Comparison
        equal_pref = equal_data["metric_preference_intensity_score"].mean()
        pareto_pref = pareto_data["metric_preference_intensity_score"].mean()
        pref_diff = pareto_pref - equal_pref

        print(f"\n   🎨 Preference Intensity:")
        print(f"      Equal: {equal_pref:.3f}")
        print(f"      Pareto: {pareto_pref:.3f}")
        print(f"      Difference: {pref_diff:.3f}")

        if pref_diff > 0.5:
            print("      ✅ Pareto shows much stronger preference expression")
        elif pref_diff > 0.2:
            print("      ⚠️  Pareto shows stronger preference expression")
        else:
            print("      ➡️  Similar preference expression")

        # Inclusivity Comparison
        equal_incl = equal_data["metric_inclusivity_score"].mean()
        pareto_incl = pareto_data["metric_inclusivity_score"].mean()
        incl_diff = pareto_incl - equal_incl

        print(f"\n   🤝 Inclusivity:")
        print(f"      Equal: {equal_incl:.3f}")
        print(f"      Pareto: {pareto_incl:.3f}")
        print(f"      Difference: {incl_diff:.3f}")

        if incl_diff > 0.3:
            print("      ✅ Pareto surprisingly more inclusive")
        elif incl_diff > 0.1:
            print("      ⚠️  Pareto somewhat more inclusive")
        elif incl_diff < -0.1:
            print("      ❌ Equal distribution more inclusive (expected)")
        else:
            print("      ➡️  Similar inclusivity levels")


def provide_recommendations(df):
    """Provide recommendations based on the analysis."""
    print("\n\n💡 RECOMMENDATIONS & INSIGHTS")
    print("=" * 50)

    equal_data = df[df["dist_description"] == "Equal distribution"]
    pareto_data = df[df["dist_description"] == "Pareto 80/20"]

    print(f"\n🎯 Key Findings:")

    # Finding 1: Distribution Impact
    if len(equal_data) > 0 and len(pareto_data) > 0:
        equal_acc = equal_data["metric_acceptance_rate"].mean()
        pareto_acc = pareto_data["metric_acceptance_rate"].mean()
        pareto_pref = pareto_data["metric_preference_intensity_score"].mean()
        equal_pref = equal_data["metric_preference_intensity_score"].mean()

        print(f"\n   1️⃣  Distribution Trade-offs:")
        if equal_acc > pareto_acc and pareto_pref > equal_pref:
            print(
                f"      • Equal distribution → Higher success rate ({equal_acc:.1%} vs {pareto_acc:.1%})"
            )
            print(
                f"      • Pareto distribution → Stronger preferences ({pareto_pref:.2f} vs {equal_pref:.2f})"
            )
            print(
                f"      💡 INSIGHT: Inequality increases preference intensity but reduces overall success"
            )

    # Finding 2: Parameter Sensitivity
    threshold_range = (
        df["param_acceptance_threshold"].max() - df["param_acceptance_threshold"].min()
    )
    decay_range = df["param_decay_multiplier"].max() - df["param_decay_multiplier"].min()

    print(f"\n   2️⃣  Parameter Sensitivity:")
    print(f"      • Tested threshold range: {threshold_range:,}")
    print(f"      • Tested decay range: {decay_range:.2f}")

    threshold_corr = abs(df["param_acceptance_threshold"].corr(df["metric_acceptance_rate"]))
    decay_corr = abs(df["param_decay_multiplier"].corr(df["metric_preference_intensity_score"]))

    if threshold_corr > decay_corr:
        print(f"      💡 INSIGHT: Acceptance threshold more impactful than decay rate")
    else:
        print(f"      💡 INSIGHT: Decay rate more impactful than acceptance threshold")

    # Finding 3: System Performance
    overall_success = df["metric_acceptance_rate"].mean()
    overall_intensity = df["metric_preference_intensity_score"].mean()

    print(f"\n   3️⃣  Overall System Performance:")
    print(f"      • Average acceptance rate: {overall_success:.1%}")
    print(f"      • Average preference intensity: {overall_intensity:.2f}")

    if overall_success > 0.7:
        print(f"      ✅ HIGH SUCCESS - System effectively processes initiatives")
    elif overall_success > 0.5:
        print(f"      ⚠️  MODERATE SUCCESS - Room for improvement")
    else:
        print(f"      ❌ LOW SUCCESS - System may be too restrictive")

    print(f"\n🔮 Recommendations for Future Research:")
    print(f"   • Test wider parameter ranges to find optimal settings")
    print(f"   • Investigate why sybil resistance scores are consistently low")
    print(f"   • Explore mechanisms to improve inclusivity in equal distributions")
    print(f"   • Study longer-term dynamics with more epochs")
    print(f"   • Test additional distribution types (bimodal, custom)")


def main():
    """Main analysis function."""
    print("🔍 GOVERNANCE SYSTEM INSIGHTS & ANALYSIS")
    print("=" * 60)

    df = load_latest_results()
    if df is None:
        print("❌ No data available for analysis")
        return

    print(f"📊 Analyzing {len(df)} successful experiments")

    # Run all analyses
    analyze_governance_attributes(df)
    analyze_parameter_effects(df)
    analyze_distribution_effects(df)
    provide_recommendations(df)

    print(f"\n\n✅ Analysis complete!")
    print(f"📁 Visualizations available in: plots/")
    print(f"📊 Raw data available in: quick_experiments/")


if __name__ == "__main__":
    main()
