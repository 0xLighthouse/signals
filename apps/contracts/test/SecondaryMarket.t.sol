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
import {ISignals} from "../src/interfaces/ISignals.sol";
import {SignalsHarness} from "./utils/SignalsHarness.sol";

import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";

import {IV4Router} from "v4-periphery/src/interfaces/IV4Router.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";

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

    // function test_NormalSwap() public {
    //     // 1. Create GOV token
    //     Currency gov = deployAndMintToken("GOV", 6, 100_000_000);
    //     // 2. Create USDC token
    //     Currency usdc = deployAndMintToken("USDC", 6, 100_000_000);
    //     // 3. Create pool for GOV/USDC + hook + liquidity

    //     // print balances
    //     console.log("gov balance:", gov.balanceOf(address(this)));
    //     console.log("usdc balance:", usdc.balanceOf(address(this)));

    //     (PoolKey memory key, Currency currency0, Currency currency1)     = _deployPoolWithHookAndLiquidity(gov, usdc);
    //     // 4. Give USDC to alice
    //     usdc.transfer(address(_alice), 100_000 * 1e6);
    //     vm.startPrank(_alice);
    //     // 5. Alice approves transfers
    //     MockERC20(Currency.unwrap(usdc)).approve(address(swapRouter), type(uint256).max);
    //     // 6. Alice swaps USDC for GOV
    //     // We want to give USDC, so zeroForOne is true if USDC is currency0
    //     bool zfo = currency0 == usdc;

    //     swapRouter.swap(
    //         key,
    //         IPoolManager.SwapParams({
    //             zeroForOne: zfo,
    //             amountSpecified: 1 * 1e6,
    //             // sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
    //             sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1
    //             }),
    //         PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
    //         ""
    //     );
    //     // 6. Check balances
    //     console.log("gov balance:", gov.balanceOf(address(_alice)));
    //     console.log("usdc balance:", usdc.balanceOf(address(_alice)));
    //     // assertEq(gov.balanceOf(address(_alice)), 100_000);
    //     // assertEq(usdc.balanceOf(address(_alice)), 0);
    // }

    function test_SellBond() public {
        // 1. Create GOV token
        // 2. Create USDC token
        // 3. Create pool for GOV/USDC + hook
        // 4. Give Signal NFT to alice
        // 5. Give liquidity to pool
        // 6. Alice swaps NFT for USDC
        // 7. Check balances
    }

    /**
     * TODO: Ensure liquidity is deployed as expected
     */
    function test_LiquidityDeployment() public view {
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

    /**
     * FIXME: This is not complete yet
     */
    function test_SwapExactSingleOutput() public {
        // Alice locks 50k against an initiative for 1 year
        uint256 bondA = lockTokensAndIssueBond(signals, _alice, 50_000, 12);
        console.log("Token ID:", bondA);

        deal(address(_dai), address(_alice), 100_000 ether);

        vm.startPrank(_alice);
        _token.approve(address(swapRouter), 50_000);    
        _dai.approve(address(swapRouter), 100_000_000 ether);

        console.log("gov balance before:", _token.balanceOf(address(_alice))); 
        console.log("dai balance before:", _dai.balanceOf(address(_alice)));

        uint256 govBalanceBefore = _token.balanceOf(address(_alice));
        uint256 daiBalanceBefore = _dai.balanceOf(address(_alice));

        // Ensure the bond is locked
        uint256 tokenId = 1;
        uint256 amount = 1000;
        bytes memory hookData = abi.encode(tokenId, amount);

        
        // Buy 1 gov token
        vm.startPrank(_alice);
        swapRouter.swap(
            _keyB,
            IPoolManager.SwapParams({zeroForOne: !_keyBIsGovZero, amountSpecified: 1 ether, sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE-1}),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            // hookData
            ZERO_BYTES
        );

        console.log("gov balance after:", _token.balanceOf(address(_alice))); 
        console.log("dai balance after:", _dai.balanceOf(address(_alice)));
        assertEq(_token.balanceOf(address(_alice)), govBalanceBefore + 1 ether);
        assertLt(_dai.balanceOf(address(_alice)), daiBalanceBefore);
    }

    // TOOD: [ ] Sell bond for USDC (exact input swap) single-hop pool [BOND -> UNI -> USDC]
    // TOOD: [ ] Sell bond for USDT (exact input swap) multi-hop pool (UNI/USDC, UNI/USDT) [BOND -> UNI -> USDC -> USDT]
}
