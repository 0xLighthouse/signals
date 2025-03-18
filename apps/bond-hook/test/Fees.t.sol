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

import {BondHook, LiquidityData, DesiredCurrency, SwapData, ONE_HUNDRED_PERCENT} from "../src/BondHook.sol";

contract FeesTest is Test, Deployers, BondHookHarness {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    function setUp() public {
        deployFreshManagerAndRouters();
        dealMockTokens();
    }

    function test_OwnerFee() public {
        uint256 feeRate = 3_0000;

        deployHookWithFeesAndPools(feeRate, 0, 0); // 3% fee for owner
        modifyLiquidityFromProvider(poolA, 1_000_000 ether);

         uint256 tokenId = aliceCreateBondAndWaits(50_000 ether, 50);
        aliceSellBond(tokenId, 22_500 ether);
        bobBuyBond(tokenId, 27_500 ether);

        // 2_500 in profit should have been generated, generating 3% for the owner
        assertApproxEqAbs(bondhook.ownerFees(), 2_500 ether * feeRate / ONE_HUNDRED_PERCENT, 100, "Owner fee should be 3% of profit");
    }

    // function test_earnFees() public {
    //     return;
    //     uint256 _initialDaiBalance = _dai.balanceOf(address(_liquidityProvider));
    //     uint256 _initialTokenBalance = _token.balanceOf(address(_liquidityProvider));

    //     // Add liquidity to pool as liquidity provider
    //     modifyLiquidityFromProvider(poolA, 100_000 ether);

    //     vm.startPrank(_alice);
    //     uint256 tokenId = bondIssuer.createBond(1, 50_000 ether, 365 days);

    //     // Jump ahead to when bond is worth 50%
    //     vm.warp(block.timestamp + 365 days / 2);

    //     // approve and sell bond into the pool
    //     bondIssuer.approve(address(bondhook), tokenId);
    //     bondhook.swapBond(
    //         SwapData({
    //             poolKey: poolA,
    //             tokenId: tokenId,
    //             bondPriceLimit: 0,
    //             swapPriceLimit: 0,
    //             desiredCurrency: DesiredCurrency.Mixed
    //         })
    //     );
    //     vm.stopPrank();

    //     // The maximum price we would pay for the bond.
    //     // 50% of 50k is 25k, plus the 10% fee is 27.5k
    //     uint256 bondPriceLimit = 27_500 ether;

    //     // Bob buys the bond
    //     vm.startPrank(_bob);
    //     _token.approve(address(bondhook), type(uint256).max);
    //     _dai.approve(address(bondhook), type(uint256).max);

    //     bondhook.swapBond(
    //         SwapData({
    //             poolKey: poolA,
    //             tokenId: tokenId,
    //             bondPriceLimit: bondPriceLimit,
    //             swapPriceLimit: 0,
    //             desiredCurrency: DesiredCurrency.Mixed
    //         })
    //     );
    //     vm.stopPrank();

    //     // Finally, LP removes original liquidity from pool
    //     // TODO: What happens when LP is in an IL position?
    //     modifyLiquidityFromProvider(poolA, -100_000 ether);

    //     // we should have earned all of the profit.
    //     assertEq(
    //         bondhook.balanceOf(poolA.toId(), address(_liquidityProvider)), 0 ether, "Incorrect user liquidity removed"
    //     );

    //     bondhook.claimRewards(poolA);
    //     uint256 _profit = bondhook.balanceOf(poolA.toId(), address(_liquidityProvider));
    //     assertEq(_profit, 2_500 ether, "Incorrect amount of profit earned");

    //     uint128 _liquidity = StateLibrary.getLiquidity(manager, poolA.toId());
    //     console.log("liquidity", _liquidity);

    //     // Withdraw the profit
    //     modifyLiquidityFromProvider(poolA, -int128(int256(_profit)));

    //     // Assert how much profit was generated from this position
    //     // Users should have ended up with 2.5k more than they started with
    //     assertApproxEqAbs(
    //         _dai.balanceOf(address(_liquidityProvider)), _initialDaiBalance + 2_500 ether, 1000, "Incorrect dai balance"
    //     );
    //     assertApproxEqAbs(
    //         _token.balanceOf(address(_liquidityProvider)),
    //         _initialTokenBalance + 2_500 ether,
    //         1000,
    //         "Incorrect token balance"
    //     );
    // }

}
