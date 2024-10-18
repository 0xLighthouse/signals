// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

library DecayCurves {
  /// @notice Linear decay curve
  /// @param _lockDuration Total number of intervals of lock
  /// @param _lockAmount Amount of tokens locked
  /// @param _currentInterval How many intervals have passed
  /// @param _curveParameters Linear takes just one value. e.g. 1e18 = 1:1 linear decay
  /// @return The weight of the lock at the current interval

  function linear(uint256 _lockDuration, uint256 _lockAmount, uint256 _currentInterval, uint256[] memory _curveParameters) internal pure returns (uint256) {

    require(_curveParameters.length == 1, 'Invalid curve parameters');
    require(_currentInterval <= _lockDuration, 'Invalid interval');

    uint256 weight = _lockAmount * _lockDuration - _lockAmount * _currentInterval * _curveParameters[0] / 1e18;
    if (weight < _lockAmount) {
      return _lockAmount;
    }

    return weight;
  }

  /// @notice Exponential decay curve
  /// @param _lockDuration Total number of intervals of lock
  /// @param _lockAmount Amount of tokens locked
  /// @param _currentInterval How many intervals have passed
  /// @param _curveParameters This curve takes just one value. e.g. 9e17 = 0.9 (10% reduced each interval)
  /// @return The weight of the lock at the current interval

  function exponential(uint256 _lockDuration, uint256 _lockAmount, uint256 _currentInterval, uint256[] memory _curveParameters) internal pure returns (uint256) {

    require(_curveParameters.length == 1, 'Invalid curve parameters');
    require(_currentInterval <= _lockDuration, 'Invalid interval');

    uint256 weight = _lockAmount * _lockDuration;
    for (uint256 i = 0; i < _currentInterval; i++) {
      console.log(i, weight);
      weight = (weight * _curveParameters[0]) / 1e18;
    }
    if (weight < _lockAmount) {
      return _lockAmount;
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