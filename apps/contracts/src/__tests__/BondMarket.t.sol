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
contract BondMarketTest is Test, Deployers {
  using CurrencyLibrary for Currency;

  // --- Contracts ---
  Signals _signalsContract;
  BondHook public bondhook;

  // --- Signals Config ---
  uint256 constant _PROPOSAL_THRESHOLD = 50_000 * 1e18; // 50k
  uint256 constant _ACCEPTANCE_THRESHOLD = 100_000 * 1e18; // 100k
  uint256 constant _LOCK_DURATION_CAP = 365 days; // 1 year
  uint256 constant _PROPOSAL_CAP = 100; // 100 proposals
  uint256 constant _LOCK_INTERVAL = 1 days; // 1 day
  uint256 constant _DECAY_CURVE_TYPE = 0; // Linear

  // --- Tokens ---
  MockERC20 _someGovToken;
  MockERC20 _usdc;

  Currency ethCurrency = Currency.wrap(address(0));
  Currency usdcCurrency;
  Currency govTokenCurrency;

  // --- Pool Config ---
  uint24 public constant POOL_FEE = 3000; // 0.3% fee

  function setUp() public {
    // Deploy Uniswap V4 PoolManager and Router contracts
    // Note: Providers [manager] and [swapRouter] to scope
    deployFreshManagerAndRouters();

    // Deploy the mocked ERC20 token
    _someGovToken = new MockERC20('Some Gov Token', 'GOV', 18);
    govTokenCurrency = Currency.wrap(address(_someGovToken));

    // Deploy the mock USDC token
    _usdc = new MockERC20('USDC', 'USDC', 6);
    usdcCurrency = Currency.wrap(address(_usdc));

    /**
     * Deploy a Signals board
     * TODO: Wrap in a utility lib
     */
    _signalsContract = new Signals();
    uint256[] memory _decayCurveParameters = new uint256[](1);
    _decayCurveParameters[0] = 9e17;

    _signalsContract.initialize(
      ISignals.SignalsConfig({
        owner: address(this),
        underlyingToken: address(_someGovToken),
        proposalThreshold: _PROPOSAL_THRESHOLD,
        acceptanceThreshold: _ACCEPTANCE_THRESHOLD,
        maxLockIntervals: _LOCK_DURATION_CAP,
        proposalCap: _PROPOSAL_CAP,
        lockInterval: _LOCK_INTERVAL,
        decayCurveType: _DECAY_CURVE_TYPE,
        decayCurveParameters: _decayCurveParameters
      })
    );

    // Approve our TOKEN for spending on the swap router and modify liquidity router
    // NOTE: These variables are exported from the `Deployers` contract
    _someGovToken.approve(address(swapRouter), type(uint256).max);
    _someGovToken.approve(address(modifyLiquidityRouter), type(uint256).max);

    _usdc.approve(address(swapRouter), type(uint256).max);
    _usdc.approve(address(modifyLiquidityRouter), type(uint256).max);

    // Deploy hook with correct flags
    uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG);
    console.log('HookAddress: %s', address(flags));

    deployCodeTo(
      'BondHook.sol',
      // Note: [manager] exposed from the Deployers contract
      abi.encode(manager, address(_signalsContract)),
      address(flags)
    );
    bondhook = BondHook(address(flags));

    // Initialize the pool with the correct parameters
    // Note: writes [key] to the [Deployers] contract
    (key, ) = initPool(
      ethCurrency, // Currency 0 = USDC
      govTokenCurrency, // Currency 1 = GOV
      bondhook, // Hook Contract
      POOL_FEE, // Swap Fees, 0.3%
      SQRT_PRICE_1_1 // Initial Sqrt(P) value = 1
    );
  }

  function test_InitialState() public view {
    assertEq(_signalsContract.owner(), address(this));
    assertEq(_signalsContract.token(), address(_someGovToken));
    assertEq(_signalsContract.proposalThreshold(), _PROPOSAL_THRESHOLD);
    assertEq(_signalsContract.acceptanceThreshold(), _ACCEPTANCE_THRESHOLD);
    assertEq(_signalsContract.maxLockIntervals(), _LOCK_DURATION_CAP);
    assertEq(_signalsContract.proposalCap(), _PROPOSAL_CAP);
    assertEq(_signalsContract.lockInterval(), _LOCK_INTERVAL);
    assertEq(_signalsContract.decayCurveType(), _DECAY_CURVE_TYPE);
    assertEq(_signalsContract.totalInitiatives(), 0);
  }

  // FIXME: This should be moved into a utility function
  function test_AddSingleSidedLiquidity() public {
    // Mind eth to self
    vm.deal(address(this), 100 ether);
    // Mint a bunch of GOV to ourselves
    _someGovToken.mint(address(this), 1000 ether);

    // Set user address in hook data
    bytes memory hookData = abi.encode(address(this));

    uint160 sqrtPriceAtTickLower = TickMath.getSqrtPriceAtTick(-60);
    uint160 sqrtPriceAtTickUpper = TickMath.getSqrtPriceAtTick(60);

    console.log('sqrtPriceAtTickLower: %s', sqrtPriceAtTickLower);
    console.log('sqrtPriceAtTickUpper: %s', sqrtPriceAtTickUpper);

    uint256 ethToAdd = 0.1 ether;
    uint128 liquidityDelta = LiquidityAmounts.getLiquidityForAmount0(
      sqrtPriceAtTickLower,
      SQRT_PRICE_1_1,
      ethToAdd
    );
    uint256 tokenToAdd = LiquidityAmounts.getAmount1ForLiquidity(
      sqrtPriceAtTickLower,
      SQRT_PRICE_1_1,
      liquidityDelta
    );

    console.log('liquidityDelta: %s', liquidityDelta);
    console.log('tokenToAdd: %s', tokenToAdd);

    // Add liquidity
    modifyLiquidityRouter.modifyLiquidity{value: ethToAdd}(
      key,
      IPoolManager.ModifyLiquidityParams({
        tickLower: -60,
        tickUpper: 60,
        liquidityDelta: int256(uint256(liquidityDelta)),
        salt: bytes32(0)
      }),
      hookData
    );
  }
}
