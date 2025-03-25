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
        modifyLiquidityFromProvider(poolA, 10 ether);

        // Check that the liquidity was added to the pool
        uint128 liquidity = StateLibrary.getLiquidity(manager, poolA.toId());
        assertEq(liquidity, 10 ether, "Incorrect amount of liquidity added");

        // Check that the user was credited with the liquidity
        assertEq(
            bondhook.liquidityBalanceOf(poolA.toId(), address(_liquidityProvider)),
            10 ether,
            "Incorrect user liquidity deposited"
        );
        assertEq(bondhook.getTotalShares(poolA.toId()), 10 ether / 1e6, "Incorrect total shares reported by hook");

        // Check that the user's balances were reduced
        assertEq(_dai.balanceOf(address(_liquidityProvider)), _initialDaiBalance - 10 ether, "Incorrect dai balance");
        assertEq(
            _token.balanceOf(address(_liquidityProvider)), _initialTokenBalance - 10 ether, "Incorrect token balance"
        );

        // Remove liquidity from pool
        modifyLiquidityFromProvider(poolA, -10 ether);

        // Check that the liquidity was removed
        liquidity = StateLibrary.getLiquidity(manager, poolA.toId());
        assertEq(liquidity, 0, "Incorrect amount of liquidity removed");

        // Check that the balance of the user is 0 ether
        assertEq(
            bondhook.liquidityBalanceOf(poolA.toId(), address(_liquidityProvider)),
            0 ether,
            "Incorrect user liquidity removed"
        );

        // Check that the total liquidity is 0 ether
        assertEq(bondhook.getTotalShares(poolA.toId()), 0 ether, "Incorrect total liquidity reported by hook");

        // Check that the user has their starting balances
        assertApproxEqAbs(_dai.balanceOf(address(_liquidityProvider)), _initialDaiBalance, 10, "Incorrect dai balance");
        assertApproxEqAbs(
            _token.balanceOf(address(_liquidityProvider)), _initialTokenBalance, 10, "Incorrect token balance"
        );
    }
}
