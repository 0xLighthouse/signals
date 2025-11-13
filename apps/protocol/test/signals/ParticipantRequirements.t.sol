// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {SignalsHarness} from "../utils/SignalsHarness.sol";
import {ISignals} from "../../src/interfaces/ISignals.sol";
import {IAuthorizer} from "../../src/interfaces/IAuthorizer.sol";

/**
 * @title SignalsProposerRequirementsTest
 * @notice Tests for proposal requirements configuration
 */
contract SignalsProposerRequirementsTest is Test, SignalsHarness {
    // /*//////////////////////////////////////////////////////////////
    //                     MIN BALANCE TESTS
    // //////////////////////////////////////////////////////////////*/

    /// @notice Test that proposerRequirements.minBalance is enforced
    function test_Propose_MinBalance() public {
        // Create config with minBalance = 100k (Charlie has 40k, Alice/Bob have 200k)
        ISignals.BoardConfig memory config = defaultConfig;
        config.proposerRequirements.minBalance = 100_000 ether;

        ISignals signals = deploySignals(config);
        dealMockTokens();

        // Charlie (40k tokens) should NOT be able to propose
        vm.startPrank(_charlie);
        _tokenERC20.approve(address(signals), 100_000 ether);
        vm.expectRevert(ISignals.Signals_InsufficientTokens.selector);
        signals.proposeInitiative(_metadata(1));
        vm.stopPrank();

        // Alice (200k tokens) should be able to propose
        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), 100_000 ether);
        signals.proposeInitiative(_metadata(2));
        vm.stopPrank();

        // Verify initiative was created
        ISignals.Initiative memory initiative = signals.getInitiative(1);
        assertEq(initiative.proposer, _alice);
        assertEq(uint256(initiative.state), uint256(ISignals.InitiativeState.Proposed));
    }

    /// @notice Test that supporterRequirements.minBalance is enforced
    function test_Support_MinBalance() public {
        // Create config with supporterRequirements.minBalance = 100k
        ISignals.BoardConfig memory config = defaultConfig;
        config.supporterRequirements.minBalance = 100_000 ether;
        config.proposerRequirements.minBalance = 0; // Allow anyone to propose

        ISignals signals = deploySignals(config);
        dealMockTokens();

        // Alice proposes an initiative first
        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), 50_000 ether);
        signals.proposeInitiativeWithLock(_metadata(1), 50_000 ether, 1);
        vm.stopPrank();

        // Charlie (40k tokens) should NOT be able to support
        vm.startPrank(_charlie);
        _tokenERC20.approve(address(signals), 10_000 ether);
        vm.expectRevert(ISignals.Signals_InsufficientTokens.selector);
        signals.supportInitiative(1, 10_000 ether, 1);
        vm.stopPrank();

        // Bob (200k tokens) should be able to support
        vm.startPrank(_bob);
        _tokenERC20.approve(address(signals), 50_000 ether);
        signals.supportInitiative(1, 50_000 ether, 1);
        vm.stopPrank();

        // Verify support was recorded
        uint256 expectedWeight = (50_000 ether * 1) + (50_000 ether * 1);
        assertEq(signals.getWeight(1), expectedWeight);
    }

    /*//////////////////////////////////////////////////////////////
                        MIN LOCK AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that proposerRequirements.minLockAmount is enforced
    function test_Propose_MinLockAmount() public {
        // Create config with minLockAmount = 30k
        ISignals.BoardConfig memory config = defaultConfig;
        config.proposerRequirements.minLockAmount = 30_000 ether;
        config.proposerRequirements.minBalance = 30_000 ether; // Can't be less than the minLockAmount

        ISignals signals = deploySignals(config);
        dealMockTokens();

        // Alice tries to propose with lock < 30k (should fail)
        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), 20_000 ether);
        vm.expectRevert(ISignals.Signals_InsufficientLockAmount.selector);
        signals.proposeInitiativeWithLock(_metadata(1), 20_000 ether, 1);
        vm.stopPrank();

        // Alice proposes with lock >= 30k (should succeed)
        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), 50_000 ether);
        signals.proposeInitiativeWithLock(_metadata(2), 50_000 ether, 1);
        vm.stopPrank();

        // Verify initiative was created with correct lock amount
        ISignals.Initiative memory initiative = signals.getInitiative(1);
        assertEq(initiative.proposer, _alice);
        assertEq(uint256(initiative.state), uint256(ISignals.InitiativeState.Proposed));
    }

    /// @notice Test that supporterRequirements.minLockAmount is enforced
    function test_Support_MinLockAmount() public {
        // Create config with supporterRequirements.minLockAmount = 30k
        ISignals.BoardConfig memory config = defaultConfig;
        config.supporterRequirements.minLockAmount = 30_000 ether;
        config.supporterRequirements.minBalance = 30_000 ether; // Can't be less than the minLockAmount
        config.proposerRequirements.minLockAmount = 0; // No lock requirement for proposer
        config.proposerRequirements.minBalance = 0; // No balance requirement for proposer

        ISignals signals = deploySignals(config);
        dealMockTokens();

        // Alice proposes an initiative first
        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), 10_000 ether);
        signals.proposeInitiativeWithLock(_metadata(1), 10_000 ether, 1);
        vm.stopPrank();

        // Bob tries to support with lock < 30k (should fail)
        vm.startPrank(_bob);
        _tokenERC20.approve(address(signals), 20_000 ether);
        vm.expectRevert(ISignals.Signals_InsufficientLockAmount.selector);
        signals.supportInitiative(1, 20_000 ether, 1);
        vm.stopPrank();

        // Bob supports with lock >= 30k (should succeed)
        vm.startPrank(_bob);
        _tokenERC20.approve(address(signals), 50_000 ether);
        signals.supportInitiative(1, 50_000 ether, 1);
        vm.stopPrank();

        // Verify support was recorded
        uint256 expectedWeight = (10_000 ether * 1) + (50_000 ether * 1);
        assertEq(signals.getWeight(1), expectedWeight);
    }

    /*//////////////////////////////////////////////////////////////
                        VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that initialization reverts when minHoldingDuration > 0 but minBalance == 0
    function test_Initialize_RevertsInvalidConfigurations() public {
        // TEST 1: proposerRequirements with invalid config
        ISignals.BoardConfig memory config1 = defaultConfig;
        config1.proposerRequirements.minHoldingDuration = 100;
        config1.proposerRequirements.minBalance = 0;

        vm.expectRevert(ISignals.Signals_InvalidArguments.selector);
        deploySignals(config1);

        // TEST 2: supporterRequirements with invalid config
        ISignals.BoardConfig memory config2 = defaultConfig;
        config2.supporterRequirements.minHoldingDuration = 100;
        config2.supporterRequirements.minBalance = 0;

        vm.expectRevert(ISignals.Signals_InvalidArguments.selector);
        deploySignals(config2);

        // TEST 3: Valid config with both duration and balance set
        ISignals.BoardConfig memory config3 = defaultConfig;
        config3.proposerRequirements.minHoldingDuration = 100;
        config3.proposerRequirements.minBalance = 50_000 ether;

        ISignals signals = deploySignals(config3);

        // Verify config was set correctly
        IAuthorizer.ParticipantRequirements memory reqs = signals.getProposerRequirements();
        assertEq(reqs.minHoldingDuration, 100);
        assertEq(reqs.minBalance, 50_000 ether);
    }
}
