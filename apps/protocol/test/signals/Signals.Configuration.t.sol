// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {SignalsHarness} from "../utils/SignalsHarness.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ISignals} from "../../src/interfaces/ISignals.sol";

/**
 * @title SignalsConfigurationTest
 * @notice Tests for configuration and admin functions
 * @dev Covers initialization, parameter updates, and access control
 */
contract SignalsConfigurationTest is Test, SignalsHarness {
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
