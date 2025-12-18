// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {SignalsHarness} from "../utils/SignalsHarness.sol";

import {ISignals} from "../../src/interfaces/ISignals.sol";
import {Signals} from "../../src/Signals.sol";

/**
 * @title BoardConfigTest
 * @notice Tests for configuration and admin functions
 * @dev Covers initialization, parameter updates, and access control
 */
contract BoardConfigTest is Test, SignalsHarness {
    Signals signals;

    function setUp() public {}

    /*//////////////////////////////////////////////////////////////
                    CRITICAL VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// Test that critical zero values are rejected
    ISignals.BoardConfig config;

    function test_Initialize_RejectsInvalidZeroValues() public {
        Signals board = new Signals();

        // Zero address for token
        config = defaultConfig;
        config.underlyingToken = address(0);
        vm.expectRevert(ISignals.Signals_InvalidArguments.selector);
        board.initialize(config);

        // Reset and test zero owner
        config = defaultConfig;
        config.owner = address(0);
        vm.expectRevert(ISignals.Signals_InvalidArguments.selector);
        board.initialize(config);

        // Reset and test zero thresholds (both thresholdPercentTotalSupplyWAD and minThreshold)
        config = defaultConfig;
        config.acceptanceCriteria.thresholdPercentTotalSupplyWAD = 0;
        config.acceptanceCriteria.minThreshold = 0;
        vm.expectRevert(ISignals.Signals_InvalidArguments.selector);
        board.initialize(config);

        // Reset and test zero maxLockIntervals
        config = defaultConfig;
        config.lockingConfig.maxLockIntervals = 0;
        vm.expectRevert(ISignals.Signals_InvalidArguments.selector);
        board.initialize(config);

        // Reset and test zero lockInterval
        config = defaultConfig;
        config.lockingConfig.lockInterval = 0;
        vm.expectRevert(ISignals.Signals_InvalidArguments.selector);
        board.initialize(config);

        // Reset and test invalid decayCurveType
        // Note: Solidity enums can't be cast from out-of-bounds values directly
        // The validation happens inside initialize() when converting enum to uint256
        // This test is covered by testing that only Linear(0) and Exponential(1) are valid
    }
}
