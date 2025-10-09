// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {SignalsHarness} from "../utils/SignalsHarness.sol";

import {ISignals} from "../../src/interfaces/ISignals.sol";
import {Signals} from "../../src/Signals.sol";

/**
 * @title SignalsConfigValidationTest
 * @notice Tests for configuration validation guards
 * @dev Ensures dangerous configurations are rejected at initialization
 */
contract SignalsConfigValidationTest is Test, SignalsHarness {
    Signals signals;

    function setUp() public {
        signals = new Signals();
    }

    /*//////////////////////////////////////////////////////////////
                    CRITICAL VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// Test that critical zero values are rejected
    function test_Initialize_RejectsInvalidZeroValues() public {
        ISignals.BoardConfig memory config = defaultConfig;

        // Zero address for token
        config.underlyingToken = address(0);
        vm.expectRevert(ISignals.Signals_ZeroAddressToken.selector);
        signals.initialize(config);

        // Reset and test zero owner
        signals = new Signals();
        config = defaultConfig;
        config.owner = address(0);
        vm.expectRevert(ISignals.Signals_ZeroAddressOwner.selector);
        signals.initialize(config);

        // Reset and test zero acceptanceThreshold
        signals = new Signals();
        config = defaultConfig;
        config.acceptanceThreshold = 0;
        vm.expectRevert(ISignals.Signals_ZeroAcceptanceThreshold.selector);
        signals.initialize(config);

        // Reset and test zero maxLockIntervals
        signals = new Signals();
        config = defaultConfig;
        config.maxLockIntervals = 0;
        vm.expectRevert(ISignals.Signals_ZeroMaxLockIntervals.selector);
        signals.initialize(config);

        // Reset and test zero lockInterval
        signals = new Signals();
        config = defaultConfig;
        config.lockInterval = 0;
        vm.expectRevert(ISignals.Signals_ZeroLockInterval.selector);
        signals.initialize(config);

        // Reset and test zero proposalCap
        signals = new Signals();
        config = defaultConfig;
        config.proposalCap = 0;
        vm.expectRevert(ISignals.Signals_ZeroProposalCap.selector);
        signals.initialize(config);

        // Reset and test invalid decayCurveType
        signals = new Signals();
        config = defaultConfig;
        config.decayCurveType = 2;
        vm.expectRevert(ISignals.Signals_InvalidDecayCurveType.selector);
        signals.initialize(config);
    }

    /*//////////////////////////////////////////////////////////////
                    VALID CONFIGURATIONS
    //////////////////////////////////////////////////////////////*/

    /// Test minimal valid configuration
    function test_Initialize_MinimalConfig() public {
        ISignals.BoardConfig memory config = ISignals.BoardConfig({
            version: "1.0",
            owner: _deployer,
            underlyingToken: address(_tokenERC20),
            acceptanceThreshold: 1, // Minimal non-zero
            maxLockIntervals: 1,
            proposalCap: 1,
            lockInterval: 1,
            decayCurveType: 0,
            decayCurveParameters: new uint256[](1),
            proposerRequirements: ISignals.ProposerRequirements({
                eligibilityType: ISignals.EligibilityType.None,
                minBalance: 0,
                minHoldingDuration: 0,
                threshold: 1 // Minimal threshold when eligibility type is None
            }),
            participantRequirements: ISignals.ParticipantRequirements({
                eligibilityType: ISignals.EligibilityType.None,
                minBalance: 0,
                minHoldingDuration: 0
            }),
            releaseLockDuration: 0,
            boardOpensAt: 0,
            boardIncentives: ISignals.BoardIncentives({
                enabled: false,
                curveType: 0,
                curveParameters: new uint256[](0)
            })
        });

        signals.initialize(config);
        assertEq(signals.getProposerRequirements().threshold, 1);
        assertEq(signals.acceptanceThreshold(), 1);
    }

    /// Test production configuration
    function test_Initialize_ProductionConfig() public {
        ISignals.BoardConfig memory config = ISignals.BoardConfig({
            version: "1.0",
            owner: _deployer,
            underlyingToken: address(_tokenERC20),
            acceptanceThreshold: 500_000 * 1e18,
            maxLockIntervals: 365,
            proposalCap: 10,
            lockInterval: 1 days,
            decayCurveType: 0,
            decayCurveParameters: new uint256[](1),
            proposerRequirements: ISignals.ProposerRequirements({
                eligibilityType: ISignals.EligibilityType.MinBalance,
                minBalance: 10_000 * 1e18,
                minHoldingDuration: 0,
                threshold: 50_000 * 1e18
            }),
            participantRequirements: ISignals.ParticipantRequirements({
                eligibilityType: ISignals.EligibilityType.None,
                minBalance: 0,
                minHoldingDuration: 0
            }),
            releaseLockDuration: 7 days,
            boardOpensAt: 0,
            boardIncentives: ISignals.BoardIncentives({
                enabled: false,
                curveType: 0,
                curveParameters: new uint256[](0)
            })
        });

        signals.initialize(config);
        assertEq(signals.getProposerRequirements().threshold, 50_000 * 1e18);
        assertEq(signals.acceptanceThreshold(), 500_000 * 1e18);
        assertEq(signals.releaseLockDuration(), 7 days);
    }

    /// Test that both decay types are valid
    function test_Initialize_BothDecayTypes() public {
        ISignals.BoardConfig memory config = defaultConfig;

        // Linear
        config.decayCurveType = 0;
        signals.initialize(config);
        assertEq(signals.decayCurveType(), 0);

        // Exponential
        signals = new Signals();
        config.decayCurveType = 1;
        signals.initialize(config);
        assertEq(signals.decayCurveType(), 1);
    }
}
