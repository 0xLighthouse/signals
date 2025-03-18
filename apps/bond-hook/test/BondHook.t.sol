// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { MockERC20 } from "solmate/src/test/utils/mocks/MockERC20.sol";
import { Deployers } from "@uniswap/v4-core/test/utils/Deployers.sol";
import { SortTokens } from "@uniswap/v4-core/test/utils/SortTokens.sol";
import { Hooks } from "v4-core/libraries/Hooks.sol";
import { PoolKey } from "v4-core/types/PoolKey.sol";
import { Currency } from "v4-core/types/Currency.sol";
import { BalanceDelta, BalanceDeltaLibrary } from "v4-core/types/BalanceDelta.sol";
import { PoolSwapTest } from "v4-core/test/PoolSwapTest.sol";
import { IPoolManager } from "v4-core/interfaces/IPoolManager.sol";
import { TickMath } from "v4-core/libraries/TickMath.sol";
import { StateLibrary } from "v4-core/libraries/StateLibrary.sol";

import { IBondIssuer } from "../src/interfaces/IBondIssuer.sol";
import { BondHook } from "../src/BondHook.sol";
import { BondHookHarness } from "./utils/BondHookHarness.sol";

import { ExampleLinearPricing } from "../src/pricing/ExampleLinearPricing.sol";
import { IBondPricing } from "../src/interfaces/IBondPricing.sol";

contract BondHookTest is Test, Deployers, BondHookHarness {

    function setUp() public {
        deployFreshManagerAndRouters();
        deployHookAndPools();
    }

    // Test that a pool is rejected if the underlying token is not part of the pair
    function test_Revert_initializePoolWithoutBondToken() public {
        (currency0, currency1) = SortTokens.sort(_dai, _usdc);
        // Creating this pool should revert
        vm.expectRevert();
        initPool(currency0, currency1, bondhook, 3000, SQRT_PRICE_1_1);
    }

    // A non-hook swap should work fine
    function test_NormalSwap() public {
        dealMockTokens();
        modifyLiquidityFromProvider(poolA, 1_000_000 ether);

        vm.startPrank(_alice);
        // _token.approve(address(swapRouter), 100_000 either);
        _dai.approve(address(swapRouter), 100_000 ether);

        uint256 govBalanceBefore = _token.balanceOf(address(_alice));
        uint256 daiBalanceBefore = _dai.balanceOf(address(_alice));

        // Buy 1 gov token
        vm.startPrank(_alice);
        swapRouter.swap(
            poolA,
            IPoolManager.SwapParams({
                zeroForOne: !poolAIsGovZero,
                amountSpecified: 1 ether,
                sqrtPriceLimitX96: poolAIsGovZero ? TickMath.MAX_SQRT_PRICE - 1 : TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            // hookData
            ZERO_BYTES
        );

        assertEq(_token.balanceOf(address(_alice)), govBalanceBefore + 1 ether);
        assertLt(_dai.balanceOf(address(_alice)), daiBalanceBefore);
    }
}
