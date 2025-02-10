// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import {Signals} from '../../Signals.sol';
import {SignalsFactory} from '../../SignalsFactory.sol';
import {ISignals} from '../../interfaces/ISignals.sol';
import {MockERC20} from 'solmate/src/test/utils/mocks/MockERC20.sol';
import {MockStable} from '../../__mocks__/MockStable.m.sol';
import {TokenRegistry} from '../../TokenRegistry.sol';
import {Currency, CurrencyLibrary} from 'v4-core/types/Currency.sol';
import {Hooks} from 'v4-core/libraries/Hooks.sol';
import {BondHook} from '../../BondHook.sol';
import {Deployers} from '@uniswap/v4-core/test/utils/Deployers.sol';
import {PoolKey} from 'v4-core/types/PoolKey.sol';
import {IPoolManager} from 'v4-core/interfaces/IPoolManager.sol';

contract SignalsHarness is Test, Deployers {
  address _deployer = address(this);
  address _alice = address(0x1111);
  address _bob = address(0x2222);
  address _charlie = address(0x3333);

  // --- Tokens ---
  MockERC20 internal _token = new MockERC20('SomeGovToken', 'GOV', 18);
  MockERC20 internal _usdc = new MockERC20('USDC', 'USDC', 6);
  MockERC20 internal _dai = new MockERC20('DAI', 'DAI', 18);

  // tokens expressed as Currency
  Currency usdcCurrency = Currency.wrap(address(_usdc));
  Currency tokenCurrency = Currency.wrap(address(_token));
  Currency daiCurrency = Currency.wrap(address(_dai));

  BondHook public bondhook;

  // --- Pool Config ---
  uint24 public constant POOL_FEE = 3000; // 0.3% fee

  PoolKey _keyA; // USDC/GOV
  PoolKey _keyB; // DAI/GOV

  ISignals.SignalsConfig public defaultConfig =
    ISignals.SignalsConfig({
      owner: _deployer,
      underlyingToken: address(_token),
      proposalThreshold: 50_000 * 1e18, // 50k
      acceptanceThreshold: 100_000 * 1e18, // 100k
      maxLockIntervals: 365 days, // 1 year
      proposalCap: 100, // 100 proposals
      lockInterval: 1 days, // 1 day
      decayCurveType: 0, // Linear
      decayCurveParameters: new uint256[](1)
    });

  function deploySignals(bool _dealTokens) public returns (Signals) {
    Signals signals = new Signals();
    signals.initialize(defaultConfig);
    if (_dealTokens) {
      _dealDefaultTokens();
    }
    return signals;
  }

  function deploySignalsWithFactory(
    bool _dealTokens
  ) public returns (SignalsFactory factory, Signals signals) {
    factory = new SignalsFactory();
    signals = Signals(factory.create(defaultConfig));
    if (_dealTokens) {
      _dealDefaultTokens();
    }
  }

  function _dealDefaultTokens() public {
    // --- Issue governance tokens to participants ---
    // Alice has 50k
    deal(address(_token), _alice, defaultConfig.proposalThreshold);
    // Bob has 100k
    deal(address(_token), _bob, defaultConfig.acceptanceThreshold);
    // Charlie has 25k
    deal(address(_token), _charlie, defaultConfig.proposalThreshold / 2);
  }

  // TODO: Needs review
  function deployStables() public returns (MockERC20 _mToken, MockStable _mUSDC) {
    // Deploy MockERC20 token and mint 1 million tokens
    _mToken = new MockERC20('MockToken', 'MTK', 18);

    uint256 initialSupply = 1_000_000 * 1e18;
    deal(address(_mToken), _deployer, initialSupply);

    _mUSDC = new MockStable('MockUSDC', 'MUSDC');
    deal(address(_mUSDC), _deployer, initialSupply);

    // Distribute tokens to test addresses
    deal(address(_mToken), _alice, 200_000 * 1e18);
    deal(address(_mToken), _bob, 200_000 * 1e18);
    deal(address(_mToken), _charlie, 40_000 * 1e18);

    // Distribute some mocked USDC to the test addresses
    deal(address(_mUSDC), _alice, 200_000 * 1e6);
    deal(address(_mUSDC), _bob, 200_000 * 1e6);
    deal(address(_mUSDC), _charlie, 40_000 * 1e6);

    return (_mToken, _mUSDC);
  }

  function deployHooksAndLiquidity(Signals _signals) public {
    // Approve our TOKEN for spending on the swap router and modify liquidity router
    // NOTE: These variables are exported from the `Deployers` contract
    _token.approve(address(swapRouter), type(uint256).max);
    _token.approve(address(modifyLiquidityRouter), type(uint256).max);

    _usdc.approve(address(swapRouter), type(uint256).max);
    _usdc.approve(address(modifyLiquidityRouter), type(uint256).max);

    // Deploy hook with correct flags
    uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG);
    console.log('HookAddress: %s', address(flags));

    deployCodeTo('BondHook.sol', abi.encode(manager, address(_signals)), address(flags));
    bondhook = BondHook(address(flags));

    // Deploy the pools
    console.log('Deploying USDC/GOV pool....');
    _keyA = _deployPoolWithHook(usdcCurrency, tokenCurrency); // USDC/GOV
    console.log('Deploying DAI/GOV pool....');
    _keyB = _deployPoolWithHook(daiCurrency, tokenCurrency); // DAI/GOV
  }

  // Gotcha: currencies are sorted by address
  function _deployPoolWithHook(
    Currency currency0,
    Currency currency1
  ) public returns (PoolKey memory _key) {
    (_key, ) = initPool(
      currency0,
      currency1,
      bondhook, // Hook Contract
      POOL_FEE, // Swap Fees, 0.3%
      SQRT_PRICE_1_1 // Initial Sqrt(P) value = 1
    );

    console.log('Deployed pool...');
    console.log('Adding liquidity...');

    // Add some liquidity
    modifyLiquidityRouter.modifyLiquidity(
      _key,
      IPoolManager.ModifyLiquidityParams({
        tickLower: -60,
        tickUpper: 60,
        liquidityDelta: 100 ether,
        salt: bytes32(0)
      }),
      ZERO_BYTES
    );

    console.log('Liquidity added...');

    return _key;
  }

  function deployAllowedTokens()
    public
    returns (TokenRegistry registry, MockERC20 _mToken, MockStable _mUSDC)
  {
    // Create some tokens
    (_mToken, _mUSDC) = deployStables();
    address[] memory _tokens = new address[](2);
    _tokens[0] = address(_mToken);
    _tokens[1] = address(_mUSDC);

    // Configure the registry
    registry = _configureRegistry(_tokens);

    return (registry, _mToken, _mUSDC);
  }

  function _configureRegistry(address[] memory _tokens) public returns (TokenRegistry registry) {
    registry = new TokenRegistry();
    for (uint256 i = 0; i < _tokens.length; i++) {
      registry.allow(_tokens[i]);
    }
  }

  function sortTokens(
    address tokenA,
    address tokenB
  ) internal pure returns (address token0, address token1) {
    require(tokenA != tokenB, 'IDENTICAL_ADDRESSES');
    if (tokenA < tokenB) {
      token0 = tokenA;
      token1 = tokenB;
    } else {
      token0 = tokenB;
      token1 = tokenA;
    }
    console.log('--------------------------------');
    console.log('tokenA: %s', tokenA);
    console.log('tokenB: %s', tokenB);
    console.log('--------------------------------');
    console.log('token0: %s', token0);
    console.log('token1: %s', token1);
    console.log('--------------------------------');
    require(token0 != address(0), 'ZERO_ADDRESS');
  }
}
