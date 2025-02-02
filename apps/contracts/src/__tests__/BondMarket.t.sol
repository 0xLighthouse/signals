// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";

import {PoolManager} from "v4-core/PoolManager.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";

import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {SqrtPriceMath} from "v4-core/libraries/SqrtPriceMath.sol";

import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

import {StateLibrary} from 'v4-core/libraries/StateLibrary.sol';
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {Signals} from '../Signals.sol';
import {BondHook} from '../BondHook.sol';

import 'forge-std/console.sol';

/**
 * Selling locked bonds into a Uniswap V4 pool
 *
 * TODO:
 * - [ ] Alice has 100k GOV
 * - [ ] Bob provides 1MM GOV/USDC to the pool
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
      address(this),
      address(_someGovToken),
      _PROPOSAL_THRESHOLD,
      _ACCEPTANCE_THRESHOLD,
      _LOCK_DURATION_CAP,
      _PROPOSAL_CAP,
      _LOCK_INTERVAL,
      _DECAY_CURVE_TYPE,
      _decayCurveParameters
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

  // function test_AddSingleSidedLiquidity() public {
  //   vm.startPrank(address(this));
  //   uint256 amountUSDC = 1_000_000 * 1e6; // 1M USDC (6 decimals)

  //   // Mint USDC to test contract
  //   deal(usdc, address(this), amountUSDC);

  //   // Approve PoolManager to use USDC
  //   IERC20(usdc).approve(address(poolManager), amountUSDC);

  //   // Define full-range liquidity parameters
  //   int24 lowerTick = TickMath.MIN_TICK;
  //   int24 upperTick = TickMath.MAX_TICK;

  //   // Add single-sided USDC liquidity at full range
  //   IPoolManager.ModifyLiquidityParams memory params = IPoolManager.ModifyLiquidityParams({
  //     tickLower: lowerTick,
  //     tickUpper: upperTick,
  //     liquidityDelta: int128(int256(amountUSDC)),
  //     salt: bytes32(0)
  //   });

  //   // Call unlock with the params
  //   poolManager.unlock(abi.encode(poolKey, params));

  //   // Assert liquidity is added
  //   // (uint128 liquidity, , , ) = poolManager.getLiquidity(poolKey, address(_charlie), lowerTick, upperTick);
  //   // assertGt(liquidity, 0, 'Liquidity should be added');
  // }
}
