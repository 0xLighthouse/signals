// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {SignalsHarness} from "../utils/SignalsHarness.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "solady/test/utils/mocks/MockERC20.sol";

import {ISignals} from "../../src/interfaces/ISignals.sol";

/**
 * @title SignalsLifecycleTest
 * @notice Tests for initiative lifecycle: propose, accept, expire
 * @dev Covers state transitions and access control for initiatives
 */
contract SignalsLifecycleTest is Test, SignalsHarness {
    ISignals signals;

    function setUp() public {
        bool dealTokens = true;
        (, signals) = deploySignalsWithFactory(dealTokens);
    }

    /*//////////////////////////////////////////////////////////////
                        PROPOSAL TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Test revert when proposing an initiative with insufficient tokens
     */
    function test_Propose_RevertsWithInsufficientTokens() public {
        vm.startPrank(_charlie);
        vm.expectRevert(ISignals.Signals_InsufficientTokens.selector);
        signals.proposeInitiative("Should revert", "Description 1");
        vm.stopPrank();
    }

    /**
     * @notice Test proposing an initiative without locking tokens
     */
    function test_Propose_WithoutLock() public {
        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), defaultConfig.proposerRequirements.threshold);

        vm.expectEmit();
        emit ISignals.InitiativeProposed(1, _alice, "Initiative 1", "Description 1");

        signals.proposeInitiative("Initiative 1", "Description 1");

        // Check that the initiative is stored correctly
        ISignals.Initiative memory initiative = signals.getInitiative(1);
        assertEq(initiative.title, "Initiative 1");
        assertEq(initiative.body, "Description 1");
        assertEq(uint256(initiative.state), uint256(ISignals.InitiativeState.Proposed));
        assertEq(initiative.proposer, _alice);

        vm.stopPrank();
    }

    function test_ProposeWithLock_EmitsTokenId() public {
        vm.startPrank(_bob);
        // Approve the total amount needed (proposal threshold + locked amount)
        _tokenERC20.approve(address(signals), defaultConfig.proposerRequirements.threshold * 2);

        uint256 lockedAmount = 50_000 * 1e18;

        // We should receive a tokenId of 1
        vm.expectEmit();
        emit ISignals.InitiativeSupported(1, _bob, lockedAmount, 6, 1);
        signals.proposeInitiativeWithLock("Initiative 2", "Description 2", lockedAmount, 6);
    }

    /**
     * @notice Test proposing an initiative with locked tokens
     */
    function test_Propose_WithLock() public {
        vm.startPrank(_bob);
        // Approve the total amount needed (proposal threshold + locked amount)
        _tokenERC20.approve(address(signals), defaultConfig.proposerRequirements.threshold * 2);

        uint256 balanceBefore = _tokenERC20.balanceOf(_bob);
        uint256 lockedAmount = 50_000 * 1e18;

        // Propose an initiative with lock
        vm.expectEmit();
        emit ISignals.InitiativeProposed(1, _bob, "Initiative 2", "Description 2");
        signals.proposeInitiativeWithLock("Initiative 2", "Description 2", lockedAmount, 6);

        assertEq(_tokenERC20.balanceOf(_bob), balanceBefore - lockedAmount);

        // Check that the initiative is stored correctly
        ISignals.Initiative memory initiative = signals.getInitiative(1);
        assertEq(initiative.title, "Initiative 2");
        assertEq(initiative.body, "Description 2");
        assertEq(uint256(initiative.state), uint256(ISignals.InitiativeState.Proposed));
        assertEq(initiative.proposer, _bob);

        // Check that the lock info is stored
        ISignals.TokenLock memory lock = signals.getTokenLock(1);
        assertEq(lock.tokenAmount, lockedAmount);
        assertEq(lock.lockDuration, 6);
        assertEq(lock.withdrawn, false);

        // Check that the NFT is minted
        assertEq(signals.balanceOf(_bob), 1);
        assertEq(signals.ownerOf(1), _bob);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        ACCEPTANCE TESTS
    //////////////////////////////////////////////////////////////*/

    /// Test accepting an initiative
    function test_Accept_Success() public {
        // Propose an initiative
        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), 100 * 1e18);
        signals.proposeInitiative("Initiative 1", "Description 1");

        // Accept the initiative
        vm.startPrank(_deployer);
        signals.acceptInitiative(1);

        // Check that the initiative state is updated
        ISignals.Initiative memory initiative = signals.getInitiative(1);
        assertEq(uint256(initiative.state), uint256(ISignals.InitiativeState.Accepted));
    }

    /// Test that only the owner can accept an initiative
    function test_Accept_OnlyOwner() public {
        // Propose an initiative
        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), 100 * 1e18);
        signals.proposeInitiative("Initiative 1", "Description 1");

        // Attempt to accept the initiative as a non-owner
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _alice));
        signals.acceptInitiative(1);
    }

    /*//////////////////////////////////////////////////////////////
                        EXPIRATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// Test expiring an initiative after inactivity
    function test_Expire_AfterInactivity() public {
        // Propose an initiative
        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), 100 * 1e18);
        signals.proposeInitiative("Initiative 1", "Description 1");

        // Fast forward time beyond inactivity threshold
        vm.warp(block.timestamp + 61 days);

        // Expire the initiative
        vm.startPrank(_deployer); // Only owner can expire initiatives
        signals.expireInitiative(1);
        ISignals.Initiative memory initiative = signals.getInitiative(1);
        assertEq(uint256(initiative.state), uint256(ISignals.InitiativeState.Expired));
    }

    // Test attempting to expire an initiative before inactivity threshold (should fail)
    function test_Expire_RevertsBeforeThreshold() public {
        // Propose an initiative
        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), 100 * 1e18);
        signals.proposeInitiative("Initiative 1", "Description 1");
        vm.stopPrank();

        // Attempt to expire the initiative before inactivity threshold
        vm.expectRevert(abi.encodeWithSignature("Signals_NotEligibleForExpiration()"));
        signals.expireInitiative(1);
    }

    /*//////////////////////////////////////////////////////////////
                        TODO: BOUNDARY CONDITION TESTS
    //////////////////////////////////////////////////////////////*/

    // TODO: Test proposing with exact threshold amount
    // function test_Propose_ExactThreshold() public {}

    // TODO: Test proposing with maximum lock intervals
    // function test_Propose_MaxLockIntervals() public {}

    // TODO: Test proposing at proposal cap limit
    // function test_Propose_AtProposalCap() public {}

    /*//////////////////////////////////////////////////////////////
                        TODO: STATE TRANSITION EDGE CASES
    //////////////////////////////////////////////////////////////*/

    // TODO: Test cannot accept an expired initiative
    // function test_Accept_RevertsWhenExpired() public {}

    // TODO: Test cannot expire an accepted initiative
    // function test_Expire_RevertsWhenAccepted() public {}

    // TODO: Test cannot propose when paused (if pausable)
    // function test_Propose_RevertsWhenPaused() public {}

    /*//////////////////////////////////////////////////////////////
                        TODO: EVENT EMISSION TESTS
    //////////////////////////////////////////////////////////////*/

    // TODO: Test all events are emitted with correct parameters for propose
    // function test_ProposeInitiative_EmitsEvent() public {}

    // TODO: Test all events are emitted with correct parameters for accept
    // function test_AcceptInitiative_EmitsEvent() public {}

    // TODO: Test all events are emitted with correct parameters for expire
    // function test_ExpireInitiative_EmitsEvent() public {}

    /*//////////////////////////////////////////////////////////////
                        TODO: ERROR HANDLING TESTS
    //////////////////////////////////////////////////////////////*/

    // TODO: Test invalid initiative ID
    // function test_InvalidInitiativeId_Reverts() public {}

    // TODO: Test empty title/description
    // function test_Propose_RevertsWithEmptyTitleOrDescription() public {}
}
