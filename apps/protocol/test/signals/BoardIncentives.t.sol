// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {SignalsHarness} from "../utils/SignalsHarness.sol";

import {ISignals} from "../../src/interfaces/ISignals.sol";
import {IIncentivizer} from "../../src/interfaces/IIncentivizer.sol";
import {Signals} from "../../src/Signals.sol";
import {IncentivesPool} from "../../src/IncentivesPool.sol";
import {MockERC20} from "solady/test/utils/mocks/MockERC20.sol";
/**
 * @title SignalsBoardIncentivesTest
 * @notice Tests for the board incentives feature
 * @dev Covers incentive pool setup, reward calculation, and claiming
 */

contract SignalsBoardIncentivesTest is Test, SignalsHarness {
    Signals signals;
    IncentivesPool incentivesPool;
    MockERC20 token;
    MockERC20 rewardToken;

    address poolOwner = address(0x9999);

    /*//////////////////////////////////////////////////////////////
                        SETUP HELPERS
    //////////////////////////////////////////////////////////////*/

    /// Helper to deploy Signals with board incentives enabled
    /// @param openTimeDelay Seconds from now when board opens (0 = opens immediately after pool setup)
    /// @param setupPool Whether to initialize and approve the pool
    function deploySignalsWithIncentives(uint256 openTimeDelay, bool setupPool)
        internal
        returns (Signals, IncentivesPool, uint256)
    {
        return deploySignalsWithIncentivesCustomReward(openTimeDelay, setupPool, 10_000 * 1e18);
    }

    /// Helper to deploy Signals with board incentives enabled and custom max reward
    /// @param openTimeDelay Seconds from now when board opens (0 = opens immediately after pool setup)
    /// @param setupPool Whether to initialize and approve the pool
    /// @param maxRewardPerInitiative_ Maximum reward per initiative
    function deploySignalsWithIncentivesCustomReward(
        uint256 openTimeDelay,
        bool setupPool,
        uint256 maxRewardPerInitiative_
    ) internal returns (Signals, IncentivesPool, uint256) {
        // Create tokens
        token = new MockERC20("TestToken", "TEST", 18);
        rewardToken = new MockERC20("RewardToken", "REWARD", 18);

        // Mint tokens to test addresses
        token.mint(_alice, 1_000_000 * 1e18);
        token.mint(_bob, 1_000_000 * 1e18);
        token.mint(_charlie, 1_000_000 * 1e18);

        // Mint reward tokens to pool owner
        rewardToken.mint(poolOwner, 10_000_000 * 1e18);

        // Create board incentives config with linear curve parameters [3, 1, 2]
        uint256[] memory incentiveParams = new uint256[](3);
        incentiveParams[0] = 3;
        incentiveParams[1] = 1;
        incentiveParams[2] = 2;

        IIncentivizer.IncentivesConfig memory incentivesConfig = IIncentivizer.IncentivesConfig({
            incentiveType: IIncentivizer.IncentiveType.Linear,
            incentiveParameters: incentiveParams
        });

        // Create decay curve params
        uint256[] memory decayParams = new uint256[](1);
        decayParams[0] = 9e17; // 0.9 for decay curve

        // Set board open time: if we need to setup pool, add 1 second buffer to allow setIncentivesPool
        uint256 actualOpenTime = block.timestamp + (setupPool ? 1 : 0) + openTimeDelay;

        // Deploy and initialize Signals
        Signals newSignals = new Signals();
        newSignals.initialize(defaultConfig);

        // Deploy IncentivesPool with rewardToken (immutable constructor param)
        vm.prank(poolOwner);
        IncentivesPool pool = new IncentivesPool(address(rewardToken));

        // Optionally setup pool and link it to board (must be done before board opens)
        if (setupPool) {
            vm.startPrank(poolOwner);
            rewardToken.approve(address(pool), 1_000_000 * 1e18);
            pool.addFundsToPool(1_000_000 * 1e18);
            pool.approveBoard(address(newSignals), 1_000_000 * 1e18, maxRewardPerInitiative_);
            vm.stopPrank();

            // Set pool on board with incentives config (must be before board opens)
            vm.prank(_deployer);
            newSignals.setIncentivesPool(address(pool), incentivesConfig);

            // If openTimeDelay is 0, warp to board open time
            if (openTimeDelay == 0) {
                vm.warp(actualOpenTime);
            }
        }

        return (newSignals, pool, actualOpenTime);
    }

    /*//////////////////////////////////////////////////////////////
                        INCENTIVES POOL SETUP TESTS
    //////////////////////////////////////////////////////////////*/

    /// Test pool initialization before board opens
    function test_IncentivesPool_InitializeBeforeOpen_Succeeds() public {
        uint256 futureOpenDelay = 1 hours;
        (signals, incentivesPool,) = deploySignalsWithIncentives(futureOpenDelay, false);

        vm.startPrank(poolOwner);
        rewardToken.approve(address(incentivesPool), 1_000_000 * 1e18);
        incentivesPool.addFundsToPool(1_000_000 * 1e18);
        incentivesPool.approveBoard(address(signals), 1_000_000 * 1e18, 10_000 * 1e18);
        vm.stopPrank();

        assertEq(incentivesPool.REWARD_TOKEN(), address(rewardToken));
        assertEq(incentivesPool.availableRewards(), 1_000_000 * 1e18);
        assertEq(incentivesPool.totalRewardPerInitiative(address(signals)), 10_000 * 1e18);
        assertTrue(incentivesPool.approvedBoards(address(signals)));
    }

    /// Test pool initialization can still happen after any board opens (1:M design)
    function test_IncentivesPool_InitializeAfterBoardOpens_Succeeds() public {
        (signals, incentivesPool,) = deploySignalsWithIncentives(0, false);

        // Pool can be funded anytime now (no longer tied to board open time)
        vm.startPrank(poolOwner);
        rewardToken.approve(address(incentivesPool), 1_000_000 * 1e18);
        incentivesPool.addFundsToPool(1_000_000 * 1e18);
        incentivesPool.approveBoard(address(signals), 1_000_000 * 1e18, 10_000 * 1e18);
        vm.stopPrank();

        assertTrue(incentivesPool.approvedBoards(address(signals)));
    }

    /// TODO: Test setting incentives pool before board opens
    function test_SetIncentivesPool_BeforeOpen_Succeeds() public {}

    /// TODO: Test setting incentives pool after board opens, which should revert as it is not allowed
    function test_SetIncentivesPool_AfterOpen_Reverts() public {}

    /*//////////////////////////////////////////////////////////////
                        REWARD CALCULATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// TODO: Test: Deploy a board and attach it to a funded incentives pool. Alice creates an initiative but does not add any support to it. Bob adds enough support to it to accept it. Action the initiative, and have Bob claim his rewards. Confirm Bob gets rewards equal to the total reward per initiative.
    function test_IncentivesPool_SingleSupporter() public {}

    /// Test reward calculation with multiple supporters at different times
    function test_IncentivesPool_MultipleSupporter_LinearDecay() public {}

    /// Test immediate acceptance (duration = 0) gives equal weight
    function test_IncentivesPool_ImmediateAcceptance_EqualWeight() public {
        // (signals, incentivesPool,) = deploySignalsWithIncentivesCustomReward(0, true, 1_000 * 1e18);

        // // Alice proposes
        // vm.startPrank(_alice);
        // token.approve(address(signals), 100 * 1e18);
        // signals.proposeInitiativeWithLock("Initiative 1", "Description 1", 100 * 1e18, 10);
        // vm.stopPrank();

        // // Bob supports
        // vm.startPrank(_bob);
        // token.approve(address(signals), 100 * 1e18);
        // signals.supportInitiative(1, 100 * 1e18, 10);
        // vm.stopPrank();

        // // Accept immediately (same block)
        // vm.prank(_deployer);
        // signals.acceptInitiative(1);

        // // Both should get equal rewards (50/50 split)
        // uint256 aliceRewards = incentivesPool.getSupporterRewards(address(signals), 1, _alice);
        // uint256 bobRewards = incentivesPool.getSupporterRewards(address(signals), 1, _bob);

        // assertEq(aliceRewards, 500 * 1e18);
        // assertEq(bobRewards, 500 * 1e18);
    }

    /*//////////////////////////////////////////////////////////////
                        REWARD AUTO-CLAIM TESTS
    //////////////////////////////////////////////////////////////*/

    /// Test rewards are auto-claimed on redeem
    function test_IncentivesPool_AutoClaimOnRedeem() public {
        // (signals, incentivesPool,) = deploySignalsWithIncentivesCustomReward(0, true, 1_000 * 1e18);

        // // Alice proposes and supports
        // vm.startPrank(_alice);
        // token.approve(address(signals), 100 * 1e18);
        // uint256 tokenId = signals.proposeInitiativeWithLock("Initiative 1", "Description 1", 100 * 1e18, 10);
        // vm.stopPrank();

        // // Accept initiative
        // vm.prank(_deployer);
        // signals.acceptInitiative(1);

        // // Check expected rewards before redeem
        // uint256 expectedRewards = incentivesPool.getSupporterRewards(address(signals), 1, _alice);
        // assertGt(expectedRewards, 0);

        // // Redeem - should auto-claim rewards
        // uint256 aliceRewardsBefore = rewardToken.balanceOf(_alice);
        // uint256 aliceTokensBefore = token.balanceOf(_alice);

        // vm.prank(_alice);
        // signals.redeem(tokenId);

        // uint256 aliceRewardsAfter = rewardToken.balanceOf(_alice);
        // uint256 aliceTokensAfter = token.balanceOf(_alice);

        // // Should receive both underlying tokens AND rewards
        // assertEq(aliceTokensAfter - aliceTokensBefore, 100 * 1e18); // Underlying tokens
        // assertEq(aliceRewardsAfter - aliceRewardsBefore, expectedRewards); // Reward tokens

        // // Rewards should be marked as claimed (0)
        // assertEq(incentivesPool.getSupporterRewards(address(signals), 1, _alice), 0);
    }

    /// Test manual claim still works if user prefers
    function test_IncentivesPool_ManualClaimStillWorks() public {
        // (signals, incentivesPool,) = deploySignalsWithIncentivesCustomReward(0, true, 1_000 * 1e18);

        // // Alice proposes and supports
        // vm.startPrank(_alice);
        // token.approve(address(signals), 100 * 1e18);
        // signals.proposeInitiativeWithLock("Initiative 1", "Description 1", 100 * 1e18, 10);
        // vm.stopPrank();

        // // Accept initiative
        // vm.prank(_deployer);
        // signals.acceptInitiative(1);

        // // Manual claim (before redeem)
        // uint256 aliceRewardsBefore = rewardToken.balanceOf(_alice);
        // uint256 expectedRewards = incentivesPool.getSupporterRewards(address(signals), 1, _alice);

        // vm.prank(_alice);
        // incentivesPool.claimRewards(address(signals), 1, _alice);

        // uint256 aliceRewardsAfter = rewardToken.balanceOf(_alice);
        // assertEq(aliceRewardsAfter - aliceRewardsBefore, expectedRewards);

        // // Rewards should be marked as claimed
        // assertEq(incentivesPool.getSupporterRewards(address(signals), 1, _alice), 0);
    }

    /// Test redeeming after manual claim doesn't fail
    function test_IncentivesPool_RedeemAfterManualClaim() public {
        // (signals, incentivesPool,) = deploySignalsWithIncentivesCustomReward(0, true, 1_000 * 1e18);

        // // Alice proposes and supports
        // vm.startPrank(_alice);
        // token.approve(address(signals), 100 * 1e18);
        // uint256 tokenId = signals.proposeInitiativeWithLock("Initiative 1", "Description 1", 100 * 1e18, 10);
        // vm.stopPrank();

        // // Accept initiative
        // vm.prank(_deployer);
        // signals.acceptInitiative(1);

        // // Manual claim first
        // vm.prank(_alice);
        // incentivesPool.claimRewards(address(signals), 1, _alice);

        // // Redeem should still work (no rewards to claim, but doesn't fail)
        // uint256 aliceTokensBefore = token.balanceOf(_alice);

        // vm.prank(_alice);
        // signals.redeem(tokenId);

        // uint256 aliceTokensAfter = token.balanceOf(_alice);

        // // Alice should have received underlying tokens
        // assertEq(aliceTokensAfter - aliceTokensBefore, 100 * 1e18);
    }

    /*//////////////////////////////////////////////////////////////
                        POOL DEPLETION TESTS
    //////////////////////////////////////////////////////////////*/

    /// Test pool depletion doesn't block acceptance
    function test_IncentivesPool_Depleted_NonBlocking() public {
        // uint256 boardOpenTime;
        // (signals, incentivesPool, boardOpenTime) = deploySignalsWithIncentives(1 hours, false);

        // // Setup pool with limited funds (will be fully depleted after first initiative)
        // vm.startPrank(poolOwner);
        // rewardToken.approve(address(incentivesPool), 100 * 1e18);
        // incentivesPool.addFundsToPool(100 * 1e18);
        // incentivesPool.approveBoard(address(signals), 100 * 1e18, 100 * 1e18);
        // vm.stopPrank();

        // // Create incentives config
        // uint256[] memory incentiveParams = new uint256[](1);
        // incentiveParams[0] = 0.12e18;
        // ISignals.IncentivesConfig memory incentivesConfig =
        //     ISignals.IncentivesConfig({curveType: 0, curveParameters: incentiveParams});

        // vm.prank(_deployer);
        // signals.setIncentivesPool(address(incentivesPool), incentivesConfig);

        // // Warp to board open time
        // vm.warp(boardOpenTime);

        // // First initiative depletes pool
        // vm.startPrank(_alice);
        // token.approve(address(signals), 100 * 1e18);
        // signals.proposeInitiativeWithLock("Initiative 1", "Description 1", 100 * 1e18, 10);
        // vm.stopPrank();

        // vm.prank(_deployer);
        // signals.acceptInitiative(1);

        // // Second initiative should still be accepted (non-blocking)
        // vm.startPrank(_bob);
        // token.approve(address(signals), 100 * 1e18);
        // signals.proposeInitiativeWithLock("Initiative 2", "Description 2", 100 * 1e18, 10);
        // vm.stopPrank();

        // vm.prank(_deployer);
        // signals.acceptInitiative(2); // Should succeed

        // // Second initiative should have 0 rewards
        // assertEq(incentivesPool.getSupporterRewards(address(signals), 2, _bob), 0);
    }

    /*//////////////////////////////////////////////////////////////
                        DISABLED INCENTIVES TESTS
    //////////////////////////////////////////////////////////////*/

    /// Test acceptance works without incentives pool
    // function test_NoIncentivesPool_AcceptanceSucceeds() public {
    //     (signals,,) = deploySignalsWithIncentives(0, false);
    //     // Don't set incentives pool

    //     // Alice proposes
    //     vm.startPrank(_alice);
    //     token.approve(address(signals), 100 * 1e18);
    //     signals.proposeInitiativeWithLock("Initiative 1", "Description 1", 100 * 1e18, 10);
    //     vm.stopPrank();

    //     // Accept should succeed without pool
    //     vm.prank(_deployer);
    //     signals.acceptInitiative(1);

    //     ISignals.Initiative memory initiative = signals.getInitiative(1);
    //     assertEq(uint256(initiative.state), uint256(ISignals.InitiativeState.Accepted));
    // }
}
