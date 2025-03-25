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
import { TickMath } from "v4-core/libraries/TickMath.sol";
import { BondPoolState, BondPoolLibrary, ONE_HUNDRED_PERCENT } from "../src/utils/BondPool.sol";
import { LiquidityAmounts } from "../src/utils/LiquidityAmounts.sol";

contract BondPoolLibraryTest is Test, Deployers, BondHookHarness {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;
    using BondPoolLibrary for BondPoolState;

    BondPoolState internal state;
    uint256 constant TEST_AMOUNT = 1000 ether;

    function setUp() public {
        deployFreshManagerAndRouters();
        deployHookAndPools();
        dealMockTokens();
        
        // Get initial state from the deployed pool
        state = bondhook._getPoolState(poolA.toId());
    }

    function test_swapAmountForConversion() public {

      uint160 price = SQRT_PRICE_1_1;
      uint160 maxPrice = TickMath.getSqrtPriceAtTick(TickMath.maxUsableTick(state.key.tickSpacing));
      uint160 minPrice = TickMath.getSqrtPriceAtTick(TickMath.minUsableTick(state.key.tickSpacing));

      uint256 amountInBondToken = 10 ether;
      uint256 amountToSwap = BondPoolLibrary._calculateSwapAmountForLiquidityConversion(price, maxPrice, minPrice, amountInBondToken, true);

      // At a price of 1:1, this should tell us to sell half
      assertApproxEqAbs(amountToSwap, amountInBondToken / 2, 10, "Amount to swap should be half of the input amount");
    }

}
