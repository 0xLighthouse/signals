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

import {ISignals} from '../interfaces/ISignals.sol';
import {SignalsHarness} from './utils/SignalsHarness.sol';

import 'forge-std/console.sol';

import {IV4Router} from 'v4-periphery/src/interfaces/IV4Router.sol';
import {PoolSwapTest} from 'v4-core/test/PoolSwapTest.sol';

/**
 * Selling locked bonds into a Uniswap V4 pool
 *
 * TODO:
 * - [ ] Alice has 100k GOV
 * - [ ] Bob provides 1k USDC/GOV to the pool
 * - [ ] Bob provides 1k USDT/GOV to the pool
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

  function setUp() public {
    // Deploy Uniswap V4 PoolManager and Router contracts
    // Note: Providers [manager] and [swapRouter] to scope
    deployFreshManagerAndRouters();

    // Deploy the Signals contract
    bool dealTokens = true;
    signals = deploySignals(dealTokens);

    deployHooksAndLiquidity(signals);
  }

  function test_liquidity() public {
    // Get token balances of the deployer
    uint256 govBalance = _token.balanceOf(address(this));
    uint256 usdcBalance = _usdc.balanceOf(address(this));
    uint256 daiBalance = _dai.balanceOf(address(this));

    // Log current balances
    console.log('GOV balance:', govBalance);
    console.log('USDC balance:', usdcBalance);
    console.log('DAI balance:', daiBalance);
    // Get liquidity positions from the pool
    // (uint160 sqrtPriceX96, int24 tick, , , , , ) = manager.getSlot0(_keyA);
    // console.log('Current pool price (sqrt):', sqrtPriceX96);
    // console.log('Current tick:', tick);

    // // Get position info for specific tick range
    // bytes32 positionId = keccak256(
    //   abi.encode(
    //     address(this), // owner
    //     -60, // tickLower
    //     60 // tickUpper
    //   )
    // );

    // (uint128 liquidity, , , , ) = manager.getPosition(_keyA, address(this), -60, 60);
    // console.log('Liquidity in position:', liquidity);

    // // Assert expected values
    // assertGt(liquidity, 0, 'No liquidity found in position');
    // assertGt(govBalance, 0, 'No GOV balance');
    // assertGt(usdcBalance, 0, 'No USDC balance');
    // assertGt(daiBalance, 0, 'No DAI balance');
  }

  function test_AddSingleSidedLiquidity() public {
    // Mint tokens to self
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
  //   // TODO: What is the current price?
  }

  // lib/v4-periphery/src/interfaces/IV4Router.sol

  /**
   * [ ] Sell bond for UNI (exact output swap) single-hop pool [BOND -> UNI]
   * <https://8640p.slack.com/archives/C089L09UCFR/p1739202925580799>
   */
  function test_SellBondForExactOutput() public {
    // TODO: Sell bond into the pool

    uint256 tokenId = 1;
    uint256 amount = 1000;
    bytes memory hookData = abi.encode(tokenId, amount);

    swapRouter.swap(
      key,
      IPoolManager.SwapParams({zeroForOne: true, amountSpecified: 1000, sqrtPriceLimitX96: 0}),
      PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
      hookData
    );
  }

  // TOOD: [ ] Sell bond for USDC (exact input swap) single-hop pool [BOND -> UNI -> USDC]
  // TOOD: [ ] Sell bond for USDT (exact input swap) multi-hop pool (UNI/USDC, UNI/USDT) [BOND -> UNI -> USDC -> USDT]
}
