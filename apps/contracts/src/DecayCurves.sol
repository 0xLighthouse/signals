// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

library DecayCurves {
  /// @notice Linear decay curve
  /// @param lockDuration Total number of intervals of lock
  /// @param lockAmount Amount of tokens locked
  /// @param currentInterval How many intervals have passed
  /// @param curveParameters Linear takes just one value. e.g. 1e18 = 1:1 linear decay
  /// @return The weight of the lock at the current interval

  function linear(uint256 lockDuration, uint256 lockAmount, uint256 currentInterval, uint256[] memory curveParameters) internal pure returns (uint256) {

    require(curveParameters.length == 1, 'Invalid curve parameters');
    require(currentInterval <= lockDuration, 'Invalid interval');

    uint256 weight = lockAmount * lockDuration - lockAmount * currentInterval * curveParameters[0] / 1e18;
    if (weight < lockAmount) {
      return lockAmount;
    }

    return weight;
  }

  /// @notice Exponential decay curve
  /// @param lockDuration Total number of intervals of lock
  /// @param lockAmount Amount of tokens locked
  /// @param currentInterval How many intervals have passed
  /// @param curveParameters This curve takes just one value. e.g. 9e17 = 0.9 (10% reduced each interval)
  /// @return The weight of the lock at the current interval

  function exponential(uint256 lockDuration, uint256 lockAmount, uint256 currentInterval, uint256[] memory curveParameters) internal pure returns (uint256) {


    require(curveParameters.length == 1, 'Invalid curve parameters');
    require(currentInterval <= lockDuration, 'Invalid interval');

    uint256 weight = lockAmount * lockDuration;
    console.log("Starting Weight", weight);
    console.log("currentInterval", currentInterval);
    for (uint256 i = 0; i < currentInterval; i++) {
      weight = (weight * curveParameters[0]) / 1e18;
      console.log("Step", i, weight);
    }
    if (weight < lockAmount) {
      return lockAmount;
    }

    return weight;
  }
}

    //TODO: Revisit this for differential decay
    /*
      // Using a differential decay model instead of linear decay
      // dW/dt = -k * W where k is a constant and W is the current weight
      // W(t) = W0 * exp(-k * t)
      // For simplicity, k is set to 1 / weightedDuration for an exponential decay over the duration
    
      uint256 decayFactor = exp((elapsedTime * 1e18) / lockInfo.weightedDuration);
      uint256 currentWeight = (lockInfo.totalAmount * remainingDuration * decayFactor);

      return currentWeight;
    */