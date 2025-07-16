// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { Deployers } from "@uniswap/v4-core/test/utils/Deployers.sol";
import { BondHookHarness } from "./utils/BondHookHarness.sol";

import { TickMath } from "v4-core/libraries/TickMath.sol";
import { DesiredCurrency, SwapData } from "../src/BondHook.sol";

/**
 * Goal of this suite is to ensure that a user can sell a bond into the pool
 *
 * Assume pool: DAI/GOV w/ ExampleLinearPricing
 *
 * Base case:
 * - [x] Sell bond for DAI from DAI/GOV pool
 *
 * Later:
 * - [ ] Sell bond for USDC from DAI/GOV pool
 * - [ ] Setup additional pool (USDC/GOV)
 *      - [ ] Sell bond into both pools (USDC/GOV, DAI/GOV)
 *      - [ ] Ensure hook registers which NFT belongs to which pool
 * - [ ] Setup additional hooks with alternate pricing contracts
 * Multi hop swaps:
 * - [ ] (v2) Sell bond for USDT when there is only DAI/GOV pool
 * - [ ] (v2) Sell bond for USDT when there is [DAI/GOV, DEGEN/GOV] pool
 */
contract UserSellBondTest is Test, Deployers, BondHookHarness {
  
    function setUp() public {
        deployFreshManagerAndRouters();
        deployHookAndPools();
        dealMockTokens();
        modifyLiquidityFromProvider(poolA, 1_000_000 ether);
    }

    function test_UserSellsBond() public {
        // Alice locks 50k against an initiative for 1 year
        vm.startPrank(_alice);
        uint256 tokenId = bondIssuer.createBond(1, 50_000 ether, 365 days);
        vm.stopPrank();

        // Jump ahead to when bond is worth 50%
        vm.warp(block.timestamp + 365 days / 2);

        // The minimum price we will accept for the bond.
        // 50% of 50k is 25k, minus the 10% fee is 22.5k
        uint256 bondPriceLimit = 22_500 ether;

        // record balances
        uint256 _aliceBondBefore = bondIssuer.balanceOf(address(_alice));
        uint256 _poolBondBefore = bondIssuer.balanceOf(address(bondhook));
        uint256 _govBefore = _token.balanceOf(address(_alice));
        uint256 _daiBefore = _dai.balanceOf(address(_alice));

        aliceSellBond(tokenId, bondPriceLimit);

        uint256 _govAfter = _token.balanceOf(address(_alice));
        uint256 _daiAfter = _dai.balanceOf(address(_alice));
        uint256 _bondAfter = bondIssuer.balanceOf(address(_alice));
        uint256 _poolBondAfter = bondIssuer.balanceOf(address(bondhook));

        console.log("bondPriceLimit", bondPriceLimit/ 1e18);
        console.log("govBefore", _govBefore/ 1e18);
        console.log("govAfter", _govAfter/ 1e18);
        console.log("daiBefore", _daiBefore/ 1e18);
        console.log("daiAfter", _daiAfter/ 1e18);

        // Alice should end up with 22.5k liquidity (11.25k gov, 11.25k dai)
        assertApproxEqAbs(_govAfter, _govBefore + (bondPriceLimit / 2), 1000, "Alice Gov balance incorrect");
        assertApproxEqAbs(_daiAfter, _daiBefore + (bondPriceLimit / 2), 1000, "Alice DAI balance incorrect");
        // The bond should be transfered to the pool
        assertEq(_bondAfter, 0, "Alice Bond balance incorrect");
        assertEq(_poolBondAfter, 1, "Pool Bond balance incorrect");
    }

    function test_UserSellsBondSingleCurrency() public {
        // Alice locks 50k against an initiative for 1 year
        vm.startPrank(_alice);
        uint256 tokenId = bondIssuer.createBond(1, 50_000 ether, 365 days);
        vm.stopPrank();

        // Jump ahead to when bond is worth 50%
        vm.warp(block.timestamp + 365 days / 2);

        // The minimum price we will accept for the bond.
        // 50% of 50k is 25k, minus the 10% fee is 22.5k
        uint256 bondPriceLimit = 22_500 ether;

        // record balances
        uint256 _aliceBondBefore = bondIssuer.balanceOf(address(_alice));
        uint256 _poolBondBefore = bondIssuer.balanceOf(address(bondhook));
        uint256 _govBefore = _token.balanceOf(address(_alice));
        uint256 _daiBefore = _dai.balanceOf(address(_alice));

        // approve and swap the bond into the pool, requesting only gov tokens in return
        vm.startPrank(_alice);
        bondIssuer.approve(address(bondhook), tokenId);
        bondhook.swapBond(
            SwapData({
                poolKey: poolA,
                tokenId: tokenId,
                bondPriceLimit: bondPriceLimit,
                swapPriceLimit: poolAIsGovZero ? TickMath.MAX_SQRT_PRICE - 1 : TickMath.MIN_SQRT_PRICE + 1,
                desiredCurrency: poolAIsGovZero ? DesiredCurrency.Currency0 : DesiredCurrency.Currency1
            })
        );
        vm.stopPrank();

        uint256 _govAfter = _token.balanceOf(address(_alice));
        uint256 _daiAfter = _dai.balanceOf(address(_alice));
        uint256 _aliceBondAfter = bondIssuer.balanceOf(address(_alice));
        uint256 _poolBondAfter = bondIssuer.balanceOf(address(bondhook));

        //Alice should end up with around 22.5k in gov, minus the 3% trading fee
        assertApproxEqAbs(_govAfter - _govBefore, bondPriceLimit, _govAfter * 3 / 100, "Alice Gov balance incorrect");
        assertEq(_daiAfter, _daiBefore, "Alice DAI balance incorrect");
        // The bond should be transfered to the pool
        assertEq(_aliceBondAfter, 0, "Alice Bond balance incorrect");
        assertEq(_poolBondAfter, 1, "Pool Bond balance incorrect");
    }
}
