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


import {BondHook, BondPoolState, LiquidityData, DesiredCurrency, SwapData, ONE_HUNDRED_PERCENT} from "../src/BondHook.sol";

contract FeesTest is Test, Deployers, BondHookHarness {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    function setUp() public {
        deployFreshManagerAndRouters();
        dealMockTokens();
    }

    function test_ProfitShare() public {
        // uint256 feeRate = 3_0000;
        // uint256 feeReductionRate = 50_0000;       

        // deployHookWithFeesAndPools(feeRate, feeReductionRate, 0, 0); // 3% fee for owner, 50% credited towards fee reduction
        // modifyLiquidityFromProvider(poolA, 1_000_000 ether);

        //  uint256 tokenId = aliceCreateBondAndWaits(50_000 ether, 50);
        // aliceSellBond(tokenId, 22_500 ether);
        // bobBuyBond(tokenId, 27_500 ether);

        // // 2_500 in profit should have been generated, generating 3% for the owner
        // assertApproxEqAbs(bondhook.ownerFees(), 2_500 ether * feeRate / ONE_HUNDRED_PERCENT, 100, "Owner fee should be 3% of profit");
        // assertApproxEqAbs(bondhook.liquidityForFeeReduction(poolA.toId()), 2_500 ether * feeReductionRate / ONE_HUNDRED_PERCENT, 100, "Fee reduction should be 50% of profit");
    }

    function test_lpEarnFees() public {
        // deployHookAndPools(); 

        // uint256 _initialDaiBalance = _dai.balanceOf(address(_liquidityProvider));
        // uint256 _initialTokenBalance = _token.balanceOf(address(_liquidityProvider));

        // // Add liquidity, bond gets sold and bought, remove original liquidity
        // modifyLiquidityFromProvider(poolA, 100_000 ether);
        // uint256 tokenId = aliceCreateBondAndWaits(50_000 ether, 50);
        // aliceSellBond(tokenId, 22_500 ether);
        // bobBuyBond(tokenId, 27_500 ether);
        // modifyLiquidityFromProvider(poolA, -100_000 ether);

        // // we should have earned all of the profit.
        // assertEq(
        //     bondhook.liquidityBalanceOf(poolA.toId(), address(_liquidityProvider)), 0 ether, "Incorrect user liquidity removed"
        // );

        // vm.prank(_liquidityProvider);
        // bondhook.claimRewards(poolA);
        // uint256 _profit = bondhook.liquidityBalanceOf(poolA.toId(), address(_liquidityProvider));
        // assertEq(_profit, 2_500 ether, "Incorrect amount of profit earned"); 

        // // Withdraw the profit
        // modifyLiquidityFromProvider(poolA, -int128(int256(_profit)));

        // // Users should have ended up with 2.5k more than they started with
        // assertApproxEqAbs(
        //     _dai.balanceOf(address(_liquidityProvider)), _initialDaiBalance + 2_500 ether, 1000, "Incorrect dai balance"
        // );
        // assertApproxEqAbs(
        //     _token.balanceOf(address(_liquidityProvider)),
        //     _initialTokenBalance + 2_500 ether,
        //     1000,
        //     "Incorrect token balance"
        // );
    }

    function test_playground() public {
        // deployHookAndPools();
        // modifyLiquidityFromProvider(poolA, 10_000 ether);

        // // get current sqrt price
        // // (uint160 sqrtPriceX96,,,) = StateLibrary.getSlot0(poolManager, poolA.toId());

        // uint256 liquidity = LiquidityAmounts.getLiquidityForAmount0(TickMath.MIN_SQRT_PRICE, TickMath.MAX_SQRT_PRICE, 10 ether);
        // console.log("liquidity", liquidity);

        // // Do a swap
        //  vm.startPrank(_alice);
        //  _dai.approve(address(swapRouter), 10000 ether);
        //  _token.approve(address(swapRouter), 10000 ether);
        // swapRouter.swap(
        //     poolA,
        //     IPoolManager.SwapParams({
        //         zeroForOne: !poolAIsGovZero,
        //         amountSpecified: 100 ether,
        //         sqrtPriceLimitX96: poolAIsGovZero ? TickMath.MAX_SQRT_PRICE - 1 : TickMath.MIN_SQRT_PRICE + 1
        //     }),
        //     PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
        //     // hookData
        //     ZERO_BYTES
        // );
        // vm.stopPrank();

        // uint256 liquidity2 = LiquidityAmounts.getLiquidityForAmount0(TickMath.MIN_SQRT_PRICE, TickMath.MAX_SQRT_PRICE, 10 ether);
        // console.log("liquidity2", liquidity2);


    }
}
