// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BaseHook} from 'v4-periphery/base/hooks/BaseHook.sol';
import {ERC20} from 'solmate/src/tokens/ERC20.sol';

import {CurrencyLibrary, Currency} from 'v4-core/types/Currency.sol';
import {PoolKey} from 'v4-core/types/PoolKey.sol';
import {BalanceDeltaLibrary, BalanceDelta} from 'v4-core/types/BalanceDelta.sol';
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from 'v4-core/types/BeforeSwapDelta.sol';


import {Hooks} from 'v4-core/libraries/Hooks.sol';
// import {BaseHook} from 'v4-periphery/base/hooks/BaseHook.sol';
// import {PoolId, PoolIdLibrary} from 'v4-core/types/PoolId.sol';
// import {TickMath} from 'v4-core/libraries/TickMath.sol';
import {StateLibrary} from 'v4-core/libraries/StateLibrary.sol';

// --- This is the correct import for the IPoolManager interface...
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";

import {Signals} from './Signals.sol';
import {ISignals} from './interfaces/ISignals.sol';

import 'forge-std/console.sol';

/**
 * - LPs provide need to provide single sided liquidity to a pool
 * - Bonds can be sold into the pool
 *    - revert when not enough liquidity is provided
 * - Bonds can be purchased from the pool
 * - Bonds can be redeemed for the underlying asset into the pool
 *    - revert when bond is not mature
 */
contract BondAMM is BaseHook {
  using BeforeSwapDeltaLibrary for BeforeSwapDelta;
  // using PoolIdLibrary for PoolKey;
  using StateLibrary for IPoolManager;

  Signals public immutable signals;

  // Add events
  event Buyer(bytes32 indexed poolId, address indexed liquidityProvider);
  event BondRedeemed(uint256 indexed tokenId, address indexed owner);

  constructor(IPoolManager _poolManager, address _signals) BaseHook(_poolManager) {
    signals = Signals(_signals);
    // poolManager = IPoolManager(_poolManager);
  }

  function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
    return
      Hooks.Permissions({
        beforeInitialize: false,
        afterInitialize: false,
        beforeAddLiquidity: false,
        afterAddLiquidity: false,
        beforeRemoveLiquidity: false,
        afterRemoveLiquidity: false,
        beforeSwap: false,
        afterSwap: false,
        beforeDonate: false,
        afterDonate: false,
        beforeSwapReturnDelta: false,
        afterSwapReturnDelta: false,
        afterAddLiquidityReturnDelta: false,
        afterRemoveLiquidityReturnDelta: false
      });
  }


  function _handleBondSwap(
    address user,
    PoolKey calldata key,
    IPoolManager.SwapParams calldata params,
    bytes calldata data
  ) internal {
    uint256 tokenId = abi.decode(data, (uint256));
    require(signals.ownerOf(tokenId) == user, 'BondHook: Not bond owner');

    ISignals.LockInfo memory metadata = signals.getTokenMetadata(tokenId);
    console.log('lockDuration', metadata.lockDuration);

    // TODO: Get current price and apply discount
    // --- Get the bare minimum params required to calculate the bond.
    uint256 currentPrice = _getUnderlyingPrice(Currency.unwrap(key.currency0));
    uint256 currentDiscount = 10;
    // uint256 currentDiscount = signals.getCurrentDiscount(tokenId);
    uint256 discountedPrice = (currentPrice * (10000 - currentDiscount)) / 10000;

    // FIXME: (TO STUDY) Enforce price impact based on bond terms
    if (params.zeroForOne) {
      require(
        params.sqrtPriceLimitX96 <= _priceToSqrtX96(discountedPrice),
        'BondHook: Price exceeds bond discount'
      );
    } else {
      require(
        params.sqrtPriceLimitX96 >= _priceToSqrtX96(discountedPrice),
        'BondHook: Price exceeds bond discount'
      );
    }
  }

  // Lazy implementation
  function _priceToSqrtX96(uint256 price) internal pure returns (uint160) {
    return uint160(_sqrt((price << 192) / 1e18));
  }

  // Lazy implementation
  function _sqrt(uint256 x) internal pure returns (uint256 y) {
    uint256 z = (x + 1) / 2;
    y = x;
    while (z < y) {
      y = z;
      z = (x / z + z) / 2;
    }
  }

  // Lazy implementation
  function _getUnderlyingPrice(address asset) internal view returns (uint256) {
    // Implement oracle price feed
    return 1e18;
  }

  // function _priceBond(address asset) internal view returns (uint256) {
  //   // Implement oracle price feed
  //   return 1e18;
  // }
}
