// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { Deployers } from "@uniswap/v4-core/test/utils/Deployers.sol";
import { BondHookHarness } from "./utils/BondHookHarness.sol";

/**
 * Goal of this suite is to ensure that our ExampleLinearPricing model is working as expected
 *
 * - [ ] Price bonds at t0 (immediately)
 * - [ ] Price bonds at t3 (3/12)
 * - [ ] Price bonds at t6 (6/12)
 * - [ ] Price bonds at t9 (9/12)
 * - [ ] Price bonds at t12 (12/12)
 */
contract PriceLinearBondsTest is Test, Deployers, BondHookHarness {

    function setUp() public {
        deployFreshManagerAndRouters();
        deployHookAndPools();
    }

    /**
     * [ ] Sell bond for UNI (exact output swap) single-hop pool [BOND -> UNI]
     * <https://8640p.slack.com/archives/C089L09UCFR/p1739202925580799>
     */
    function test_QuoteExactSingleOutput() public {
        // TODO: Sell bond into the pool

        // // Alice locks 50k against an initiative for 1 year
        // uint256 bondA = lockTokensAndIssueBond(signals, _alice, 50_000, 12);
        // console.log("Token ID:", bondA);

        //  IV4Quoter.QuoteExactSingleParams memory p = IQuoter
        //         .QuoteExactSingleParams({
        //             poolKey: _key,
        //             zeroForOne: zeroForOne,
        //             recipient: address(this),
        //             exactAmount: 1,
        //             sqrtPriceLimitX96: Deployers.MIN_PRICE_LIMIT,
        //             hookData: ZERO_BYTES
        //         });

        // // Quote selling it into the pool at t0 (immediately)
        // uint256 amountOut = bondhook.nominalAmount(bondA);
        // assertEq(amountOut, 0);

        // // Quote selling it into the pool at t3 (3/12 months)
        // vm.warp(block.timestamp + 3 * 30 days);
        // amountOut = bondhook.nominalAmount(bondA);
        // assertEq(amountOut, 10000); // (3/12 * 50k) * 0.8 = 10k

        // // Quote selling it into the pool at t6 (6/12 months)
        // vm.warp(block.timestamp + 6 * 30 days);
        // amountOut = bondhook.nominalAmount(bondA);
        // assertEq(amountOut, 20000); // (6/12 * 50k) * 0.8 = 20k

        // TODO: Sell the bond into the pool at t8 (8/12 months)
        // uint256 tokenId = 1;
        // uint256 amount = 1000;
        // bytes memory hookData = abi.encode(tokenId, amount);
        // swapRouter.swap(
        //   _keyA,
        //   IPoolManager.SwapParams({zeroForOne: true, amountSpecified: 1000, sqrtPriceLimitX96: 1}),
        //   PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
        //   hookData
        // );
    }
}
