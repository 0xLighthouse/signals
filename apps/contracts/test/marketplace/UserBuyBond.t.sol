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
    }

    // function test_UserBuysBond() public {
    //     dealMockTokens();

    //     // add liquidity to the pool
    //     vm.startPrank(_liquidityProvider);
    //     _token.approve(address(bondhook), type(uint256).max);
    //     _dai.approve(address(bondhook), type(uint256).max);

    //     bondhook.modifyLiquidity(_keyB, 1_000_000 ether);
    //     vm.stopPrank();

    //     // Alice locks 50k against an initiative for 1 year
    //     uint256 tokenId = lockTokensAndIssueBond(signals, _alice, 50_000 ether, 365);
    //     // Jump ahead to when bond is worth 50%
    //     vm.warp(block.timestamp + 365 days / 2);

    //     // The minimum price we will accept for the bond.
    //     // 50% of 50k is 25k, minus the 10% fee is 22.5k
    //     uint256 desiredAmount = 22_500 ether;

    //     // record balances
    //     uint256 _aliceBondBefore = signals.balanceOf(address(_alice));
    //     uint256 _poolBondBefore = signals.balanceOf(address(bondhook));
    //     uint256 _govBefore = _token.balanceOf(address(_alice));
    //     uint256 _daiBefore = _dai.balanceOf(address(_alice));

    //     // approve and swap the bond into the pool
    //     vm.startPrank(_alice);
    //     signals.approve(address(bondhook), tokenId);
    //     bondhook.swapBond(
    //         _keyB,
    //         tokenId,
    //         desiredAmount, // The minimum she expects to receive before any swap
    //         DesiredCurrency.Mixed
    //     );
    //     vm.stopPrank();

    //     uint256 _govAfter = _token.balanceOf(address(_alice));
    //     uint256 _daiAfter = _dai.balanceOf(address(_alice));
    //     uint256 _bondAfter = signals.balanceOf(address(_alice));
    //     uint256 _poolBondAfter = signals.balanceOf(address(bondhook));

    //     // Alice should end up with 22.5k liquidity (11.25k gov, 11.25k dai)
    //     assertApproxEqAbs(_govAfter, _govBefore + (desiredAmount / 2), 1000, "Alice Gov balance incorrect");
    //     assertApproxEqAbs(_daiAfter, _daiBefore + (desiredAmount / 2), 1000, "Alice DAI balance incorrect");
    //     // The bond should be transfered to the pool
    //     assertEq(_bondAfter, 0, "Alice Bond balance incorrect");
    //     assertEq(_poolBondAfter, 1, "Pool Bond balance incorrect");
    // }

    // function test_UserSellsBondSingleCurrency() public {
    //     dealMockTokens();

    //     // add liquidity to the pool
    //     vm.startPrank(_liquidityProvider);
    //     _token.approve(address(bondhook), type(uint256).max);
    //     _dai.approve(address(bondhook), type(uint256).max);

    //     bondhook.modifyLiquidity(_keyB, 1_000_000 ether);
    //     vm.stopPrank();

    //     // Alice locks 50k against an initiative for 1 year
    //     uint256 tokenId = lockTokensAndIssueBond(signals, _alice, 50_000 ether, 365);
    //     // Jump ahead to when bond is worth 50%
    //     vm.warp(block.timestamp + 365 days / 2);

    //     // The minimum price we will accept for the bond.
    //     // 50% of 50k is 25k, minus the 10% fee is 22.5k
    //     uint256 desiredAmount = 22_500 ether;

    //     // record balances
    //     uint256 _aliceBondBefore = signals.balanceOf(address(_alice));
    //     uint256 _poolBondBefore = signals.balanceOf(address(bondhook));
    //     uint256 _govBefore = _token.balanceOf(address(_alice));
    //     uint256 _daiBefore = _dai.balanceOf(address(_alice));

    //     // approve and swap the bond into the pool, requesting only gov tokens in return
    //     vm.startPrank(_alice);
    //     signals.approve(address(bondhook), tokenId);
    //     bondhook.swapBond(
    //         _keyB,
    //         tokenId,
    //         desiredAmount, // The minimum she expects to receive before any swap
    //         _keyBIsGovZero ? DesiredCurrency.Currency0 : DesiredCurrency.Currency1
    //     );
    //     vm.stopPrank();

    //     uint256 _govAfter = _token.balanceOf(address(_alice));
    //     uint256 _daiAfter = _dai.balanceOf(address(_alice));
    //     uint256 _aliceBondAfter = signals.balanceOf(address(_alice));
    //     uint256 _poolBondAfter = signals.balanceOf(address(bondhook));

    //     //Alice should end up with around 22.5k in currency 0, minus the 3% trading fee
    //     assertApproxEqAbs(_govAfter, _govBefore + desiredAmount, _govAfter * 3 / 100, "Alice Gov balance incorrect");
    //     assertEq(_daiAfter, _daiBefore, "Alice DAI balance incorrect");
    //     // The bond should be transfered to the pool
    //     assertEq(_aliceBondAfter, 0, "Alice Bond balance incorrect");
    //     assertEq(_poolBondAfter, 1, "Pool Bond balance incorrect");
    // }
}
