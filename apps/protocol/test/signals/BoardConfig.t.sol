// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {SignalsHarness} from "../utils/SignalsHarness.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ISignals} from "../../src/interfaces/ISignals.sol";
import {Signals} from "../../src/Signals.sol";

/**
 * @title BoardConfigTest
 * @notice Tests for configuration and admin functions
 * @dev Covers initialization, parameter updates, and access control
 */
contract BoardConfigTest is Test, SignalsHarness {
    ISignals signals;

    function setUp() public {
        bool dealTokens = true;
        (, signals) = deploySignalsWithFactory(dealTokens);
    }

    /*//////////////////////////////////////////////////////////////
                        INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Config_DefaultValues() public view {
        assertEq(Ownable(address(signals)).owner(), address(_deployer));
        assertEq(signals.underlyingToken(), address(_tokenERC20));
        assertEq(signals.getProposerRequirements().threshold, defaultConfig.proposerRequirements.threshold);
        assertEq(signals.acceptanceThreshold(), defaultConfig.acceptanceThreshold);
        assertEq(signals.maxLockIntervals(), defaultConfig.maxLockIntervals);
        assertEq(signals.proposalCap(), defaultConfig.proposalCap);
        assertEq(signals.lockInterval(), defaultConfig.lockInterval);
        assertEq(signals.decayCurveType(), defaultConfig.decayCurveType);
        assertEq(signals.totalInitiatives(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                        INACTIVITY THRESHOLD TESTS
    //////////////////////////////////////////////////////////////*/

    // Test updating inactivity threshold as owner
    function test_SetInactivityThreshold_Success() public {
        // Update the inactivity threshold
        vm.startPrank(_deployer);
        signals.setInactivityThreshold(30 days);

        // Check that the threshold is updated
        assertEq(signals.activityTimeout(), 30 days);
    }

    function test_SetInactivityThreshold_OnlyOwner() public {
        vm.startPrank(_alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _alice));
        signals.setInactivityThreshold(30 days);
    }

    /*//////////////////////////////////////////////////////////////
                    CRITICAL VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// Test that critical zero values are rejected
    function test_Initialize_RejectsInvalidZeroValues() public {
        ISignals.BoardConfig memory config = defaultConfig;
        ISignals board;

        // Zero address for token
        board = ISignals(address(new Signals()));
        config = defaultConfig;
        config.underlyingToken = address(0);
        vm.expectRevert(ISignals.Signals_ZeroAddressToken.selector);
        board.initialize(config);

        // Reset and test zero owner
        board = ISignals(address(new Signals()));
        config = defaultConfig;
        config.owner = address(0);
        vm.expectRevert(ISignals.Signals_ZeroAddressOwner.selector);
        board.initialize(config);

        // Reset and test zero acceptanceThreshold
        board = ISignals(address(new Signals()));
        config = defaultConfig;
        config.acceptanceThreshold = 0;
        vm.expectRevert(ISignals.Signals_ZeroAcceptanceThreshold.selector);
        board.initialize(config);

        // Reset and test zero maxLockIntervals
        board = ISignals(address(new Signals()));
        config = defaultConfig;
        config.maxLockIntervals = 0;
        vm.expectRevert(ISignals.Signals_ZeroMaxLockIntervals.selector);
        board.initialize(config);

        // Reset and test zero lockInterval
        board = ISignals(address(new Signals()));
        config = defaultConfig;
        config.lockInterval = 0;
        vm.expectRevert(ISignals.Signals_ZeroLockInterval.selector);
        board.initialize(config);

        // Reset and test zero proposalCap
        board = ISignals(address(new Signals()));
        config = defaultConfig;
        config.proposalCap = 0;
        vm.expectRevert(ISignals.Signals_ZeroProposalCap.selector);
        board.initialize(config);

        // Reset and test invalid decayCurveType
        board = ISignals(address(new Signals()));
        config = defaultConfig;
        config.decayCurveType = 2;
        vm.expectRevert(ISignals.Signals_InvalidDecayCurveType.selector);
        board.initialize(config);
    }

    /*//////////////////////////////////////////////////////////////
                    VALID CONFIGURATIONS
    //////////////////////////////////////////////////////////////*/

    /// Test minimal valid configuration
    function test_Initialize_MinimalConfig() public {
        ISignals board = ISignals(address(new Signals()));
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
            boardOpenAt: 0,
            boardClosedAt: 0
        });

        board.initialize(config);
        assertEq(board.getProposerRequirements().threshold, 1);
        assertEq(board.acceptanceThreshold(), 1);
    }

    /// Test production configuration
    function test_Initialize_ProductionConfig() public {
        ISignals board = ISignals(address(new Signals()));
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
            boardOpenAt: 0,
            boardClosedAt: 0
        });

        board.initialize(config);
        assertEq(board.getProposerRequirements().threshold, 50_000 * 1e18);
        assertEq(board.acceptanceThreshold(), 500_000 * 1e18);
        assertEq(board.releaseLockDuration(), 7 days);
    }

    /// Test that both decay types are valid
    function test_Initialize_BothDecayTypes() public {
        ISignals.BoardConfig memory config = defaultConfig;
        ISignals board;

        // Linear
        board = ISignals(address(new Signals()));
        config.decayCurveType = 0;
        board.initialize(config);
        assertEq(board.decayCurveType(), 0);

        // Exponential
        board = ISignals(address(new Signals()));
        config.decayCurveType = 1;
        board.initialize(config);
        assertEq(board.decayCurveType(), 1);
    }

    /*//////////////////////////////////////////////////////////////
                    TODO: PARAMETER UPDATE TESTS
    //////////////////////////////////////////////////////////////*/

    // TODO: Test setting proposal threshold
    // function test_SetProposalThreshold_Success() public {}

    // TODO: Test setting acceptance threshold
    // function test_SetAcceptanceThreshold_Success() public {}

    // TODO: Test only owner can update parameters
    // function test_SetParameters_OnlyOwner() public {}

    /*//////////////////////////////////////////////////////////////
                    TODO: PAUSE/UNPAUSE TESTS
    //////////////////////////////////////////////////////////////*/

    // TODO: Test pausing (if implemented)
    // function test_Pause_Success() public {}

    // TODO: Test unpausing (if implemented)
    // function test_Unpause_Success() public {}

    // TODO: Test operations revert when paused
    // function test_Operations_RevertWhenPaused() public {}
}
