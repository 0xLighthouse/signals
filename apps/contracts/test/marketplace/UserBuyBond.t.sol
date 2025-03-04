// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {SignalsHarness} from "../../test/utils/SignalsHarness.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";

import {PoolManager} from "v4-core/PoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

import {Signals} from "../../src/Signals.sol";
import {ISignals} from "../../src/interfaces/ISignals.sol";

import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";

import {IV4Router} from "v4-periphery/src/interfaces/IV4Router.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";

import {DesiredCurrency} from "../../src/BondHook.sol";

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
contract UserBuyBondTest is Test, Deployers, SignalsHarness {
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
        dealMockTokens();
        addLiquidity(_keyB);
    }

    function test_UserBuysBond() public {
        // Alice locks 50k against an initiative for 1 year
        uint256 tokenId = lockTokensAndIssueBond(signals, _alice, 50_000 ether, 365);
        // Jump ahead to when bond is worth 50%
        vm.warp(block.timestamp + 365 days / 2);

        // record pool balances
        uint256 _poolLiquidity = StateLibrary.getLiquidity(manager, _keyB.toId());
        
        // approve and swap the bond into the pool
        vm.startPrank(_alice);
        signals.approve(address(bondhook), tokenId);
        bondhook.swapBond({
            key: _keyB,
            tokenId: tokenId,
            bondPriceLimit: 0,
            swapPriceLimit: 0,
            desiredCurrency: DesiredCurrency.Mixed
        });
        vm.stopPrank();

        // The maximum price we would pay for the bond.
        // 50% of 50k is 25k, plus the 10% fee is 27.5k
        uint256 bondPriceLimit = 27_500 ether;

        vm.startPrank(_bob);
        _token.approve(address(bondhook), type(uint256).max);
        _dai.approve(address(bondhook), type(uint256).max);

        bondhook.swapBond({
            key: _keyB,
            tokenId: tokenId,
            bondPriceLimit: bondPriceLimit,
            swapPriceLimit: 0,
            desiredCurrency: DesiredCurrency.Mixed
        });
        vm.stopPrank();

        // record pool balances
        uint256 _poolLiquidityAfter = StateLibrary.getLiquidity(manager, _keyB.toId());
       
        // The pool should have earned profit in the form of liquidity:
        // Bought for 22_500, sold for 27_500 = 5_000 equals 2_500 liquidity as profit
        assertApproxEqAbs(_poolLiquidityAfter - _poolLiquidity, 2_500 ether, 100, "Pool liquidity should have increased");
    }

    function test_UserBuysBondSingleCurrency() public {
          // Alice locks 50k against an initiative for 1 year
        uint256 tokenId = lockTokensAndIssueBond(signals, _alice, 50_000 ether, 365);
        // Jump ahead to when bond is worth 50%
        vm.warp(block.timestamp + 365 days / 2);

        // record pool balances
        uint256 _poolLiquidity = StateLibrary.getLiquidity(manager, _keyB.toId());
        
        // approve and swap the bond into the pool
        vm.startPrank(_alice);
        signals.approve(address(bondhook), tokenId);
        bondhook.swapBond({
            key: _keyB,
            tokenId: tokenId,
            bondPriceLimit: 0,
            swapPriceLimit: 0,
            desiredCurrency: DesiredCurrency.Mixed
        });
        vm.stopPrank();

        // The maximum price we would pay for the bond.
        // 50% of 50k is 25k, plus the 10% fee is 27.5k
        uint256 bondPriceLimit = 27_500 ether;

        uint256 _daiBalanceBefore = _dai.balanceOf(address(_bob));
        uint256 _tokenBalanceBefore = _token.balanceOf(address(_bob));

        vm.startPrank(_bob);
        _token.approve(address(bondhook), type(uint256).max);
        _dai.approve(address(bondhook), type(uint256).max);

        // Purchase bond with DAI
        bondhook.swapBond({
            key: _keyB,
            tokenId: tokenId,
            bondPriceLimit: bondPriceLimit,
            swapPriceLimit: _keyBIsGovZero ? TickMath.MAX_SQRT_PRICE - 1 : TickMath.MIN_SQRT_PRICE + 1,
            desiredCurrency: _keyBIsGovZero ? DesiredCurrency.Currency1 : DesiredCurrency.Currency0
        });
        vm.stopPrank();

        // record pool balances
        uint256 _poolLiquidityAfter = StateLibrary.getLiquidity(manager, _keyB.toId());
        uint256 _daiBalanceAfter = _dai.balanceOf(address(_bob));
        uint256 _tokenBalanceAfter = _token.balanceOf(address(_bob));
       
        // The pool should have earned profit in the form of liquidity:
        // Bought for 22_500, sold for 27_500 = 5_000 equals 2_500 liquidity as profit
        assertApproxEqAbs(_poolLiquidityAfter - _poolLiquidity, 2_500 ether, 100, "Pool liquidity should have increased");

        assertApproxEqAbs(_daiBalanceBefore - _daiBalanceAfter, 27_500 ether, 27_500 ether / 100, "Bob should have spent DAI (and some fees)");
        assertEq(_tokenBalanceAfter, _tokenBalanceBefore, "Bob should have no change of GOV");
    }
}
