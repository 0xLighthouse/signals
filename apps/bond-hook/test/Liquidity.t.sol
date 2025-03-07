// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { Deployers } from "@uniswap/v4-core/test/utils/Deployers.sol";
import { BondHookHarness } from "./utils/BondHookHarness.sol";

import { PoolKey } from "v4-core/types/PoolKey.sol";
import { PoolIdLibrary } from "v4-core/types/PoolId.sol";
import { Currency, CurrencyLibrary } from "v4-core/types/Currency.sol";
import { StateLibrary } from "v4-core/libraries/StateLibrary.sol";

import { BondHook, LiquidityData, DesiredCurrency } from "../src/BondHook.sol";

contract ModifyLiquidityTest is Test, Deployers, BondHookHarness {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    function setUp() public {
        deployFreshManagerAndRouters();
        deployHookAndPools();
    }

    function test_addRemoveLiquidity() public {
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

        // Check that the liquidity was added
        uint128 liquidity = StateLibrary.getLiquidity(manager, poolA.toId());
        assertEq(liquidity, 10 ether, "Incorrect amount of liquidity added");

        // Check that the balance of the user is 10 ether
        assertEq(bondhook.balanceOf(poolA.toId(), address(this)), 10 ether, "Incorrect user balance");

        // Check that the total liquidity is 10 ether
        assertEq(bondhook.totalShares(poolA.toId()), 10 ether / 1e6, "Incorrect total liquidity reported by hook");

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
        assertEq(bondhook.balanceOf(poolA.toId(), address(this)), 0 ether, "Incorrect user balance");

        // Check that the total liquidity is 0 ether
        assertEq(bondhook.totalShares(poolA.toId()), 0 ether, "Incorrect total liquidity reported by hook");

        // Check that the user has their starting balances
        assertApproxEqAbs(_dai.balanceOf(address(this)), 100 ether, 10, "Incorrect dai balance");
        assertApproxEqAbs(_token.balanceOf(address(this)), 100 ether, 10, "Incorrect token balance");
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
}
