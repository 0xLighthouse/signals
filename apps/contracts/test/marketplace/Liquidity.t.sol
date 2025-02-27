// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {SignalsHarness} from "../../test/utils/SignalsHarness.sol";

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
 * Ensure our helper liquidity is deployed correctly
 */
contract UserSellBondTest is Test, Deployers, SignalsHarness {
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

    function test_helperLiquidityDeployment() public view {
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
}
