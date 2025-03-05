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
import {BondHook} from "../../src/BondHook.sol";

import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";

import {IV4Router} from "v4-periphery/src/interfaces/IV4Router.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";

import {DesiredCurrency} from "../../src/BondHook.sol";

/**
 * Ensure our helper liquidity is deployed correctly
 */
contract ModifyLiquidityTest is Test, Deployers, SignalsHarness {
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

    function test_addLiquidity() public {

        MockERC20 _currency0 = MockERC20(Currency.unwrap(_keyB.currency0));
        MockERC20 _currency1 = MockERC20(Currency.unwrap(_keyB.currency1));

        deal(address(_currency0), address(this), 100 ether);
        deal(address(_currency1), address(this), 100 ether);

        _currency0.approve(address(bondhook), type(uint256).max);
        _currency1.approve(address(bondhook), type(uint256).max);

        // Add liquidity to pool
        bondhook.modifyLiquidity(_keyB, 10 ether);

        // Check that the liquidity was added
        uint128 liquidity = StateLibrary.getLiquidity(manager, _keyB.toId());
        assertEq(liquidity, 10 ether, "Incorrect amount of liquidity added");

        // Check that the balance of the user is 10 ether
        assertEq(bondhook.balanceOf(_keyB.toId(), address(this)), 10 ether, "Incorrect user balance");

        // Check that the total liquidity is 10 ether
        assertEq(bondhook.totalLiquidity(_keyB.toId()), 10 ether, "Incorrect total liquidity reported by hook");
    }

    function test_Revert_addLiquidityInvalidPool() public {

        // Add liquidity to unknown pool
        vm.expectRevert(BondHook.PoolNotInitialized.selector);
        bondhook.modifyLiquidity(PoolKey({
            currency0: Currency.wrap(address(234)),
            currency1: Currency.wrap(address(345)),
            fee: 3000,
            tickSpacing: 100,
            hooks: bondhook
        }), 10 ether);
    }
}
