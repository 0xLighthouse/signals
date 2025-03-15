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

import {BondHook, LiquidityData, DesiredCurrency, SwapData} from "../src/BondHook.sol";

contract ModifyLiquidityTest is Test, Deployers, BondHookHarness {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    function setUp() public {
        deployFreshManagerAndRouters();
        deployHookAndPools();
        dealMockTokens();
    }

    function test_Revert_addLiquidityInvalidPool() public {
        // Add liquidity to unknown pool
        vm.expectRevert(BondHook.PoolNotInitialized.selector);
        bondhook.modifyLiquidity(
            LiquidityData({
                poolKey: PoolKey({
                    currency0: Currency.wrap(address(234)),
                    currency1: Currency.wrap(address(345)),
                    fee: 3000,
                    tickSpacing: 100,
                    hooks: bondhook
                }),
                liquidityDelta: 10 ether,
                desiredCurrency: DesiredCurrency.Mixed,
                swapPriceLimit: 0
            })
        );
    }

    function test_addRemoveLiquidity() public {
        uint256 _initialDaiBalance = _dai.balanceOf(address(_liquidityProvider));
        uint256 _initialTokenBalance = _token.balanceOf(address(_liquidityProvider));

        // Add liquidity to pool as liquidity provider
        vm.startPrank(_liquidityProvider);
        bondhook.modifyLiquidity(
            LiquidityData({
                poolKey: poolA,
                liquidityDelta: 10 ether,
                desiredCurrency: DesiredCurrency.Mixed,
                swapPriceLimit: 0
            })
        );
        vm.stopPrank();

        // Check that the liquidity was added to the pool
        uint128 liquidity = StateLibrary.getLiquidity(manager, poolA.toId());
        assertEq(liquidity, 10 ether, "Incorrect amount of liquidity added");

        // Check that the user was credited with the liquidity
        assertEq(
            bondhook.balanceOf(poolA.toId(), address(_liquidityProvider)),
            10 ether,
            "Incorrect user liquidity deposited"
        );
        assertEq(bondhook.totalShares(poolA.toId()), 10 ether / 1e6, "Incorrect total shares reported by hook");

        // Check that the user's balances were reduced
        assertEq(_dai.balanceOf(address(_liquidityProvider)), _initialDaiBalance - 10 ether, "Incorrect dai balance");
        assertEq(
            _token.balanceOf(address(_liquidityProvider)), _initialTokenBalance - 10 ether, "Incorrect token balance"
        );

        // Remove liquidity from pool
        vm.startPrank(_liquidityProvider);
        bondhook.modifyLiquidity(
            LiquidityData({
                poolKey: poolA,
                liquidityDelta: -10 ether,
                desiredCurrency: DesiredCurrency.Mixed,
                swapPriceLimit: 0
            })
        );
        vm.stopPrank();

        // Check that the liquidity was removed
        liquidity = StateLibrary.getLiquidity(manager, poolA.toId());
        assertEq(liquidity, 0, "Incorrect amount of liquidity removed");

        // Check that the balance of the user is 0 ether
        assertEq(
            bondhook.balanceOf(poolA.toId(), address(_liquidityProvider)), 0 ether, "Incorrect user liquidity removed"
        );

        // Check that the total liquidity is 0 ether
        assertEq(bondhook.totalShares(poolA.toId()), 0 ether, "Incorrect total liquidity reported by hook");

        // Check that the user has their starting balances
        assertApproxEqAbs(_dai.balanceOf(address(_liquidityProvider)), _initialDaiBalance, 10, "Incorrect dai balance");
        assertApproxEqAbs(
            _token.balanceOf(address(_liquidityProvider)), _initialTokenBalance, 10, "Incorrect token balance"
        );
    }

    function test_earnFees() public {
        uint256 _initialDaiBalance = _dai.balanceOf(address(_liquidityProvider));
        uint256 _initialTokenBalance = _token.balanceOf(address(_liquidityProvider));

        // Add liquidity to pool as liquidity provider
        vm.startPrank(_liquidityProvider);
        bondhook.modifyLiquidity(
            LiquidityData({
                poolKey: poolA,
                liquidityDelta: 100_000 ether,
                desiredCurrency: DesiredCurrency.Mixed,
                swapPriceLimit: 0
            })
        );
        vm.stopPrank();

        vm.startPrank(_alice);
        uint256 tokenId = bondIssuer.createBond(1, 50_000 ether, 365 days);

        // Jump ahead to when bond is worth 50%
        vm.warp(block.timestamp + 365 days / 2);

        // approve and sell bond into the pool
        bondIssuer.approve(address(bondhook), tokenId);
        bondhook.swapBond(
            SwapData({
                poolKey: poolA,
                tokenId: tokenId,
                bondPriceLimit: 0,
                swapPriceLimit: 0,
                desiredCurrency: DesiredCurrency.Mixed
            })
        );
        vm.stopPrank();

        // The maximum price we would pay for the bond.
        // 50% of 50k is 25k, plus the 10% fee is 27.5k
        uint256 bondPriceLimit = 27_500 ether;

        // Bob buys the bond
        vm.startPrank(_bob);
        _token.approve(address(bondhook), type(uint256).max);
        _dai.approve(address(bondhook), type(uint256).max);

        bondhook.swapBond(
            SwapData({
                poolKey: poolA,
                tokenId: tokenId,
                bondPriceLimit: bondPriceLimit,
                swapPriceLimit: 0,
                desiredCurrency: DesiredCurrency.Mixed
            })
        );
        vm.stopPrank();

        // Finally, LP removes original liquidity from pool
        // TODO: What happens when LP is in an IL position?
        vm.startPrank(_liquidityProvider);
        bondhook.modifyLiquidity(
            LiquidityData({
                poolKey: poolA,
                liquidityDelta: -100_000 ether,
                desiredCurrency: DesiredCurrency.Mixed,
                swapPriceLimit: 0
            })
        );

        // we should have earned all of the profit.
        assertEq(
            bondhook.balanceOf(poolA.toId(), address(_liquidityProvider)), 0 ether, "Incorrect user liquidity removed"
        );

        bondhook.claimRewards(poolA);
        uint256 _profit = bondhook.balanceOf(poolA.toId(), address(_liquidityProvider));
        vm.stopPrank();
        assertEq(_profit, 2_500 ether, "Incorrect amount of profit earned");

        uint128 _liquidity = StateLibrary.getLiquidity(manager, poolA.toId());
        console.log("liquidity", _liquidity);

        // Withdraw the profit
        vm.startPrank(_liquidityProvider);
        bondhook.modifyLiquidity(
            LiquidityData({
                poolKey: poolA,
                liquidityDelta: -int128(int256(_profit)),
                desiredCurrency: DesiredCurrency.Mixed,
                swapPriceLimit: 0
            })
        );
        vm.stopPrank();

        // Assert how much profit was generated from this position
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
}
