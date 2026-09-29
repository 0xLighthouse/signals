// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {DecayCurves} from "../src/DecayCurves.sol";

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
        assertEq(DecayCurves.linear(lockDuration, lockAmount, currentInterval, curveParameters), 835_000 * 1e18);
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
        assertEq(DecayCurves.exponential(lockDuration, lockAmount, currentInterval, curveParameters), 729_000 * 1e18);
    }

    /// @notice Passing 0 for interval must always return the starting weight
    function testDecayIntervalZero() public pure {
        uint256 lockDuration = 20;
        uint256 lockAmount = 50_000 * 1e18;
        uint256[] memory curveParameters = new uint256[](1);
        curveParameters[0] = 9e17;

        assertEq(DecayCurves.linear(lockDuration, lockAmount, 0, curveParameters), lockAmount * lockDuration);
        assertEq(DecayCurves.exponential(lockDuration, lockAmount, 0, curveParameters), lockAmount * lockDuration);
    }

    /// @notice A linear rate above 1e18 must floor at the lock amount instead of underflowing
    function testLinearDecayFloorsWhenDecayExceedsStartingWeight() public pure {
        uint256 lockDuration = 20;
        uint256 lockAmount = 50_000 * 1e18;
        uint256[] memory curveParameters = new uint256[](1);
        curveParameters[0] = 11e17;

        // Interval 18: 1M - (18 * 1.1 / 20 * 1M) = 10_000, below the floor
        assertEq(DecayCurves.linear(lockDuration, lockAmount, 18, curveParameters), lockAmount);
        // Interval 19: decay (1.045M) is larger than the starting weight (1M)
        assertEq(DecayCurves.linear(lockDuration, lockAmount, 19, curveParameters), lockAmount);
        assertEq(DecayCurves.linear(lockDuration, lockAmount, 20, curveParameters), lockAmount);
    }

    /// @notice The linear curve is unchanged wherever it did not underflow before
    function testFuzzLinearDecayMatchesFormula(
        uint256 lockDuration,
        uint256 lockAmount,
        uint256 currentInterval,
        uint256 rate
    ) public pure {
        lockDuration = bound(lockDuration, 1, 365);
        lockAmount = bound(lockAmount, 1, 1e30);
        currentInterval = bound(currentInterval, 0, lockDuration);
        rate = bound(rate, 0, 5e18);
        uint256[] memory curveParameters = new uint256[](1);
        curveParameters[0] = rate;

        uint256 initialWeight = lockAmount * lockDuration;
        uint256 decay = (lockAmount * currentInterval * rate) / 1e18;
        uint256 expected = decay >= initialWeight ? lockAmount : initialWeight - decay;
        if (expected < lockAmount) expected = lockAmount;

        assertEq(
            DecayCurves.linear(lockDuration, lockAmount, currentInterval, curveParameters), expected
        );
    }
}
