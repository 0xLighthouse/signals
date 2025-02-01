// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.26;

import 'forge-std/Test.sol';
import 'forge-std/mocks/MockERC20.sol';
import 'forge-std/console.sol';

import '@v4-core/PoolManager.sol';
import '@v4-core/interfaces/IPoolManager.sol';
import '@v4-core/libraries/TickMath.sol';

import {Currency} from '@v4-core/types/Currency.sol';
import {PoolKey} from '@v4-core/types/PoolKey.sol';

import {Signals} from '../Signals.sol';
import {BondAMM} from '../BondAMM.sol';

import '@v4-periphery/libraries/LiquidityAmounts.sol';

import {HookMiner} from './utils/HookMiner.sol';

/**
 * Selling locked bonds into a Uniswap V4 pool
 *
 * TODO:
 * - [ ] Alice has 100k SGT
 * - [ ] Bob provides 1MM SGT/USDC to the pool
 * - [ ] Alice locks 50k against an initiative for 1 year
 * - [ ] Variations:
 *      - [ ] Price selling the bond into the pool at t0 (immediately)
 *      - [ ] Price selling the bond into the pool at t3 (3/12)
 *      - [ ] Sell the bond into the pool at t6 (6/12)
 * - [ ] Quote searchers to buy immature bonds from the Pool, LPs should get fees
 * - [ ] Quote searchers to redeem bonds
 */
contract BondAMMHookTest is Test {
  Signals _signalsContract;
  BondAMM _bondAmm;

  // TODO: Explore if this was a Governor; if so, we should be testing with a Governor contract
  MockERC20 _someGovToken;

  address _deployer;
  address _alice;
  address _bob;
  address _charlie;

  // --- Signals Config ---
  uint256 constant _PROPOSAL_THRESHOLD = 50_000 * 1e18; // 50k
  uint256 constant _ACCEPTANCE_THRESHOLD = 100_000 * 1e18; // 100k
  uint256 constant _LOCK_DURATION_CAP = 365 days; // 1 year
  uint256 constant _PROPOSAL_CAP = 100; // 100 proposals
  uint256 constant _LOCK_INTERVAL = 1 days; // 1 day
  uint256 constant _DECAY_CURVE_TYPE = 0; // Linear

  // --- Pool Config ---
  IPoolManager public poolManager;
  PoolKey public poolKey;

  address public usdc;
  address public govToken;

  address public hook;
  address public pool;

  uint24 public constant FEE = 3000; // 0.3% fee

  function setUp() public {
    _deployer = address(this);
    _alice = address(0x1111);
    _bob = address(0x2222);
    _charlie = address(0x3333);

    // Deploy the mock ERC20 token
    _someGovToken = new MockERC20();
    _someGovToken.initialize('SomeGovToken', 'SGT', 18);

    // Deploy the Signals contract
    _signalsContract = new Signals();

    uint256[] memory _decayCurveParameters = new uint256[](1);
    _decayCurveParameters[0] = 9e17;

    // Initialize the Signals contract
    _signalsContract.initialize(
      _deployer,
      address(_someGovToken),
      _PROPOSAL_THRESHOLD,
      _ACCEPTANCE_THRESHOLD,
      _LOCK_DURATION_CAP,
      _PROPOSAL_CAP,
      _LOCK_INTERVAL,
      _DECAY_CURVE_TYPE,
      _decayCurveParameters
    );

    // Mint tokens to participants
    // Distribute tokens to test addresses
    deal(address(_someGovToken), _alice, _PROPOSAL_THRESHOLD); // Alice has 50k
    deal(address(_someGovToken), _bob, _PROPOSAL_THRESHOLD * 2); // Bob has 100k
    deal(address(_someGovToken), _charlie, _PROPOSAL_THRESHOLD / 2); // Charlie has 25k

    // Deploy mock tokens (if needed)
    usdc = address(new MockERC20());
    govToken = address(_someGovToken);

    // Deploy the PoolManager
    poolManager = new PoolManager(address(this));

    // Define the hook's permissions
    Hooks.Permissions memory permissions = Hooks.Permissions({
      beforeInitialize: false,
      afterInitialize: false,
      beforeAddLiquidity: false,
      afterAddLiquidity: false,
      beforeRemoveLiquidity: false,
      afterRemoveLiquidity: false,
      beforeSwap: true,
      afterSwap: false,
      beforeDonate: false,
      afterDonate: false,
      beforeSwapReturnDelta: false,
      afterSwapReturnDelta: false,
      afterAddLiquidityReturnDelta: false,
      afterRemoveLiquidityReturnDelta: false
    });

    // Deploy hook with correct flags
    bytes memory hookBytecode = type(BondAMM).creationCode;
    bytes memory constructorArgs = abi.encode(poolManager, address(_signalsContract));
    hook = HookMiner.deploy(hookBytecode, constructorArgs, permissions);

    // Create the pool with proper PoolKey struct
    poolKey = PoolKey({
      currency0: Currency.wrap(govToken),
      currency1: Currency.wrap(usdc),
      fee: FEE,
      tickSpacing: 60, // Must match hook requirements
      hooks: IHooks(hook)
    });

    // Set price to 1:1, sqrt(1.0) * 2^96
    uint160 sqrtPriceX96 = 79228162514264337593543950336;

    // Initialize pool and get the pool ID
    poolManager.initialize(poolKey, sqrtPriceX96);

    // Approve tokens for pool operations
    MockERC20(govToken).approve(address(poolManager), type(uint256).max);
    MockERC20(usdc).approve(address(poolManager), type(uint256).max);
  }

  function test_InitialState() public view {
    assertEq(_signalsContract.owner(), address(_deployer));
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
  //   uint256 amountUSDC = 1_000_000 * 1e6; // 1M USDC (6 decimals)

  //   // Mint USDC to test contract
  //   deal(usdc, address(this), amountUSDC);

  //   // Approve PoolManager to use USDC
  //   IERC20(usdc).approve(address(poolManager), amountUSDC);

  //     // Calculate liquidity amount based on the amount of USDC
  //   uint160 sqrtPriceX96 = uint160(poolManager.getSlot0(poolKey).sqrtPriceX96);

  //   // Use a more focused price range instead of full range
  //   int24 lowerTick = -60; // Approximately -0.5% from current price
  //   int24 upperTick = 60;  // Approximately +0.5% from current price

  //   uint128 liquidity = LiquidityAmounts.getLiquidityForAmount1(
  //       TickMath.getSqrtRatioAtTick(lowerTick),
  //       TickMath.getSqrtRatioAtTick(upperTick),
  //       amountUSDC
  //   );

  //   // Add liquidity with calculated amount
  //   poolManager.addLiquidity(
  //       IPoolManager.ModifyLiquidityParams({
  //           poolKey: poolKey,
  //           liquidityDelta: int128(liquidity),
  //           tickLower: lowerTick,
  //           tickUpper: upperTick
  //       })
  //   );

  //   // Assert liquidity is added
  //   (uint128 positionLiquidity, , ) = poolManager.getPosition(pool, address(this), lowerTick, upperTick);
  //   assertGt(positionLiquidity, 0, 'Liquidity should be added');
  //   assertEq(positionLiquidity, liquidity, 'Liquidity amount mismatch');
  // }
}
