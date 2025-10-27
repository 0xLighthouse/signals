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
        vm.expectRevert(ISignals.Signals_BoardAlreadyOpened.selector);
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
        signals.proposeInitiative("Test Initiative", "Alice's initiative without support");

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

    /// Test reward calculation with multiple supporters at different times
    function test_IncentivesPool_MultipleSupporter_LinearDecay() public {}

    /// Test immediate acceptance (duration = 0) gives equal weight
    function test_IncentivesPool_ImmediateAcceptance_EqualWeight() public {}

    /*//////////////////////////////////////////////////////////////
                        REWARD AUTO-CLAIM TESTS
    //////////////////////////////////////////////////////////////*/

    /// Test rewards are auto-claimed on redeem
    function test_IncentivesPool_AutoClaimOnRedeem() public {}

    /// Test manual claim still works if user prefers
    function test_IncentivesPool_ManualClaimStillWorks() public {}

    /// Test redeeming after manual claim doesn't fail
    function test_IncentivesPool_RedeemAfterManualClaim() public {}

    /*//////////////////////////////////////////////////////////////
                        POOL DEPLETION TESTS
    //////////////////////////////////////////////////////////////*/

    /// Test pool depletion doesn't block acceptance
    function test_IncentivesPool_Depleted_NonBlocking() public {}
}
