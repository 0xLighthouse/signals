// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/console.sol";

library DecayCurves {
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
        require(curveParameters.length == 1, "Invalid curve parameters");
        require(currentInterval <= lockDuration, "Invalid interval");

        uint256 weight = lockAmount * lockDuration - (lockAmount * currentInterval * curveParameters[0]) / 1e18;
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
        require(curveParameters.length == 1, "Invalid curve parameters");
        require(currentInterval <= lockDuration, "Invalid interval");

        uint256 weight = lockAmount * lockDuration;
        for (uint256 i = 0; i < currentInterval; i++) {
            weight = (weight * curveParameters[0]) / 1e18;
        }
        if (weight < lockAmount) {
            return lockAmount;
        }

        return weight;
    }
}
