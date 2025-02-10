// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import {Deployers} from '@uniswap/v4-core/test/utils/Deployers.sol';
import {LiquidityAmounts} from '@uniswap/v4-core/test/utils/LiquidityAmounts.sol';

import {PoolManager} from 'v4-core/PoolManager.sol';
import {IPoolManager} from 'v4-core/interfaces/IPoolManager.sol';
import {Currency, CurrencyLibrary} from 'v4-core/types/Currency.sol';

import {Hooks} from 'v4-core/libraries/Hooks.sol';
import {TickMath} from 'v4-core/libraries/TickMath.sol';
import {SqrtPriceMath} from 'v4-core/libraries/SqrtPriceMath.sol';

import {MockERC20} from 'solmate/src/test/utils/mocks/MockERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {StateLibrary} from 'v4-core/libraries/StateLibrary.sol';
import {Hooks} from 'v4-core/libraries/Hooks.sol';
import {Signals} from '../Signals.sol';
import {BondHook} from '../BondHook.sol';
import {ISignals} from '../interfaces/ISignals.sol';
import {SignalsHarness} from './utils/SignalsHarness.sol';

import 'forge-std/console.sol';

/**
 * Selling locked bonds into a Uniswap V4 pool
 *
 * TODO:
 * - [ ] Alice has 100k GOV
 * - [ ] Bob provides 1k ETH/GOV to the pool
 * - [ ] Alice locks 50k against an initiative for 1 year
 * - [ ] Variations:
 *      - [ ] Price selling the bond into the pool at t0 (immediately)
 *      - [ ] Price selling the bond into the pool at t3 (3/12)
 *      - [ ] Price selling the bond into the pool at t6 (6/12)
 * - [ ] Quote searchers to buy immature bonds from the Pool, LPs should get fees
 * - [ ] Quote searchers to redeem bonds
 */
contract SecondaryMarketTest is Test, Deployers, SignalsHarness {
  using CurrencyLibrary for Currency;

  // --- Contracts ---
  Signals signals;
  BondHook public bondhook;

  // --- Tokens ---
  MockERC20 _usdc;

  // tokens expressed as Currency
  Currency usdcCurrency;
  Currency tokenCurrency;

  // --- Pool Config ---
  uint24 public constant POOL_FEE = 3000; // 0.3% fee

  function setUp() public {
    // Deploy Uniswap V4 PoolManager and Router contracts
    // Note: Providers [manager] and [swapRouter] to scope
    deployFreshManagerAndRouters();

    // Deploy the Signals contract
    bool dealTokens = true;
    signals = deploySignals(dealTokens);

    // Deploy a governance token
    tokenCurrency = Currency.wrap(address(_token));

    // Deploy some stablecoin
    _usdc = new MockERC20('USDC', 'USDC', 6);
    usdcCurrency = Currency.wrap(address(_usdc));

    // Approve our TOKEN for spending on the swap router and modify liquidity router
    // NOTE: These variables are exported from the `Deployers` contract
    _token.approve(address(swapRouter), type(uint256).max);
    _token.approve(address(modifyLiquidityRouter), type(uint256).max);

    _usdc.approve(address(swapRouter), type(uint256).max);
    _usdc.approve(address(modifyLiquidityRouter), type(uint256).max);

    // Deploy hook with correct flags
    uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG);
    console.log('HookAddress: %s', address(flags));

    deployCodeTo(
      'BondHook.sol',
      // Note: [manager] exposed from the Deployers contract
      abi.encode(manager, address(signals)),
      address(flags)
    );
    bondhook = BondHook(address(flags));

    sortTokens(address(_usdc), address(_token));

    // Initialize the pool with the correct parameters
    // Note: writes [key] to the [Deployers] contract
    (key, ) = initPool(
      usdcCurrency, // Currency0 = USDC
      tokenCurrency, // Currency1 = GOV
      bondhook, // Hook Contract
      POOL_FEE, // Swap Fees, 0.3%
      SQRT_PRICE_1_1 // Initial Sqrt(P) value = 1
    );
  }

  function test_AddSingleSidedLiquidity() public {
    // Mind tokens to self
    _token.mint(address(_deployer), 1_000_000 * 1e18);
    _usdc.mint(address(_deployer), 1_000_000 * 1e6);

    // Set user address in hook data
    bytes memory hookData = abi.encode(address(this));

    uint160 sqrtPriceAtTickLower = TickMath.getSqrtPriceAtTick(-60);
    uint160 sqrtPriceAtTickUpper = TickMath.getSqrtPriceAtTick(60);

    console.log('sqrtPriceAtTickLower: %s', sqrtPriceAtTickLower);
    console.log('sqrtPriceAtTickUpper: %s', sqrtPriceAtTickUpper);

    uint256 usdcToAdd = 1_000_000 * 1e6;

    uint128 liquidityDelta = LiquidityAmounts.getLiquidityForAmount0(
      sqrtPriceAtTickLower,
      SQRT_PRICE_1_1,
      usdcToAdd
    );
    uint256 tokenToAdd = LiquidityAmounts.getAmount1ForLiquidity(
      sqrtPriceAtTickLower,
      SQRT_PRICE_1_1,
      liquidityDelta
    );

    console.log('liquidityDelta: %s', liquidityDelta);
    console.log('tokenToAdd: %s', tokenToAdd);

    // Add liquidity
    modifyLiquidityRouter.modifyLiquidity{value: usdcToAdd}(
      key,
      IPoolManager.ModifyLiquidityParams({
        tickLower: -60,
        tickUpper: 60,
        liquidityDelta: int256(uint256(liquidityDelta)),
        salt: bytes32(0)
      }),
      hookData
    );

    // TODO: What is the current price?
  }

  // lib/v4-periphery/src/interfaces/IV4Router.sol

  /**
   * [ ] Sell bond for UNI (exact output swap) single-hop pool [BOND -> UNI]
   * [ ] Sell bond for USDC (exact input swap) single-hop pool [BOND -> UNI -> USDC]
   * [ ] Sell bond for USDT (exact input swap) multi-hop pool (UNI/USDC, UNI/USDT) [BOND -> UNI -> USDC -> USDT]
   */
  function test_SellBondForExactOutput() public {
    IV4Router.ExactOutputSingleParams({
        poolKey: key,
        zeroForOne: true,
        amountOut: 1000,
        amountInMaximum: 1000,
        hookData: bytes("")
    })
    // TODO: Sell bond into the pool
  }
}
