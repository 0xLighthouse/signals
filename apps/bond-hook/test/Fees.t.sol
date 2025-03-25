// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {BondHookHarness} from "./utils/BondHookHarness.sol";

import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {LiquidityAmounts} from "v4-core-test/utils/LiquidityAmounts.sol";

import {TickMath} from "v4-core/libraries/TickMath.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";

import {BondHook, LiquidityData, DesiredCurrency, SwapData} from "../src/BondHook.sol";
import {BondPoolState, BondPoolLibrary, ONE_HUNDRED_PERCENT} from "../src/utils/BondPool.sol";

contract FeesTest is Test, Deployers, BondHookHarness {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    function setUp() public {
        deployFreshManagerAndRouters();
        dealMockTokens();
    }

    function test_ProfitShare() public {
        uint256 feeRate = 3_0000; // %3
        uint256 feeCreditRatio = 50_0000; // 50%
        uint24 swapFeeNormal = 1_0000; // %1
        uint24 swapFeeDiscounted = 0; // %0

        deployHookWithFeesAndPools(feeRate, feeCreditRatio, swapFeeNormal, swapFeeDiscounted, SQRT_PRICE_1_1); // 3% fee for owner, 50% credited towards fee reduction
        modifyLiquidityFromProvider(poolA, 1_000_000 ether);

        uint256 tokenId = aliceCreateBondAndWaits(50_000 ether, 50);
        aliceSellBond(tokenId, 22_500 ether);
        bobBuyBond(tokenId, 27_500 ether);

        // 2_500 in profit should have been generated, generating 3% for the owner
        assertApproxEqAbs(
            bondhook.ownerFees(), 2_500 ether * feeRate / ONE_HUNDRED_PERCENT, 100, "Owner fee should be 3% of profit"
        );

        uint256 profitMinusFees = 2_500 ether - bondhook.ownerFees();
        uint256 feeForReductionAsLiquidity = profitMinusFees * feeCreditRatio / ONE_HUNDRED_PERCENT;
        int256 feeForReductionAsBondToken = BondPoolLibrary.getUnderlyingAmountForLiquidity(
            bondhook._getPoolState(poolA.toId()), int256(feeForReductionAsLiquidity), SQRT_PRICE_1_1
        );

        assertApproxEqAbs(
            uint256(bondhook.creditForFeeReduction(poolA.toId())),
            uint256(feeForReductionAsBondToken),
            1000,
            "Fee reduction should be 50% of profit"
        );
    }

    function test_lpEarnFees() public {
        deployHookAndPools();

        uint256 _initialDaiBalance = _dai.balanceOf(address(_liquidityProvider));
        uint256 _initialTokenBalance = _token.balanceOf(address(_liquidityProvider));

        // Add liquidity, bond gets sold and bought, remove original liquidity
        modifyLiquidityFromProvider(poolA, 100_000 ether);
        uint256 tokenId = aliceCreateBondAndWaits(50_000 ether, 50);
        aliceSellBond(tokenId, 22_500 ether);
        bobBuyBond(tokenId, 27_500 ether);
        modifyLiquidityFromProvider(poolA, -100_000 ether);

        // we should have earned all of the profit.
        assertEq(
            bondhook.liquidityBalanceOf(poolA.toId(), address(_liquidityProvider)),
            0 ether,
            "Incorrect user liquidity removed"
        );

        vm.prank(_liquidityProvider);
        bondhook.claimRewards(poolA);
        uint256 _profit = bondhook.liquidityBalanceOf(poolA.toId(), address(_liquidityProvider));
        assertEq(_profit, 2_500 ether, "Incorrect amount of profit earned");

        // Withdraw the profit
        modifyLiquidityFromProvider(poolA, -int128(int256(_profit)));

        // Users should have ended up with 2.5k more than they started with
        assertApproxEqAbs(
            _dai.balanceOf(address(_liquidityProvider)), _initialDaiBalance + 2_500 ether, 1000, "Incorrect dai balance"
        );
        assertApproxEqAbs(
            _token.balanceOf(address(_liquidityProvider)),
            _initialTokenBalance + 2_500 ether,
            1000,
            "Incorrect token balance"
        );
    }

    function test_reducedFeesWhenAvailable() public {
        // 0% fee for owner, 50% fee credit ratio, 10% normal fee, 0% reduced fee
        deployHookWithFeesAndPools(0, 50_0000, 10_0000, 0, SQRT_PRICE_1_1);
        // deployHookAndPools();
        modifyLiquidityFromProvider(poolA, 100_000 ether);

        // Alice does a swap, and gets charged fees
        uint256 aliceBalanceBefore = _token.balanceOf(address(_alice));
        aliceSwap(-100 ether, false);

        uint256 aliceBalanceAfter = _token.balanceOf(address(_alice));
        assertApproxEqAbs(
            aliceBalanceAfter - aliceBalanceBefore, 90 ether, 1 ether, "Alice should have lost 3% in the trade"
        );

        // Create a bond
        uint256 tokenId = aliceCreateBondAndWaits(50_000 ether, 50);
        aliceSellBond(tokenId, 22_500 ether);
        bobBuyBond(tokenId, 27_500 ether);

        int256 creditBefore = bondhook.creditForFeeReduction(poolA.toId());
        assertGt(creditBefore, 0, "There should be some credit for fee reduction");

        aliceBalanceBefore = _token.balanceOf(address(_alice));
        aliceSwap(-100 ether, false);
        aliceBalanceAfter = _token.balanceOf(address(_alice));
        assertApproxEqAbs(
            aliceBalanceAfter - aliceBalanceBefore, 100 ether, 1 ether, "Alice should have traded with no fees"
        );

        int256 creditAfter = bondhook.creditForFeeReduction(poolA.toId());
        assertApproxEqAbs(creditAfter - 100 ether, creditBefore, 1 ether, "Fee credit should have reduced");
    }
}
