// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {Signals} from "../src/Signals.sol";
import {BondHook} from "../src/BondHook.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {SignalsHarness} from "./utils/SignalsHarness.sol";
import {SortTokens} from "@uniswap/v4-core/test/utils/SortTokens.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";

import {BalanceDelta, BalanceDeltaLibrary} from "v4-core/types/BalanceDelta.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";

import {PipsLib} from "../src/PipsLib.sol";
import {ExampleLinearPricing} from "../src/pricing/ExampleLinearPricing.sol";
import {IBondPricing} from "../src/interfaces/IBondPricing.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";

contract BondHookTest is Test, Deployers, SignalsHarness {
    using PipsLib for uint256;

    MockERC20 bondToken;
    Signals signals;
    IBondPricing bondPricing;
    BondHook hook;

    function setUp() public {
        deployFreshManagerAndRouters();

        // Deploy the Signals contract
        bool dealTokens = true;
        signals = deploySignals(dealTokens);

        deployHookWithLiquidity(signals);
    }

    // Test that a pool can be created when the underlying token is part of the pair
    function test_initializePool() public {
        MockERC20 pairToken = new MockERC20("Example token", "EXAMPLE", 18);

        (currency0, currency1) = SortTokens.sort(pairToken, MockERC20(signals.underlyingToken()));

        // Creating this pool should work
        initPool(currency0, currency1, hook, 3000, SQRT_PRICE_1_1);
    }

    // Test that a pool is rejected if the underlying token is not part of the pair
    function test_Revert_initializePoolWithoutBondToken() public {
        MockERC20 tokenA = new MockERC20("Example token", "EXAMPLE", 18);
        MockERC20 tokenB = new MockERC20("Another example token", "EXAMPL", 18);

        (currency0, currency1) = SortTokens.sort(tokenA, tokenB);

        // Creating this pool should revert
        vm.expectRevert();
        initPool(currency0, currency1, hook, 3000, SQRT_PRICE_1_1);
    }

    function test_addLiquidity() public {
        MockERC20 pairToken = new MockERC20("Example token", "EXAMPLE", 18);
        MockERC20 underlyingToken = MockERC20(signals.underlyingToken());
        (currency0, currency1) = SortTokens.sort(pairToken, underlyingToken);
        // fee zero
        (PoolKey memory poolKey,) = initPool(currency0, currency1, hook, 3000, SQRT_PRICE_1_1);

        deal(address(pairToken), address(this), 100 ether);
        deal(address(underlyingToken), address(this), 100 ether);

        pairToken.approve(address(hook), type(uint256).max);
        underlyingToken.approve(address(hook), type(uint256).max);

        // Add liquidity to pool
        hook.modifyLiquidity(poolKey, 1 ether);

        // Check that the liquidity was added
        uint128 liquidity = StateLibrary.getLiquidity(manager, poolKey.toId());
        assertEq(liquidity, 1 ether, "Incorrect amount of liquidity added");

        // Check that the balance of the user is 1 ether
        assertEq(hook.balanceOf(poolKey.toId(), address(this)), 1 ether, "Incorrect user balance");

        // Check that the total liquidity is 1 ether
        assertEq(hook.totalLiquidity(poolKey.toId()), 1 ether, "Incorrect total liquidity reported by hook");
    }

    // A non-hook swap should work fine
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
            IPoolManager.SwapParams({
                zeroForOne: !_keyBIsGovZero,
                amountSpecified: 1 ether,
                sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1
            }),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            // hookData
            ZERO_BYTES
        );

        assertEq(_token.balanceOf(address(_alice)), govBalanceBefore + 1 ether);
        assertLt(_dai.balanceOf(address(_alice)), daiBalanceBefore);
    }
}
