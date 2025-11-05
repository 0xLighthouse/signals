// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {SignalsConstants} from "./utils/Constants.sol";

library DecayCurves {
    /// @notice Thrown when curve parameters length is invalid
    error DecayCurves_InvalidCurveParameters();

    /// @notice Thrown when current interval exceeds lock duration
    error DecayCurves_InvalidInterval();
    /**
     * @notice Linear decay curve
     * @param lockDuration Total number of intervals of lock
     * @param lockAmount Amount of tokens locked
     * @param currentInterval How many intervals have passed
     * @param curveParameters Linear takes just one value. e.g. 1e18 = 1:1 linear decay
     * @return The weight of the lock at the current interval
     */
    function linear(uint256 lockDuration, uint256 lockAmount, uint256 currentInterval, uint256[] memory curveParameters)
        internal
        pure
        returns (uint256)
    {
        // Validate curve parameters - linear decay requires exactly one parameter
        if (curveParameters.length != SignalsConstants.DECAY_CURVE_PARAM_LENGTH) {
            revert DecayCurves_InvalidCurveParameters();
        }

        // Ensure we haven't passed the lock duration
        if (currentInterval > lockDuration) {
            revert DecayCurves_InvalidInterval();
        }

        // Linear decay formula: weight = lockAmount * lockDuration - (lockAmount * currentInterval * decayRate)
        // Example: 100 tokens, 10 intervals, decay rate 1e18 (1:1), at interval 5:
        //   weight = 100 * 10 - (100 * 5 * 1e18) / 1e18 = 1000 - 500 = 500
        // The weight starts at lockAmount * lockDuration and decreases linearly
        uint256 weight = lockAmount * lockDuration - (lockAmount * currentInterval * curveParameters[0]) / SignalsConstants.PRECISION;

        // Floor the weight at the original lock amount
        // This ensures early supporters always have at least their nominal value as weight
        if (weight < lockAmount) {
            return lockAmount;
        }

        return weight;
    }

    /**
     * @notice Exponential decay curve
     * @param lockDuration Total number of intervals of lock
     * @param lockAmount Amount of tokens locked
     * @param currentInterval How many intervals have passed
     * @param curveParameters This curve takes just one value. e.g. 9e17 = 0.9 (10% reduced each interval)
     * @return The weight of the lock at the current interval
     */
    function exponential(
        uint256 lockDuration,
        uint256 lockAmount,
        uint256 currentInterval,
        uint256[] memory curveParameters
    ) internal pure returns (uint256) {
        // Validate curve parameters - exponential decay requires exactly one parameter (decay multiplier)
        if (curveParameters.length != SignalsConstants.DECAY_CURVE_PARAM_LENGTH) {
            revert DecayCurves_InvalidCurveParameters();
        }

        // Ensure we haven't passed the lock duration
        if (currentInterval > lockDuration) {
            revert DecayCurves_InvalidInterval();
        }

        // Exponential decay formula: weight = initialWeight * (decayMultiplier ^ currentInterval)
        // Start with maximum weight (lockAmount * lockDuration)
        uint256 weight = lockAmount * lockDuration;

        // Apply exponential decay by multiplying by the decay factor for each elapsed interval
        // Example: 1000 initial weight, 0.9 decay rate (90%), 3 intervals:
        //   After interval 1: 1000 * 0.9 = 900
        //   After interval 2: 900 * 0.9 = 810
        //   After interval 3: 810 * 0.9 = 729
        // This creates an accelerating decay curve (faster decay over time)
        for (uint256 i = 0; i < currentInterval; i++) {
            weight = (weight * curveParameters[0]) / SignalsConstants.PRECISION;
        }

        // Floor the weight at the original lock amount
        // This ensures supporters always have at least their nominal value as weight
        if (weight < lockAmount) {
            return lockAmount;
        }

        return weight;
    }
}
