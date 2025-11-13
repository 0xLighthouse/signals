// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {SignalsHarness} from "../utils/SignalsHarness.sol";

import {ISignals} from "../../src/interfaces/ISignals.sol";
import {Signals} from "../../src/Signals.sol";
import {IncentivesPool} from "../../src/IncentivesPool.sol";

/**
 * @title SignalsRedemptionTest
 * @notice Tests for redeeming locked tokens from initiatives
 * @dev Covers redemption after acceptance, expiration, and error cases
 */
contract SignalsRedemptionTest is Test, SignalsHarness {
    Signals signals;

    function setUp() public {
        signals = deploySignals(defaultConfig);
        dealMockTokens();
    }

    /*//////////////////////////////////////////////////////////////
                    REDEMPTION AFTER ACCEPTANCE
    //////////////////////////////////////////////////////////////*/

    /// When an initiative has been accepted and releaseLockDuration is set to zero, tokens should be able to be redeemed immediately
    function test_Redeem_Accepted_ImmediateRelease() public {
        uint256 lockAmount = defaultConfig.proposerRequirements.minBalance;
        uint256 beforeBalance = _tokenERC20.balanceOf(_alice);

        (uint256 initiativeId, uint256 tokenId) = proposeAndAccept(signals, _alice, lockAmount, 0);

        // Verify balance was reduced
        assertEq(_tokenERC20.balanceOf(_alice), beforeBalance - lockAmount);

        // Redeem immediately (releaseLockDuration is 0 in defaultConfig)
        vm.startPrank(_alice);
        uint256[] memory lockIds = new uint256[](1);
        lockIds[0] = tokenId;
        signals.redeemLocksForInitiative(initiativeId, lockIds);
        vm.stopPrank();

        // Verify balance is restored
        assertEq(_tokenERC20.balanceOf(_alice), beforeBalance);

        // Verify lock is marked as withdrawn
        ISignals.TokenLock memory lock = signals.getTokenLock(tokenId);
        assertEq(lock.withdrawn, true);
    }

    /// When an initiative has been accepted and releaseLockDuration is set to a value greater than zero, tokens should not be able to be redeemed until the releaseLockDuration has passed
    function test_Redeem_Accepted_TimelockedRelease() public {
        // Create a config with 7 day release lock duration
        ISignals.BoardConfig memory config = defaultConfig;
        config.releaseLockDuration = 7 days;

        Signals customSignals = deploySignals(config);

        uint256 lockAmount = config.proposerRequirements.minBalance;
        uint256 lockDuration = 14; // Use non-zero lock duration so lock doesn't expire immediately
        uint256 beforeBalance = _tokenERC20.balanceOf(_bob);

        vm.startPrank(_bob);
        _tokenERC20.approve(address(customSignals), lockAmount);
        (uint256 initiativeId, uint256 tokenId) =
            customSignals.proposeInitiativeWithLock(_metadata(1), lockAmount, lockDuration);
        vm.stopPrank();

        // Accept the initiative
        vm.prank(_deployer);
        customSignals.acceptInitiative(initiativeId);

        // Try to redeem immediately - should fail (tokens not transferred)
        vm.startPrank(_bob);
        uint256[] memory lockIds = new uint256[](1);
        lockIds[0] = tokenId;
        vm.expectRevert(abi.encodeWithSelector(ISignals.Signals_StillTimelocked.selector, tokenId));
        customSignals.redeemLocksForInitiative(initiativeId, lockIds);
        vm.stopPrank();

        // Verify redemption did NOT succeed
        ISignals.TokenLock memory lockAfterFirstAttempt = customSignals.getTokenLock(tokenId);
        assertEq(lockAfterFirstAttempt.withdrawn, false);
        assertEq(_tokenERC20.balanceOf(_bob), beforeBalance - lockAmount);

        // Fast forward time by 7 days
        vm.warp(block.timestamp + 7 days);

        // Redeem again - should succeed now
        vm.startPrank(_bob);
        customSignals.redeemLocksForInitiative(initiativeId, lockIds);
        vm.stopPrank();

        // Verify redemption succeeded
        ISignals.TokenLock memory lockAfterSecondAttempt = customSignals.getTokenLock(tokenId);
        assertEq(lockAfterSecondAttempt.withdrawn, true);
        assertEq(_tokenERC20.balanceOf(_bob), beforeBalance);
    }

    /*//////////////////////////////////////////////////////////////
                    MULTIPLE REDEMPTIONS
    //////////////////////////////////////////////////////////////*/

    /// Test that early redemption (before acceptance) excludes user from incentives
    /// Alice, Bob, and Charlie all lock support. Alice redeems before acceptance.
    /// Bob accepts the initiative. Bob and Charlie redeem after acceptance.
    /// Verify: Alice gets only original tokens (no incentives), Bob and Charlie get tokens + incentives
    function test_Redeem_EarlyRedemptionExcludedFromIncentives() public {
        // Deploy board with incentives pool
        ISignals.BoardConfig memory config = defaultConfig;
        config.boardOpenAt = block.timestamp + 1;
        (Signals customSignals,) = deploySignalsWithIncentivesPool(config);

        // Deal tokens to test users
        dealMockTokens();

        // Ensure all users have enough tokens for the test
        uint256 supportAmount = 50_000 * 1e18;
        vm.deal(_alice, 1 ether);
        vm.deal(_bob, 1 ether);
        vm.deal(_charlie, 1 ether);
        _tokenERC20.mint(_alice, supportAmount);
        _tokenERC20.mint(_bob, supportAmount);
        _tokenERC20.mint(_charlie, supportAmount);

        // Warp to board open time
        vm.warp(config.boardOpenAt);

        uint256 lockDuration = 10;

        // Alice proposes initiative with lock
        vm.startPrank(_alice);
        _tokenERC20.approve(address(customSignals), supportAmount);
        (uint256 initiativeId, uint256 aliceLockId) =
            customSignals.proposeInitiativeWithLock(_metadata(1), supportAmount, lockDuration);
        vm.stopPrank();

        // Bob adds support
        vm.startPrank(_bob);
        _tokenERC20.approve(address(customSignals), supportAmount);
        uint256 bobLockId = customSignals.supportInitiative(initiativeId, supportAmount, lockDuration);
        vm.stopPrank();

        // Charlie adds support
        vm.startPrank(_charlie);
        _tokenERC20.approve(address(customSignals), supportAmount);
        uint256 charlieLockId =
            customSignals.supportInitiative(initiativeId, supportAmount, lockDuration);
        vm.stopPrank();

        // Warp forward past the lock duration so Alice can redeem
        vm.warp(block.timestamp + lockDuration * 1 days);

        // Record balances before Alice's redemption
        uint256 aliceTokensBefore = _tokenERC20.balanceOf(_alice);
        uint256 aliceUsdcBefore = _usdc.balanceOf(_alice);

        // Alice redeems BEFORE acceptance (but after lock expiry)
        vm.startPrank(_alice);
        uint256[] memory aliceLockIds = new uint256[](1);
        aliceLockIds[0] = aliceLockId;
        customSignals.redeemLocksForInitiative(initiativeId, aliceLockIds);
        vm.stopPrank();

        // Verify Alice got her tokens back but NO USDC incentives
        uint256 aliceTokensAfter = _tokenERC20.balanceOf(_alice);
        uint256 aliceUsdcAfter = _usdc.balanceOf(_alice);
        assertEq(aliceTokensAfter - aliceTokensBefore, supportAmount, "Alice should receive her tokens back");
        assertEq(aliceUsdcAfter - aliceUsdcBefore, 0, "Alice should receive no USDC incentives");

        // Owner accepts the initiative
        vm.prank(_deployer);
        customSignals.acceptInitiative(initiativeId);

        // Record balances before Bob's redemption
        uint256 bobTokensBefore = _tokenERC20.balanceOf(_bob);
        uint256 bobUsdcBefore = _usdc.balanceOf(_bob);

        // Bob redeems AFTER acceptance
        vm.startPrank(_bob);
        uint256[] memory bobLockIds = new uint256[](1);
        bobLockIds[0] = bobLockId;
        customSignals.redeemLocksForInitiative(initiativeId, bobLockIds);
        vm.stopPrank();

        // Record balances before Charlie's redemption
        uint256 charlieTokensBefore = _tokenERC20.balanceOf(_charlie);
        uint256 charlieUsdcBefore = _usdc.balanceOf(_charlie);

        // Charlie redeems AFTER acceptance
        vm.startPrank(_charlie);
        uint256[] memory charlieLockIds = new uint256[](1);
        charlieLockIds[0] = charlieLockId;
        customSignals.redeemLocksForInitiative(initiativeId, charlieLockIds);
        vm.stopPrank();

        // Verify Bob got his tokens back AND USDC incentives
        uint256 bobTokensAfter = _tokenERC20.balanceOf(_bob);
        uint256 bobUsdcAfter = _usdc.balanceOf(_bob);
        uint256 bobTokensReceived = bobTokensAfter - bobTokensBefore;
        uint256 bobUsdcReceived = bobUsdcAfter - bobUsdcBefore;
        assertEq(bobTokensReceived, supportAmount, "Bob should receive his tokens back");
        assertGt(bobUsdcReceived, 0, "Bob should receive USDC incentives");

        // Verify Charlie got his tokens back AND USDC incentives
        uint256 charlieTokensAfter = _tokenERC20.balanceOf(_charlie);
        uint256 charlieUsdcAfter = _usdc.balanceOf(_charlie);
        uint256 charlieTokensReceived = charlieTokensAfter - charlieTokensBefore;
        uint256 charlieUsdcReceived = charlieUsdcAfter - charlieUsdcBefore;
        assertEq(charlieTokensReceived, supportAmount, "Charlie should receive his tokens back");
        assertGt(charlieUsdcReceived, 0, "Charlie should receive USDC incentives");

        // Verify that Bob and Charlie together received approximately the max reward
        // (there may be rounding, but they should get close to the 10k USDC max)
        uint256 totalIncentivesReceived = bobUsdcReceived + charlieUsdcReceived;
        uint256 maxReward = 10_000 * 1e6; // 10k USDC (6 decimals)
        assertApproxEqAbs(
            totalIncentivesReceived, maxReward, maxReward / 100, "Bob and Charlie should split the max reward"
        );

        // Verify all locks are withdrawn
        assertEq(customSignals.getTokenLock(aliceLockId).withdrawn, true, "Alice's lock should be withdrawn");
        assertEq(customSignals.getTokenLock(bobLockId).withdrawn, true, "Bob's lock should be withdrawn");
        assertEq(
            customSignals.getTokenLock(charlieLockId).withdrawn, true, "Charlie's lock should be withdrawn"
        );
    }

    /// Test redeeming multiple escrow locks
    function test_Redeem_MultipleLocks() public {
        uint256 lockAmount = defaultConfig.proposerRequirements.minBalance;
        uint256 beforeBalance = _tokenERC20.balanceOf(_alice);

        vm.startPrank(_alice);

        // First lock - propose with lock
        _tokenERC20.approve(address(signals), lockAmount);
        (uint256 initiativeId, uint256 tokenId1) =
            signals.proposeInitiativeWithLock(_metadata(1), lockAmount, 0);

        // Second lock - support the initiative
        _tokenERC20.approve(address(signals), lockAmount);
        uint256 tokenId2 = signals.supportInitiative(initiativeId, lockAmount, 0);

        // Third lock - support the initiative again
        _tokenERC20.approve(address(signals), lockAmount);
        uint256 tokenId3 = signals.supportInitiative(initiativeId, lockAmount, 0);

        vm.stopPrank();

        // Verify alice has 3 NFTs and balance is reduced by 3x lockAmount
        assertEq(signals.balanceOf(_alice), 3);
        assertEq(_tokenERC20.balanceOf(_alice), beforeBalance - (lockAmount * 3));

        // Accept the initiative
        vm.prank(_deployer);
        signals.acceptInitiative(initiativeId);

        // Redeem first lock
        vm.startPrank(_alice);
        uint256[] memory lockIds1 = new uint256[](1);
        lockIds1[0] = tokenId1;
        signals.redeemLocksForInitiative(initiativeId, lockIds1);

        // Verify first lock redeemed
        assertEq(signals.getTokenLock(tokenId1).withdrawn, true);
        assertEq(_tokenERC20.balanceOf(_alice), beforeBalance - (lockAmount * 2));

        // Redeem second lock
        uint256[] memory lockIds2 = new uint256[](1);
        lockIds2[0] = tokenId2;
        signals.redeemLocksForInitiative(initiativeId, lockIds2);

        // Verify second lock redeemed
        assertEq(signals.getTokenLock(tokenId2).withdrawn, true);
        assertEq(_tokenERC20.balanceOf(_alice), beforeBalance - lockAmount);

        // Redeem third lock
        uint256[] memory lockIds3 = new uint256[](1);
        lockIds3[0] = tokenId3;
        signals.redeemLocksForInitiative(initiativeId, lockIds3);

        // Verify third lock redeemed and balance fully restored
        assertEq(signals.getTokenLock(tokenId3).withdrawn, true);
        assertEq(_tokenERC20.balanceOf(_alice), beforeBalance);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                    REDEMPTION AFTER EXPIRATION
    //////////////////////////////////////////////////////////////*/

    /// Tokens can be redeemed immediately after an initiative is expired due to inactivity timeout
    function test_Redeem_AfterExpiration() public {
        uint256 lockAmount = defaultConfig.proposerRequirements.minBalance;
        uint256 beforeBalance = _tokenERC20.balanceOf(_alice);

        (uint256 initiativeId, uint256 tokenId) = proposeAndExpire(signals, _alice, lockAmount, 0);

        // Verify balance was reduced
        assertEq(_tokenERC20.balanceOf(_alice), beforeBalance - lockAmount);

        // Verify initiative is expired
        ISignals.Initiative memory initiative = signals.getInitiative(initiativeId);
        assertEq(uint256(initiative.state), uint256(ISignals.InitiativeState.Expired));

        // Redeem immediately after expiration
        vm.startPrank(_alice);
        uint256[] memory lockIds = new uint256[](1);
        lockIds[0] = tokenId;
        signals.redeemLocksForInitiative(initiativeId, lockIds);
        vm.stopPrank();

        // Verify balance is restored
        assertEq(_tokenERC20.balanceOf(_alice), beforeBalance);

        // Verify lock is marked as withdrawn
        ISignals.TokenLock memory lock = signals.getTokenLock(tokenId);
        assertEq(lock.withdrawn, true);
    }

    /*//////////////////////////////////////////////////////////////
                        ERROR CASES
    //////////////////////////////////////////////////////////////*/

    // The same lockup can not be redeemed more than once
    function test_Redeem_TwiceReverts() public {
        uint256 lockAmount = defaultConfig.proposerRequirements.minBalance;

        (uint256 initiativeId, uint256 tokenId) = proposeAndAccept(signals, _alice, lockAmount, 0);

        // Redeem the lock successfully
        vm.startPrank(_alice);
        uint256[] memory lockIds = new uint256[](1);
        lockIds[0] = tokenId;
        signals.redeemLocksForInitiative(initiativeId, lockIds);

        // Verify lock is withdrawn
        assertEq(signals.getTokenLock(tokenId).withdrawn, true);

        // Attempt to redeem the same lock again - should revert (NFT no longer exists)
        vm.expectRevert();
        signals.redeemLocksForInitiative(initiativeId, lockIds);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                    NFT TRANSFER & OWNERSHIP TESTS
    //////////////////////////////////////////////////////////////*/

    // Transferring the NFT to another person should allow them to redeem the lockup
    function test_Redeem_AfterNFTTransfer() public {
        uint256 lockAmount = defaultConfig.proposerRequirements.minBalance;
        uint256 aliceBalanceBefore = _tokenERC20.balanceOf(_alice);
        uint256 bobBalanceBefore = _tokenERC20.balanceOf(_bob);

        (uint256 initiativeId, uint256 tokenId) = proposeAndAccept(signals, _alice, lockAmount, 0);

        // Verify alice owns the NFT
        assertEq(signals.ownerOf(tokenId), _alice);
        assertEq(_tokenERC20.balanceOf(_alice), aliceBalanceBefore - lockAmount);

        // Transfer NFT from alice to bob
        vm.prank(_alice);
        signals.transferFrom(_alice, _bob, tokenId);

        // Verify bob now owns the NFT
        assertEq(signals.ownerOf(tokenId), _bob);

        // Original owner (alice) cannot redeem
        vm.startPrank(_alice);
        uint256[] memory lockIds = new uint256[](1);
        lockIds[0] = tokenId;
        vm.expectRevert(ISignals.Signals_NotOwner.selector);
        signals.redeemLocksForInitiative(initiativeId, lockIds);
        vm.stopPrank();

        // New owner (bob) can redeem successfully
        vm.startPrank(_bob);
        signals.redeemLocksForInitiative(initiativeId, lockIds);
        vm.stopPrank();

        // Verify payout went to bob (new owner), not alice
        assertEq(_tokenERC20.balanceOf(_bob), bobBalanceBefore + lockAmount);
        assertEq(_tokenERC20.balanceOf(_alice), aliceBalanceBefore - lockAmount);

        // Verify lock is marked as withdrawn
        ISignals.TokenLock memory lock = signals.getTokenLock(tokenId);
        assertEq(lock.withdrawn, true);
    }

    /*//////////////////////////////////////////////////////////////
                        BOARD CLOSURE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Redeem_AfterBoardClosure() public {
        uint256 lockAmount = defaultConfig.proposerRequirements.minBalance;
        uint256 lockDuration = 14;
        uint256 beforeBalance = _tokenERC20.balanceOf(_alice);

        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), lockAmount);
        (uint256 initiativeId, uint256 tokenId) =
            signals.proposeInitiativeWithLock(_metadata(1), lockAmount, lockDuration);
        vm.stopPrank();

        // Close the board
        vm.prank(_deployer);
        signals.closeBoard();

        // Try to redeem immediately - should fail (tokens not transferred)
        vm.startPrank(_alice);
        uint256[] memory lockIds = new uint256[](1);
        lockIds[0] = tokenId;
        vm.expectRevert(abi.encodeWithSelector(ISignals.Signals_StillTimelocked.selector, tokenId));
        signals.redeemLocksForInitiative(initiativeId, lockIds);
        vm.stopPrank();

        // Verify redemption did NOT succeed
        ISignals.TokenLock memory lockAfterFirstAttempt = signals.getTokenLock(tokenId);
        assertEq(lockAfterFirstAttempt.withdrawn, false);
        assertEq(_tokenERC20.balanceOf(_alice), beforeBalance - lockAmount);

        // Fast forward time by 14 days (lock duration)
        vm.warp(block.timestamp + lockDuration * 1 days);

        // Redeem again - should succeed now
        vm.startPrank(_alice);
        signals.redeemLocksForInitiative(initiativeId, lockIds);
        vm.stopPrank();

        // Verify redemption succeeded
        ISignals.TokenLock memory lockAfterSecondAttempt = signals.getTokenLock(tokenId);
        assertEq(lockAfterSecondAttempt.withdrawn, true);
        assertEq(_tokenERC20.balanceOf(_alice), beforeBalance);
    }

    function test_Redeem_AfterBoardCancellation() public {
        uint256 lockAmount = defaultConfig.proposerRequirements.minBalance;
        uint256 lockDuration = 14;
        uint256 beforeBalance = _tokenERC20.balanceOf(_alice);

        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), lockAmount);
        (uint256 initiativeId, uint256 tokenId) =
            signals.proposeInitiativeWithLock(_metadata(1), lockAmount, lockDuration);
        vm.stopPrank();

        // Cancel the board
        vm.prank(_deployer);
        signals.cancelBoard();

        // Redeem immediately - should succeed (cancellation bypasses lock duration)
        vm.startPrank(_alice);
        uint256[] memory lockIds = new uint256[](1);
        lockIds[0] = tokenId;
        signals.redeemLocksForInitiative(initiativeId, lockIds);
        vm.stopPrank();

        // Verify redemption succeeded immediately
        ISignals.TokenLock memory lock = signals.getTokenLock(tokenId);
        assertEq(lock.withdrawn, true);
        assertEq(_tokenERC20.balanceOf(_alice), beforeBalance);
    }
}
