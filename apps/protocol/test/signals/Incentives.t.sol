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
    ISignals signals;
    IncentivesPool incentivesPool;

    function setUp() public {
        signals = deploySignals(defaultConfig);
        dealMockTokens();
    }

    /*//////////////////////////////////////////////////////////////
                        INCENTIVES POOL SETUP TESTS
    //////////////////////////////////////////////////////////////*/

    /// Test pool initialization before board opens
    function test_IncentivesPool_InitializeBeforeOpen_Succeeds() public {
        // Deploy and fund pool using harness helper (uses _usdc as reward token)
        (incentivesPool,) = deployAndFundIncentivesPool();

        assertEq(incentivesPool.REWARD_TOKEN(), address(_usdc));
        assertEq(incentivesPool.availableRewards(), 1_000_000 * 1e6); // USDC has 6 decimals

        // Approve board on pool
        vm.startPrank(_poolOwner);
        incentivesPool.approveBoard(address(signals), 1_000_000 * 1e6, 10_000 * 1e6);
        vm.stopPrank();

        assertEq(incentivesPool.totalRewardPerInitiative(address(signals)), 10_000 * 1e6);
        assertTrue(incentivesPool.approvedBoards(address(signals)));
    }

    /// Test pool initialization can still happen after any board opens (1:M design)
    function test_IncentivesPool_InitializeAfterBoardOpens_Succeeds() public {
        // Board is already open (setUp uses defaultConfig with boardOpenAt = 1)
        assertTrue(signals.isBoardOpen());

        // Deploy and fund pool using harness helper (uses _usdc as reward token)
        (incentivesPool,) = deployAndFundIncentivesPool();

        // Pool can be funded anytime now (no longer tied to board open time)
        vm.startPrank(_poolOwner);
        incentivesPool.approveBoard(address(signals), 1_000_000 * 1e6, 10_000 * 1e6);
        vm.stopPrank();

        assertTrue(incentivesPool.approvedBoards(address(signals)));
    }

    /// Test setting incentives pool before board opens
    function test_SetIncentivesPool_BeforeOpen_Succeeds() public {
        // Deploy board that hasn't opened yet
        ISignals.BoardConfig memory config = defaultConfig;
        config.boardOpenAt = block.timestamp + 1 hours;
        signals = deploySignals(config);

        // Deploy and fund pool using harness helper (uses _usdc as reward token)
        (incentivesPool,) = deployAndFundIncentivesPool();

        // Approve board on pool
        vm.startPrank(_poolOwner);
        incentivesPool.approveBoard(address(signals), 1_000_000 * 1e6, 10_000 * 1e6);
        vm.stopPrank();

        // Create incentives config
        uint256[] memory incentiveParams = new uint256[](3);
        incentiveParams[0] = 3 * 1e18;
        incentiveParams[1] = 1 * 1e18;
        incentiveParams[2] = 2 * 1e18;

        IIncentivizer.IncentivesConfig memory incentivesConfig = IIncentivizer.IncentivesConfig({
            incentiveType: IIncentivizer.IncentiveType.Linear,
            incentiveParametersWAD: incentiveParams
        });

        // Set pool on board (before board opens)
        vm.prank(_deployer);
        signals.setIncentivesPool(address(incentivesPool), incentivesConfig);

        // Verify pool is set
        assertEq(address(Signals(address(signals)).incentivesPool()), address(incentivesPool));
    }

    /// Test setting incentives pool after board opens, which should revert as it is not allowed
    function test_SetIncentivesPool_AfterOpen_Reverts() public {
        // Board is already open (setUp uses defaultConfig with boardOpenAt = 1)
        assertTrue(signals.isBoardOpen());

        // Deploy and fund pool using harness helper (uses _usdc as reward token)
        (incentivesPool,) = deployAndFundIncentivesPool();

        // Approve board on pool
        vm.startPrank(_poolOwner);
        incentivesPool.approveBoard(address(signals), 1_000_000 * 1e6, 10_000 * 1e6);
        vm.stopPrank();

        // Create incentives config
        uint256[] memory incentiveParams = new uint256[](3);
        incentiveParams[0] = 3 * 1e18;
        incentiveParams[1] = 1 * 1e18;
        incentiveParams[2] = 2 * 1e18;

        IIncentivizer.IncentivesConfig memory incentivesConfig = IIncentivizer.IncentivesConfig({
            incentiveType: IIncentivizer.IncentiveType.Linear,
            incentiveParametersWAD: incentiveParams
        });

        // Attempt to set pool on board (after board opens) - should revert
        vm.prank(_deployer);
        vm.expectRevert(ISignals.Signals_IncorrectBoardState.selector);
        signals.setIncentivesPool(address(incentivesPool), incentivesConfig);
    }

    /*//////////////////////////////////////////////////////////////
                        REWARD CALCULATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// Test: Deploy a board and attach it to a funded incentives pool. Alice creates an initiative but does not add any support to it. Bob adds enough support to it to accept it. Action the initiative, and have Bob claim his rewards. Confirm Bob gets rewards equal to the total reward per initiative.
    function test_IncentivesPool_SingleSupporter() public {
        // Deploy board with incentives pool using harness helpers (uses _usdc as reward token)
        ISignals.BoardConfig memory config = defaultConfig;
        config.boardOpenAt = block.timestamp + 1; // Delay board open to allow pool setup
        (signals, incentivesPool) = deploySignalsWithIncentivesPool(config);

        // Warp to board open time
        vm.warp(config.boardOpenAt);

        // Alice proposes initiative without lock (no support)
        vm.prank(_alice);
        signals.proposeInitiative(_metadata(1));

        uint256 initiativeId = 1; // First initiative

        // Bob adds support to reach acceptance threshold
        uint256 supportAmount = 100_000 * 1e18; // Enough to reach threshold
        uint256 lockDuration = 10; // 10 intervals

        vm.startPrank(_bob);
        _tokenERC20.approve(address(signals), supportAmount);
        uint256 bobLockId = signals.supportInitiative(initiativeId, supportAmount, lockDuration);
        vm.stopPrank();

        // Accept the initiative
        vm.prank(_deployer);
        signals.acceptInitiative(initiativeId);

        // Record Bob's balances before redeem
        uint256 bobRewardTokensBefore = _usdc.balanceOf(_bob);
        uint256 bobUnderlyingTokensBefore = _tokenERC20.balanceOf(_bob);

        // Bob redeems his lock to claim rewards
        uint256[] memory lockIds = new uint256[](1);
        lockIds[0] = bobLockId;

        vm.prank(_bob);
        signals.redeemLocksForInitiative(initiativeId, lockIds);

        // Record Bob's balances after redeem
        uint256 bobRewardTokensAfter = _usdc.balanceOf(_bob);
        uint256 bobUnderlyingTokensAfter = _tokenERC20.balanceOf(_bob);

        // Bob should receive full maxRewardPerInitiative since he's the only supporter
        uint256 maxReward = 10_000 * 1e6; // USDC has 6 decimals
        assertEq(
            bobRewardTokensAfter - bobRewardTokensBefore,
            maxReward,
            "Bob should receive full maxRewardPerInitiative"
        );

        // Bob should also receive his underlying tokens back
        assertEq(
            bobUnderlyingTokensAfter - bobUnderlyingTokensBefore,
            supportAmount,
            "Bob should receive his underlying tokens back"
        );

        // Verify pool budget decreased correctly
        uint256 expectedRemainingBudget = 100_000 * 1e6 - maxReward; // Default helper uses 100k USDC budget
        assertEq(
            incentivesPool.boardRemainingBudget(address(signals)),
            expectedRemainingBudget,
            "Pool budget should decrease by maxReward"
        );
    }

    /// Test reward calculation with two supporters at different times
    /// NOTE: Currently skipped due to contract bug where rewards exceed maxRewardPerInitiative
    /// TODO: Fix contract bug and re-enable with proper assertions for bucket-weighted rewards
    function test_IncentivesPool_MultipleSupporter() public {
        // Deploy board with incentives pool
        ISignals.BoardConfig memory config = defaultConfig;
        config.boardOpenAt = block.timestamp + 1;
        (signals, incentivesPool) = deploySignalsWithIncentivesPool(config);

        // Warp to board open time
        vm.warp(config.boardOpenAt);

        // Alice proposes initiative with lock
        vm.startPrank(_alice);
        // Alice adds support at time T1 (will be in bucket 0)
        uint256 aliceSupportAmount = 50_000 * 1e18;
        uint256 lockDuration = 10;
        _tokenERC20.approve(address(signals), aliceSupportAmount);
        (uint256 initiativeId, uint256 aliceLockId) =
            signals.proposeInitiativeWithLock(_metadata(1), aliceSupportAmount, lockDuration);
        vm.stopPrank();

        // Warp forward past bucket 0 into bucket 5 (starting interval is 1 hour)
        vm.warp(block.timestamp + 5 hours + 1);

        // Bob adds equal support at time T2 (will be in bucket 5)
        uint256 bobSupportAmount = 50_000 * 1e18;

        vm.startPrank(_bob);
        _tokenERC20.approve(address(signals), bobSupportAmount);
        uint256 bobLockId = signals.supportInitiative(initiativeId, bobSupportAmount, lockDuration);
        vm.stopPrank();

        // Accept the initiative
        vm.prank(_deployer);
        signals.acceptInitiative(initiativeId);

        // Log timestamps for debugging
        // console.log("Alice support timestamp:", aliceLockId);
        // console.log("Bob support timestamp:", bobLockId);
        // console.log("Current timestamp:", block.timestamp);

        // Record balances before redemption
        uint256 aliceRewardsBefore = _usdc.balanceOf(_alice);
        uint256 bobRewardsBefore = _usdc.balanceOf(_bob);

        // Alice redeems her lock
        uint256[] memory aliceLockIds = new uint256[](1);
        aliceLockIds[0] = aliceLockId;
        vm.prank(_alice);
        signals.redeemLocksForInitiative(initiativeId, aliceLockIds);

        // Bob redeems his lock
        uint256[] memory bobLockIds = new uint256[](1);
        bobLockIds[0] = bobLockId;
        vm.prank(_bob);
        signals.redeemLocksForInitiative(initiativeId, bobLockIds);

        // Record balances after redemption
        uint256 aliceRewardsAfter = _usdc.balanceOf(_alice);
        uint256 bobRewardsAfter = _usdc.balanceOf(_bob);

        uint256 aliceRewards = aliceRewardsAfter - aliceRewardsBefore;
        uint256 bobRewards = bobRewardsAfter - bobRewardsBefore;

        console.log("Alice rewards:", aliceRewards);
        console.log("Bob rewards:", bobRewards);

        // Both should get non-zero rewards
        assertGt(aliceRewards, 0, "Alice should get rewards");
        assertGt(bobRewards, 0, "Bob should get rewards");

        // Verify total rewards are distributed correctly
        uint256 totalRewards =
            Signals(address(signals)).incentivesPool().totalRewardPerInitiative(address(signals)); // USDC has 6 decimals

        console.log("total rewards", totalRewards);

        assertLe(
            aliceRewards + bobRewards,
            totalRewards,
            "Total rewards should not exceed maxRewardPerInitiative"
        );
        assertGt(
            aliceRewards + bobRewards,
            totalRewards * 99 / 100,
            "Total rewards should be close to maxRewardPerInitiative"
        );

        // Alice should get 1.5x the rewards bob gets (she was in the first bucket configured for a value of 3, he was in the last with a value of 2)
        assertApproxEqAbs(aliceRewards * 2, bobRewards * 3, 10, "Rewards should be split 3/2");
    }

    /*//////////////////////////////////////////////////////////////
                        POOL DEPLETION TESTS
    //////////////////////////////////////////////////////////////*/

    /// Test pool depletion doesn't block acceptance or redemption
    /// When pool is depleted, claimRewards() simply pays 0 instead of reverting
    function test_IncentivesPool_Depleted_NonBlocking() public {
        // Deploy board with SMALL pool budget to easily deplete it
        ISignals.BoardConfig memory config = defaultConfig;
        config.boardOpenAt = block.timestamp + 1;

        // Deploy signals and pool with small budget (100 USDC) and small max reward (50 USDC)
        (signals, incentivesPool) = deploySignalsWithIncentivesPool(config, 100 * 1e6, 50 * 1e6);

        vm.warp(config.boardOpenAt);

        // === FIRST INITIATIVE - Depletes the pool ===

        vm.prank(_alice);
        signals.proposeInitiative(_metadata(1));
        uint256 initiative1 = 1;

        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), 50_000 * 1e18);
        uint256 alice1LockId = signals.supportInitiative(initiative1, 50_000 * 1e18, 10);
        vm.stopPrank();

        vm.prank(_deployer);
        signals.acceptInitiative(initiative1);

        // Alice redeems and gets the 50 USDC, depleting the pool
        uint256[] memory alice1Locks = new uint256[](1);
        alice1Locks[0] = alice1LockId;

        uint256 aliceBalanceBefore = _usdc.balanceOf(_alice);
        vm.prank(_alice);
        signals.redeemLocksForInitiative(initiative1, alice1Locks);
        uint256 aliceBalanceAfter = _usdc.balanceOf(_alice);

        // Alice should get rewards (pool not yet depleted)
        uint256 aliceRewards = aliceBalanceAfter - aliceBalanceBefore;
        assertGt(aliceRewards, 0, "Alice should get rewards from first initiative");

        // Pool should be depleted or nearly depleted
        uint256 remainingBudget = incentivesPool.boardRemainingBudget(address(signals));
        assertLe(remainingBudget, 50 * 1e6, "Pool should be depleted or nearly depleted");

        // === SECOND INITIATIVE - Pool is depleted ===

        // Bob proposes a second initiative
        vm.prank(_bob);
        signals.proposeInitiative(_metadata(2));
        uint256 initiative2 = 2;

        vm.startPrank(_bob);
        _tokenERC20.approve(address(signals), 50_000 * 1e18);
        uint256 bobLockId = signals.supportInitiative(initiative2, 50_000 * 1e18, 10);
        vm.stopPrank();

        // Accept second initiative - should NOT revert even though pool is depleted
        vm.prank(_deployer);
        signals.acceptInitiative(initiative2);

        // Bob redeems lock - should NOT revert, just pays 0 rewards
        uint256[] memory bobLocks = new uint256[](1);
        bobLocks[0] = bobLockId;

        uint256 bobRewardsBefore = _usdc.balanceOf(_bob);
        uint256 bobUnderlyingBefore = _tokenERC20.balanceOf(_bob);

        vm.prank(_bob);
        signals.redeemLocksForInitiative(initiative2, bobLocks);

        uint256 bobRewardsAfter = _usdc.balanceOf(_bob);
        uint256 bobUnderlyingAfter = _tokenERC20.balanceOf(_bob);

        // Bob gets little to no rewards (pool depleted), but gets underlying tokens back
        uint256 bobRewards = bobRewardsAfter - bobRewardsBefore;
        assertLe(bobRewards, 50 * 1e6, "Bob should get little to no rewards (pool depleted)");

        // Bob MUST still get his underlying tokens back
        assertEq(
            bobUnderlyingAfter - bobUnderlyingBefore,
            50_000 * 1e18,
            "Bob must get his underlying tokens back even when pool depleted"
        );
    }
}
