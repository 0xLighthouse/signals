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
        signals = deploySignals(defaultConfig);
        dealMockTokens();
    }

    /*//////////////////////////////////////////////////////////////
                        PROPOSAL TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Test revert when proposing an initiative with insufficient tokens
     */
    function test_Propose_RevertsWithInsufficientTokens() public {
        vm.startPrank(_charlie);
        vm.expectRevert(ISignals.Signals_ParticipantInsufficientBalance.selector);
        signals.proposeInitiative("Should revert", "Description 1");
        vm.stopPrank();
    }

    /**
     * @notice Test proposing an initiative without locking tokens
     */
    function test_Propose_WithoutLock() public {
        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), defaultConfig.proposerRequirements.minBalance);

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

    function test_ProposeWithLock() public {
        uint256 lockAmount = defaultConfig.proposerRequirements.minBalance;
        uint256 beforeBalance = _tokenERC20.balanceOf(_bob);

        vm.startPrank(_bob);
        // Approve the total amount needed (proposal threshold + locked amount)
        _tokenERC20.approve(address(signals), lockAmount);

        // We should receive a tokenId of 1
        vm.expectEmit();
        emit ISignals.InitiativeSupported(1, _bob, lockAmount, 6, 1);
        signals.proposeInitiativeWithLock("Initiative 2", "Description 2", lockAmount, 6);
        vm.stopPrank();

        // Check that the initiative is stored correctly
        ISignals.Initiative memory initiative = signals.getInitiative(1);
        assertEq(initiative.title, "Initiative 2");
        assertEq(initiative.body, "Description 2");
        assertEq(uint256(initiative.state), uint256(ISignals.InitiativeState.Proposed));
        assertEq(initiative.proposer, _bob);

        // Check that the lock info is stored
        ISignals.TokenLock memory lock = signals.getTokenLock(1);
        assertEq(lock.tokenAmount, lockAmount);
        assertEq(lock.lockDuration, 6);
        assertEq(lock.withdrawn, false);

        // Check that the NFT is minted
        assertEq(signals.balanceOf(_bob), 1);
        assertEq(signals.ownerOf(1), _bob);

        assertEq(_tokenERC20.balanceOf(_bob), beforeBalance - lockAmount);
    }

    /*//////////////////////////////////////////////////////////////
                        SUPPORT TESTS
    //////////////////////////////////////////////////////////////*/

    /// Test supporting an initiative with locked tokens
    function test_SupportInitiative() public {
        uint256 lockAmount = defaultConfig.proposerRequirements.minBalance;
        vm.startPrank(_alice);
        // Approve tokens
        _tokenERC20.approve(address(signals), lockAmount);

        // Propose an initiative
        signals.proposeInitiativeWithLock("Initiative 1", "Description 1", lockAmount, 1);

        vm.startPrank(_bob);
        _tokenERC20.approve(address(signals), lockAmount);
        // Support the initiative
        signals.supportInitiative(1, lockAmount, 1);
        vm.stopPrank();

        // Check that the lock info is stored correctly
        ISignals.TokenLock memory lock = signals.getTokenLock(2);
        assertEq(lock.tokenAmount, lockAmount);
        assertEq(lock.lockDuration, 1);
        assertEq(lock.withdrawn, false);

        // Check that NFT #1 is minted to Alice
        assertEq(signals.balanceOf(_alice), 1);
        assertEq(signals.ownerOf(1), _alice);

        // Check that NFT #2 is minted to Bob
        assertEq(signals.balanceOf(_bob), 1);
        assertEq(signals.ownerOf(2), _bob);

        // Check that total support is stored correctly
        assertEq(signals.getWeight(1), lockAmount * 2);

        // Test getLockCountForSupporter
        assertEq(signals.getLockCountForSupporter(_bob), 1);
        assertEq(signals.getLockCountForSupporter(_alice), 1);

        // Test getLocksForSupporter
        uint256[] memory aliceLocks = signals.getLocksForSupporter(_alice);
        assertEq(aliceLocks.length, 1);
        assertEq(aliceLocks[0], 1);

        uint256[] memory bobLocks = signals.getLocksForSupporter(_bob);
        assertEq(bobLocks.length, 1);
        assertEq(bobLocks[0], 2);
    }

    /*//////////////////////////////////////////////////////////////
                        ACCEPTANCE TESTS
    //////////////////////////////////////////////////////////////*/

    /// Test accepting an initiative
    function test_Accept_Success() public {
        uint256 lockAmount = defaultConfig.acceptanceThreshold;
        // Propose an initiative
        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), lockAmount);
        signals.proposeInitiativeWithLock("Initiative 1", "Description 1", lockAmount, 6);

        // Non-owner cannot accept the initiative
        vm.startPrank(_bob);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _bob));
        signals.acceptInitiative(1);
        vm.stopPrank();

        // Accept the initiative
        vm.startPrank(_deployer);
        signals.acceptInitiative(1);

        // Check that the initiative state is updated
        ISignals.Initiative memory initiative = signals.getInitiative(1);
        assertEq(uint256(initiative.state), uint256(ISignals.InitiativeState.Accepted));

        // Check that no more support can be added to the accepted initiative
        vm.startPrank(_bob);
        vm.expectRevert(ISignals.Signals_NotProposedState.selector);
        signals.supportInitiative(1, lockAmount, 6);
    }

    /*//////////////////////////////////////////////////////////////
                        EXPIRATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// Test expiring an initiative after inactivity
    function test_Expire_AfterInactivity() public {
        uint256 lockAmount = defaultConfig.proposerRequirements.minBalance;
        // Propose an initiative
        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), lockAmount);
        signals.proposeInitiative("Initiative 1", "Description 1");

        // The initiative can not be expired before the inactivity threshold
        vm.startPrank(_deployer);
        vm.expectRevert(ISignals.Signals_NotEligibleForExpiration.selector);
        signals.expireInitiative(1);

        // Fast forward time beyond inactivity threshold
        vm.warp(block.timestamp + defaultConfig.inactivityTimeout);

        // Non-owner cannot expire the initiative
        vm.startPrank(_bob);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _bob));
        signals.expireInitiative(1);
        vm.stopPrank();

        // Expire the initiative
        vm.startPrank(_deployer);
        signals.expireInitiative(1);
        ISignals.Initiative memory initiative = signals.getInitiative(1);
        assertEq(uint256(initiative.state), uint256(ISignals.InitiativeState.Expired));

        // No additional support can be added to the expired initiative
        vm.startPrank(_bob);
        vm.expectRevert(ISignals.Signals_NotProposedState.selector);
        signals.supportInitiative(1, lockAmount, 6);
        vm.stopPrank();
    }
}
