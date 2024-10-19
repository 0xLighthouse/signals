// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/mocks/MockERC20.sol';

import {Signals} from '../Signals.sol';
import {DecayCurves} from '../DecayCurves.sol';

contract DecayTest is Test {
  
  /// @notice Test the linear decay curve
  function testLinearDecayCurve() public pure {
    uint256 lockDuration = 20;
    uint256 lockAmount = 50_000 * 1e18;
    uint256 currentInterval = 3;
    uint256[] memory curveParameters = new uint256[](1);

    // A parameter value of 11e17 is the equivalent of 1.1 in base 1e18.
    curveParameters[0] = 11e17;
    // The starting weight will be 50k * 20 = 1M
    // After 3 intervals, the weight should reduce by 3 / 20. Multiple by parameter means 3.3 / 20.
    // 1M - (3.3 / 20 * 1M) = 165_000
    assertEq(
      DecayCurves.linear(lockDuration, lockAmount, currentInterval, curveParameters),
      835_000 * 1e18
    );
  }

  /// @notice Test the exponential decay curve
  function testExponentialDecayCurve() public pure {
    uint256 lockDuration = 20;
    uint256 lockAmount = 50_000 * 1e18;
    uint256 currentInterval = 3;
    uint256[] memory curveParameters = new uint256[](1);

    // A parameter value of 9e17 is the equivalent of 0.9 in base 1e18.
    curveParameters[0] = 9e17;
    // The starting weight will be 50k * 20 = 1M
    // After 3 intervals, the weight should be 1M * 0.9^3 = 729_000
    assertEq(
      DecayCurves.exponential(lockDuration, lockAmount, currentInterval, curveParameters),
      729_000 * 1e18
    );
  }

  /// @notice Passing 0 for interval must always return the starting weight
  function testDecayIntervalZero() public pure {
    uint256 lockDuration = 20;
    uint256 lockAmount = 50_000 * 1e18;
    uint256[] memory curveParameters = new uint256[](1);
    curveParameters[0] = 9e17;

    assertEq(
      DecayCurves.linear(lockDuration, lockAmount, 0, curveParameters),
      lockAmount * lockDuration
    );
    assertEq(
      DecayCurves.exponential(lockDuration, lockAmount, 0, curveParameters),
      lockAmount * lockDuration
    );
  }
}
