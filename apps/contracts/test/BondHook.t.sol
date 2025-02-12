// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/console.sol';

import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {Signals} from '../src/Signals.sol';
import {BondHook} from '../src/BondHook.sol';
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {SignalsHarness} from './utils/SignalsHarness.sol';

import {SortTokens} from "@uniswap/v4-core/test/utils/SortTokens.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PipsLib} from '../src/PipsLib.sol';
import {ExampleSimplePricing} from '../src/pricing/ExampleSimplePricing.sol';
import {IBondPricing} from '../src/interfaces/IBondPricing.sol';

contract BondHookTest is Test, Deployers, SignalsHarness {
  using PipsLib for uint256;
    MockERC20 bondToken;
    Signals signals;
    IBondPricing bondPricing;
    BondHook hook;

  function setUp() public {

    // Deploy PoolManager and Router contracts
    deployFreshManagerAndRouters();

    bondToken = new MockERC20("Bond Token", "BOND", 18);
    signals = deploySignals(true);

    bondPricing = new ExampleSimplePricing(uint256(100).percentToPips(), uint256(100).percentToPips());
    
    uint160 flags = uint160(
            Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG// | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG
        );
    deployCodeTo(
        "BondHook.sol",
        abi.encode(manager, bondToken, signals, bondPricing),
        address(flags)
    );

    hook = BondHook(address(flags));
  }

  function testBeforeInitialize() public {
    MockERC20 tokenA = new MockERC20("Token A", "A", 18);

    (currency0, currency1) = SortTokens.sort(tokenA, bondToken);
    
    // Creating this pool should work
    initPool(
        currency0,
        currency1,
        hook,
        3000,
        SQRT_PRICE_1_1
    );
  }

  function testBeforeInitializeWithNonBondToken() public {
    // Create two irrelevant tokens
    MockERC20 tokenA = new MockERC20("Token A", "A", 18);
    MockERC20 tokenB = new MockERC20("Token B", "B", 18);
    
    (currency0, currency1) = SortTokens.sort(tokenA, tokenB);
    
    // Creating this pool should revert
    vm.expectRevert();
    initPool(
        currency0,
        currency1,
        hook,
        3000,
        SQRT_PRICE_1_1
    );
  }
}
