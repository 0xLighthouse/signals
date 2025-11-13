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
        vm.expectRevert(ISignals.Signals_InsufficientTokens.selector);
        signals.proposeInitiative(_metadata(1));
        vm.stopPrank();
    }

    /**
     * @notice Test proposing an initiative without locking tokens
     */
    function test_Propose_WithoutLock() public {
        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), defaultConfig.proposerRequirements.minBalance);

        vm.expectEmit(true, true, true, true);
        emit ISignals.InitiativeProposed(1, _alice, _metadata(1));

        signals.proposeInitiative(_metadata(1));

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
        signals.proposeInitiativeWithLock(_metadata(2), lockAmount, 6);
        vm.stopPrank();

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
        signals.proposeInitiativeWithLock(_metadata(1), lockAmount, 1);

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
    }

    /*//////////////////////////////////////////////////////////////
                        ACCEPTANCE TESTS
    //////////////////////////////////////////////////////////////*/

    /// Test accepting an initiative
    function test_Accept_Success() public {
        uint256 lockAmount = defaultConfig.acceptanceCriteria.fixedThreshold / 5;
        // Propose an initiative
        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), lockAmount);
        signals.proposeInitiativeWithLock(_metadata(1), lockAmount, 6);

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
        vm.expectRevert(ISignals.Signals_IncorrectInitiativeState.selector);
        signals.supportInitiative(1, lockAmount, 6);
    }

    /// Test that non-owner can accept after support is added when anyoneCanAccept is enabled
    function test_Accept_AnyoneCanAccept_AddSupportThenAccept() public {
        // Create config with anyoneCanAccept enabled
        ISignals.BoardConfig memory config = defaultConfig;
        config.acceptanceCriteria.anyoneCanAccept = true;
        config.acceptanceCriteria.fixedThreshold = 100_000 ether;

        ISignals customSignals = deploySignals(config);

        // Propose with insufficient support (lock duration of 1 means weight = amount * 1)
        uint256 initialLockAmount = 50_000 ether;
        vm.startPrank(_alice);
        _tokenERC20.approve(address(customSignals), initialLockAmount);
        customSignals.proposeInitiativeWithLock(_metadata(1), initialLockAmount, 1);
        vm.stopPrank();

        // Verify threshold is NOT met (weight = 50k * 1 = 50k)
        assertLt(customSignals.getWeight(1), 100_000 ether);

        // Non-owner cannot accept due to insufficient support
        vm.startPrank(_bob);
        vm.expectRevert(ISignals.Signals_InsufficientSupport.selector);
        customSignals.acceptInitiative(1);
        vm.stopPrank();

        // Add more support to meet threshold
        uint256 additionalSupport = 50_000 ether;
        vm.startPrank(_bob);
        _tokenERC20.approve(address(customSignals), additionalSupport);
        customSignals.supportInitiative(1, additionalSupport, 1);
        vm.stopPrank();

        // Verify threshold is now met
        assertGe(customSignals.getWeight(1), 100_000 ether);

        // Non-owner can now accept
        vm.startPrank(_bob);
        customSignals.acceptInitiative(1);
        vm.stopPrank();

        // Verify initiative is accepted
        ISignals.Initiative memory initiative = customSignals.getInitiative(1);
        assertEq(uint256(initiative.state), uint256(ISignals.InitiativeState.Accepted));
    }

    /// Test that owner can bypass threshold even when non-owner cannot
    function test_Accept_AnyoneCanAccept_OwnerBypassThreshold() public {
        // Create config with anyoneCanAccept enabled, ownerMustFollowThreshold disabled (default)
        ISignals.BoardConfig memory config = defaultConfig;
        config.acceptanceCriteria.anyoneCanAccept = true;
        config.acceptanceCriteria.ownerMustFollowThreshold = false;
        config.acceptanceCriteria.fixedThreshold = 100_000 ether;

        ISignals customSignals = deploySignals(config);

        // Propose with insufficient support (lock duration of 1 means weight = amount * 1)
        uint256 lockAmount = 50_000 ether;
        vm.startPrank(_alice);
        _tokenERC20.approve(address(customSignals), lockAmount);
        customSignals.proposeInitiativeWithLock(_metadata(1), lockAmount, 1);
        vm.stopPrank();

        // Verify threshold is NOT met (weight = 50k * 1 = 50k)
        assertLt(customSignals.getWeight(1), 100_000 ether);

        // Non-owner cannot accept due to insufficient support
        vm.startPrank(_bob);
        vm.expectRevert(ISignals.Signals_InsufficientSupport.selector);
        customSignals.acceptInitiative(1);
        vm.stopPrank();

        // Owner CAN accept despite insufficient support (bypasses threshold)
        vm.startPrank(_deployer);
        customSignals.acceptInitiative(1);
        vm.stopPrank();

        // Verify initiative is accepted
        ISignals.Initiative memory initiative = customSignals.getInitiative(1);
        assertEq(uint256(initiative.state), uint256(ISignals.InitiativeState.Accepted));
    }

    /// Test that owner must follow threshold when enabled, then can accept after support added
    function test_Accept_OwnerMustFollowThreshold_AddSupportThenOwnerAccepts() public {
        // Create config with anyoneCanAccept disabled (default), ownerMustFollowThreshold enabled
        ISignals.BoardConfig memory config = defaultConfig;
        config.acceptanceCriteria.anyoneCanAccept = false;
        config.acceptanceCriteria.ownerMustFollowThreshold = true;
        config.acceptanceCriteria.fixedThreshold = 100_000 ether;

        ISignals customSignals = deploySignals(config);

        // Propose with insufficient support (lock duration of 1 means weight = amount * 1)
        uint256 initialLockAmount = 50_000 ether;
        vm.startPrank(_alice);
        _tokenERC20.approve(address(customSignals), initialLockAmount);
        customSignals.proposeInitiativeWithLock(_metadata(1), initialLockAmount, 1);
        vm.stopPrank();

        // Verify threshold is NOT met (weight = 50k * 1 = 50k)
        assertLt(customSignals.getWeight(1), 100_000 ether);

        // Owner cannot accept due to insufficient support (must follow threshold)
        vm.startPrank(_deployer);
        vm.expectRevert(ISignals.Signals_InsufficientSupport.selector);
        customSignals.acceptInitiative(1);
        vm.stopPrank();

        // Add support to meet threshold
        uint256 additionalSupport = 50_000 ether;
        vm.startPrank(_bob);
        _tokenERC20.approve(address(customSignals), additionalSupport);
        customSignals.supportInitiative(1, additionalSupport, 1);
        vm.stopPrank();

        // Verify threshold is now met
        assertGe(customSignals.getWeight(1), 100_000 ether);

        // Non-owner still cannot accept (access control)
        vm.startPrank(_bob);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _bob));
        customSignals.acceptInitiative(1);
        vm.stopPrank();

        // Owner can now accept
        vm.startPrank(_deployer);
        customSignals.acceptInitiative(1);
        vm.stopPrank();

        // Verify initiative is accepted
        ISignals.Initiative memory initiative = customSignals.getInitiative(1);
        assertEq(uint256(initiative.state), uint256(ISignals.InitiativeState.Accepted));
    }

    /*//////////////////////////////////////////////////////////////
                        LOCK DURATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// Test lock with zero duration has equal support and can be redeemed immediately
    function test_LockWithZeroDuration_EqualSupport_ImmediateRedeem() public {
        uint256 lockAmount = defaultConfig.proposerRequirements.minBalance;
        uint256 beforeBalance = _tokenERC20.balanceOf(_alice);

        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), lockAmount);

        // Propose with lock duration = 0
        signals.proposeInitiativeWithLock(_metadata(1), lockAmount, 0);
        vm.stopPrank();

        // Check that weight equals lock amount (no multiplier for duration 0)
        assertEq(signals.getWeight(1), lockAmount);

        // Check lock info
        ISignals.TokenLock memory lock = signals.getTokenLock(1);
        assertEq(lock.tokenAmount, lockAmount);
        assertEq(lock.lockDuration, 0);
        assertEq(lock.withdrawn, false);

        // Redeem immediately - should succeed for duration 0
        vm.startPrank(_alice);
        uint256[] memory lockIds = new uint256[](1);
        lockIds[0] = 1;
        signals.redeemLocksForInitiative(1, lockIds);
        vm.stopPrank();

        // Verify redemption succeeded
        ISignals.TokenLock memory lockAfter = signals.getTokenLock(1);
        assertEq(lockAfter.withdrawn, true);
        assertEq(_tokenERC20.balanceOf(_alice), beforeBalance);
    }

    /// Test lock with duration has increased support and can only be redeemed after expiration
    function test_LockWithDuration_IncreasedSupport_RedeemAfterExpiration() public {
        uint256 lockAmount = defaultConfig.proposerRequirements.minBalance;
        uint256 lockDuration = 6;
        uint256 beforeBalance = _tokenERC20.balanceOf(_bob);

        vm.startPrank(_bob);
        _tokenERC20.approve(address(signals), lockAmount);

        // Propose with lock duration > 0
        signals.proposeInitiativeWithLock(_metadata(2), lockAmount, lockDuration);
        vm.stopPrank();

        // Check that weight is greater than lock amount (multiplier applied for duration > 0)
        assertGt(signals.getWeight(1), lockAmount);

        // Check lock info
        ISignals.TokenLock memory lock = signals.getTokenLock(1);
        assertEq(lock.tokenAmount, lockAmount);
        assertEq(lock.lockDuration, lockDuration);
        assertEq(lock.withdrawn, false);

        // Attempt to redeem immediately - should fail (no tokens transferred, withdrawn still false)
        vm.startPrank(_bob);
        uint256[] memory lockIds = new uint256[](1);
        lockIds[0] = 1;
        vm.expectRevert(abi.encodeWithSelector(ISignals.Signals_StillTimelocked.selector, 1));
        signals.redeemLocksForInitiative(1, lockIds);
        vm.stopPrank();

        // Verify redemption did NOT succeed
        ISignals.TokenLock memory lockAfterFirstAttempt = signals.getTokenLock(1);
        assertEq(lockAfterFirstAttempt.withdrawn, false);
        assertEq(_tokenERC20.balanceOf(_bob), beforeBalance - lockAmount);

        // Fast forward time past lock expiration (lockDuration * lockInterval)
        // lockInterval is 1 day, so warp by lockDuration days
        vm.warp(block.timestamp + lockDuration * 1 days);

        // Attempt to redeem again - should succeed now
        vm.startPrank(_bob);
        signals.redeemLocksForInitiative(1, lockIds);
        vm.stopPrank();

        // Verify redemption succeeded
        ISignals.TokenLock memory lockAfterSecondAttempt = signals.getTokenLock(1);
        assertEq(lockAfterSecondAttempt.withdrawn, true);
        assertEq(_tokenERC20.balanceOf(_bob), beforeBalance);
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
        signals.proposeInitiative(_metadata(1));

        // The initiative can not be expired before the inactivity threshold
        vm.startPrank(_deployer);
        vm.expectRevert(ISignals.Signals_IncorrectInitiativeState.selector);
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
        vm.expectRevert(ISignals.Signals_IncorrectInitiativeState.selector);
        signals.supportInitiative(1, lockAmount, 6);
        vm.stopPrank();
    }
}
