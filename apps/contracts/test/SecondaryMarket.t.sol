// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";

import {PoolManager} from "v4-core/PoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

import {Signals} from "../src/Signals.sol";
import {SignalsHarness} from "./utils/SignalsHarness.sol";

import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";

import {IV4Router} from "v4-periphery/src/interfaces/IV4Router.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";

import {DesiredCurrency} from "../src/BondHook.sol";

/**
 * Selling locked bonds into a Uniswap V4 pool
 *
 * - [x] Alice has 100k GOV
 * - [x] Deployer provides 100k USDC/GOV to the pool
 * - [x] Deployer provides 100k DAI/GOV to the pool
 * - [x] Alice locks 50k against an initiative for 1 year
 * - [ ] Variations:
 *      - [ ] Price selling the bond into the pool at t0 (immediately)
 *      - [ ] Price selling the bond into the pool at t3 (3/12)
 *      - [ ] Price selling the bond into the pool at t6 (6/12)
 * - [ ] Quote searchers to buy immature bonds from the Pool, LPs should get fees
 * - [ ] Quote searchers to redeem bonds
 */
contract SecondaryMarketTest is Test, Deployers, SignalsHarness {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;
    // --- Contracts ---
    Signals signals;

    function setUp() public {
        deployFreshManagerAndRouters();

        // Deploy the Signals contract
        bool dealTokens = true;
        signals = deploySignals(dealTokens);

        deployHookWithLiquidity(signals);
    }

    function test_LiquidityDeployment() public view {

        printPoolInfo();

        uint256 govBalance = _token.balanceOf(address(this));
        uint256 usdcBalance = _usdc.balanceOf(address(this));
        uint256 daiBalance = _dai.balanceOf(address(this));

        // Log current balances
        console.log("GOV balance:", govBalance);
        console.log("USDC balance:", usdcBalance);
        console.log("DAI balance:", daiBalance);

        uint128 liquidityA = StateLibrary.getLiquidity(manager, _keyA.toId());
        console.log("GOV/USDC Liquidity:", liquidityA);

        uint128 liquidityB = StateLibrary.getLiquidity(manager, _keyB.toId());
        console.log("GOV/DAI Liquidity:", liquidityB);

        assertGt(liquidityA, 0);
        assertGt(liquidityB, 0);
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

    function test_NormalSwap() public {
        dealMockTokens();

        vm.startPrank(_alice);
        // _token.approve(address(swapRouter), 100_000 either);    
        _dai.approve(address(swapRouter), 100_000 ether);

        uint256 govBalanceBefore = _token.balanceOf(address(_alice));
        uint256 daiBalanceBefore = _dai.balanceOf(address(_alice));
               
        // Buy 1 gov token
        vm.startPrank(_alice);
        swapRouter.swap(
            _keyB,
            IPoolManager.SwapParams({zeroForOne: !_keyBIsGovZero, amountSpecified: 1 ether, sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE-1}),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            // hookData
            ZERO_BYTES
        );

        assertEq(_token.balanceOf(address(_alice)), govBalanceBefore + 1 ether);
        assertLt(_dai.balanceOf(address(_alice)), daiBalanceBefore);
    }

    function test_SwapNFT() public {
        dealMockTokens();

        // add liquidity to the pool
        vm.startPrank(_liquidityProvider);
        _token.approve(address(bondhook), type(uint256).max);
        _dai.approve(address(bondhook), type(uint256).max);

        bondhook.modifyLiquidity(
            _keyB,
            1_000_000 ether
        );
        vm.stopPrank();

        // Alice locks 50k against an initiative for 1 year
        uint256 tokenId = lockTokensAndIssueBond(signals, _alice, 50_000 ether, 365);
        // Jump ahead to when bond is worth 50%
        vm.warp(block.timestamp + 365 days / 2);
        
        // The minimum price we will accept for the bond.
        // 50% of 50k is 25k, minus the 10% fee is 22.5k
        uint256 desiredAmount = 22_500 ether;

        // record balances
        uint256 _aliceBondBefore = signals.balanceOf(address(_alice));
        uint256 _poolBondBefore = signals.balanceOf(address(bondhook));
        uint256 _govBefore = _token.balanceOf(address(_alice));
        uint256 _daiBefore = _dai.balanceOf(address(_alice));

        // approve and swap the bond into the pool
        vm.startPrank(_alice);
        signals.approve(address(bondhook), tokenId);
        bondhook.swapBond(
            _keyB,
            tokenId,
            desiredAmount, // The minimum she expects to receive before any swap
            DesiredCurrency.Mixed
        );
        vm.stopPrank();

        uint256 _govAfter = _token.balanceOf(address(_alice));
        uint256 _daiAfter = _dai.balanceOf(address(_alice));
        uint256 _bondAfter = signals.balanceOf(address(_alice));
        uint256 _poolBondAfter = signals.balanceOf(address(bondhook));

        // Alice should end up with 22.5k liquidity (11.25k gov, 11.25k dai)
        assertApproxEqAbs(_govAfter, _govBefore + (desiredAmount / 2), 1000, "Alice Gov balance incorrect");
        assertApproxEqAbs(_daiAfter, _daiBefore + (desiredAmount / 2), 1000, "Alice DAI balance incorrect");
        // The bond should be transfered to the pool
        assertEq(_bondAfter, 0, "Alice Bond balance incorrect");
        assertEq(_poolBondAfter, 1, "Pool Bond balance incorrect");
    }

    function test_SwapNFTSingleCurrency() public {
        dealMockTokens();

        // add liquidity to the pool
        vm.startPrank(_liquidityProvider);
        _token.approve(address(bondhook), type(uint256).max);
        _dai.approve(address(bondhook), type(uint256).max);

        bondhook.modifyLiquidity(
            _keyB,
            1_000_000 ether
        );
        vm.stopPrank();

        // Alice locks 50k against an initiative for 1 year
        uint256 tokenId = lockTokensAndIssueBond(signals, _alice, 50_000 ether, 365);
        // Jump ahead to when bond is worth 50%
        vm.warp(block.timestamp + 365 days / 2);
        
        // The minimum price we will accept for the bond.
        // 50% of 50k is 25k, minus the 10% fee is 22.5k
        uint256 desiredAmount = 22_500 ether;

        // record balances
        uint256 _aliceBondBefore = signals.balanceOf(address(_alice));
        uint256 _poolBondBefore = signals.balanceOf(address(bondhook));
        uint256 _govBefore = _token.balanceOf(address(_alice));
        uint256 _daiBefore = _dai.balanceOf(address(_alice));

        // approve and swap the bond into the pool, requesting only gov tokens in return
        vm.startPrank(_alice);
        signals.approve(address(bondhook), tokenId);
        bondhook.swapBond(
            _keyB,
            tokenId,
            desiredAmount, // The minimum she expects to receive before any swap
            _keyBIsGovZero ? DesiredCurrency.Currency0 : DesiredCurrency.Currency1
        );
        vm.stopPrank();

        uint256 _govAfter = _token.balanceOf(address(_alice));
        uint256 _daiAfter = _dai.balanceOf(address(_alice));
        uint256 _aliceBondAfter = signals.balanceOf(address(_alice));
        uint256 _poolBondAfter = signals.balanceOf(address(bondhook));

        //Alice should end up with around 22.5k in currency 0, minus the 3% trading fee
        assertApproxEqAbs(_govAfter, _govBefore + desiredAmount, _govAfter * 3 / 100, "Alice Gov balance incorrect");
        assertEq(_daiAfter, _daiBefore, "Alice DAI balance incorrect");
        // The bond should be transfered to the pool
        assertEq(_aliceBondAfter, 0, "Alice Bond balance incorrect");
        assertEq(_poolBondAfter, 1, "Pool Bond balance incorrect");
    }

    // TOOD: [ ] Sell bond for USDC (exact input swap) single-hop pool [BOND -> UNI -> USDC]
    // TOOD: [ ] Sell bond for USDT (exact input swap) multi-hop pool (UNI/USDC, UNI/USDT) [BOND -> UNI -> USDC -> USDT]
}
