// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/console.sol';

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
import {Signals} from '../src/Signals.sol';

import {ISignals} from '../src/interfaces/ISignals.sol';
import {SignalsHarness} from './utils/SignalsHarness.sol';

import {IV4Router} from 'v4-periphery/src/interfaces/IV4Router.sol';
import {PoolSwapTest} from 'v4-core/test/PoolSwapTest.sol';

/**
 * Selling locked bonds into a Uniswap V4 pool
 *
 * TODO:
 * - [x] Alice has 100k GOV
 * - [x] Deployer provides 100k USDC/GOV to the pool
 * - [x] Deployer provides 100k DAI/GOV to the pool
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
    deployFreshManagerAndRouters();

    // Deploy the Signals contract
    bool dealTokens = true;
    signals = deploySignals(dealTokens);

    deployHooksAndLiquidity(signals);
  }

  /**
   * TODO: Ensure liquidity is deployed as expected
   */
  function test_LiquidityDeployed() public view {
    uint256 govBalance = _token.balanceOf(address(this));
    uint256 usdcBalance = _usdc.balanceOf(address(this));
    uint256 daiBalance = _dai.balanceOf(address(this));

    // Log current balances
    console.log('GOV balance:', govBalance);
    console.log('USDC balance:', usdcBalance);
    console.log('DAI balance:', daiBalance);
  }

  /**
   * [ ] Sell bond for UNI (exact output swap) single-hop pool [BOND -> UNI]
   * <https://8640p.slack.com/archives/C089L09UCFR/p1739202925580799>
   */
  function test_SellBondForExactOutput() public {
    // TODO: Sell bond into the pool

    // Alice locks 50k against an initiative for 1 year
    uint256 tokenId = lockTokensAndIssueBond(signals, _alice, 50000, 12);

    console.log('Token ID:', tokenId);

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

  // TOOD: [ ] Sell bond for USDC (exact input swap) single-hop pool [BOND -> UNI -> USDC]
  // TOOD: [ ] Sell bond for USDT (exact input swap) multi-hop pool (UNI/USDC, UNI/USDT) [BOND -> UNI -> USDC -> USDT]
}
