// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { Deployers } from "@uniswap/v4-core/test/utils/Deployers.sol";
import { BondHookHarness } from "./utils/BondHookHarness.sol";

import { TickMath } from "v4-core/libraries/TickMath.sol";
import { StateLibrary } from "v4-core/libraries/StateLibrary.sol";

import { DesiredCurrency, SwapData } from "../src/BondHook.sol";
import { BondPoolLibrary } from "../src/utils/BondPool.sol";
/**
 * Goal of this suite is to ensure that a user can purchase bonds from one or many pools
 *
 * Assume pool: DAI/GOV w/ ExampleLinearPricing
 *
 * Base case:
 * - [ ] Purchase bond with DAI from DAI/GOV pool
 *
 * Later:
 * - [ ] Purchase bond with USDC from DAI/GOV pool
 * Extended cases:
 * - [ ] Setup additional pools with different pairs
 * - [ ] Setup additional hooks with alternate pricing contracts
 * - [ ] (v2) Buy bond from DAI/GOV pool with DEGEN
 */
contract UserBuyBondTest is Test, Deployers, BondHookHarness {

    function setUp() public {
        deployFreshManagerAndRouters();
        deployHookAndPools();
        dealMockTokens();
        modifyLiquidityFromProvider(poolA, 1_000_000 ether);
    }

    function test_UserBuysBond() public {
        uint256 tokenId = aliceCreateBondAndWaits(50_000 ether, 50);

        // record pool balances
        uint256 poolLiquidity = StateLibrary.getLiquidity(manager, poolA.toId());

        // alice sells bond for the expected price
        aliceSellBond(tokenId, 22_500 ether);

        uint256 poolLiquidityMiddle = StateLibrary.getLiquidity(manager, poolA.toId());
        // The maximum price we would pay for the bond.
        // 50% of 50k is 25k, plus the 10% fee is 27.5k
        uint256 bondPriceLimit = 27_500 ether;
        bobBuyBond(tokenId, bondPriceLimit);

        // record pool balances
        uint256 poolLiquidityAfter = StateLibrary.getLiquidity(manager, poolA.toId());

        // The pool should have earned profit in the form of liquidity:
        // Bought for 22_500, sold for 27_500 = 5_000 equals 2_500 liquidity as profit
        assertGe(
            poolLiquidityAfter - poolLiquidity, 2_500 ether, "Pool liquidity should have increased"
        );
    }

    function test_UserBuysBondSingleCurrency() public {
        uint256 tokenId = aliceCreateBondAndWaits(50_000 ether, 50);

        // record pool balances
        uint256 _poolLiquidity = StateLibrary.getLiquidity(manager, poolA.toId());

        // alice sells bond for any price
        aliceSellBond(tokenId, 0);

        // The maximum price we would pay for the bond.
        // 50% of 50k is 25k, plus the 10% fee is 27.5k
        uint256 bondPriceLimit = 27_500 ether;

        uint256 _daiBalanceBefore = _dai.balanceOf(address(_bob));
        uint256 _tokenBalanceBefore = _token.balanceOf(address(_bob));

        vm.startPrank(_bob);
        _token.approve(address(bondhook), type(uint256).max);
        _dai.approve(address(bondhook), type(uint256).max);

        // Purchase bond with DAI
        bondhook.swapBond(
            SwapData({
                poolKey: poolA,
                tokenId: tokenId,
                bondPriceLimit: bondPriceLimit,
                swapPriceLimit: poolAIsGovZero ? TickMath.MAX_SQRT_PRICE - 1 : TickMath.MIN_SQRT_PRICE + 1,
                desiredCurrency: poolAIsGovZero ? DesiredCurrency.Currency1 : DesiredCurrency.Currency0
            })
        );
        vm.stopPrank();

        // record pool balances
        uint256 _poolLiquidityAfter = StateLibrary.getLiquidity(manager, poolA.toId());
        uint256 _daiBalanceAfter = _dai.balanceOf(address(_bob));
        uint256 _tokenBalanceAfter = _token.balanceOf(address(_bob));

        // The pool should have earned profit in the form of liquidity:
        // Bought for 22_500, sold for 27_500 = 5_000 equals 2_500 liquidity as profit
        assertGe(
            _poolLiquidityAfter - _poolLiquidity, 2_500 ether, "Pool liquidity should have increased"
        );

        assertGe(
            _daiBalanceBefore - _daiBalanceAfter,
            27_500 ether,
            "Bob should have spent DAI (and some fees)"
        );
        assertEq(_tokenBalanceAfter, _tokenBalanceBefore, "Bob should have no change of GOV");
    }
}
