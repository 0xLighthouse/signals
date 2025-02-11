// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import {Signals} from '../../src/Signals.sol';
import {SignalsFactory} from '../../src/SignalsFactory.sol';
import {ISignals} from '../../src/interfaces/ISignals.sol';
import {MockERC20} from 'solmate/src/test/utils/mocks/MockERC20.sol';
import {MockStable} from '../../test/mocks/MockStable.m.sol';
import {TokenRegistry} from '../../src/TokenRegistry.sol';
import {Currency, CurrencyLibrary} from 'v4-core/types/Currency.sol';
import {Hooks} from 'v4-core/libraries/Hooks.sol';
import {BondHook} from '../../src/BondHook.sol';
import {Deployers} from '@uniswap/v4-core/test/utils/Deployers.sol';
import {SortTokens} from '@uniswap/v4-core/test/utils/SortTokens.sol';
import {Constants} from '@uniswap/v4-core/test/utils/Constants.sol';
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
  Currency tokenCurrency;
  Currency usdcCurrency;
  Currency daiCurrency;

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

  function _uniswapApprovals(MockERC20 token) internal returns (Currency currency) {
    address[9] memory toApprove = [
      address(swapRouter),
      address(swapRouterNoChecks),
      address(modifyLiquidityRouter),
      address(modifyLiquidityNoChecks),
      address(donateRouter),
      address(takeRouter),
      address(claimsRouter),
      address(nestedActionRouter.executor()),
      address(actionsRouter)
    ];

    for (uint256 i = 0; i < toApprove.length; i++) {
      token.approve(toApprove[i], Constants.MAX_UINT256);
    }
    return Currency.wrap(address(token));
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

  function deployHookWithLiquidity(Signals _signals) public {
    // Set up uniswap approvals
    usdcCurrency = _uniswapApprovals(_usdc);
    tokenCurrency = _uniswapApprovals(_token);
    daiCurrency = _uniswapApprovals(_dai);

    console.log('USDC address: %s', Currency.unwrap(usdcCurrency));
    console.log('GOV address: %s', Currency.unwrap(tokenCurrency));
    console.log('DAI address: %s', Currency.unwrap(daiCurrency));

    // Deal tokens to deployer
    deal(address(_token), _deployer, 1_000_000 * 1e18);
    deal(address(_usdc), _deployer, 1_000_000 * 1e6);
    deal(address(_dai), _deployer, 1_000_000 * 1e18);

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
    Currency currencyA,
    Currency currencyB
  ) public returns (PoolKey memory _key) {
    Currency _currency0;
    Currency _currency1;
    (_currency0, _currency1) = SortTokens.sort(
      MockERC20(Currency.unwrap(currencyA)),
      MockERC20(Currency.unwrap(currencyB))
    );

    // print current decimals
    console.log('currency0 decimals: %s', MockERC20(Currency.unwrap(_currency0)).decimals());
    console.log('currency0 address: %s', Currency.unwrap(_currency0));
    console.log('currency1 decimals: %s', MockERC20(Currency.unwrap(_currency1)).decimals());
    console.log('currency1 address: %s', Currency.unwrap(_currency1));

    (_key, ) = initPool(_currency0, _currency1, bondhook, POOL_FEE, SQRT_PRICE_1_1);

    // Adjust liquidity amounts based on token decimals
    uint256 amount0 = MockERC20(Currency.unwrap(_currency0)).decimals() == 6
      ? 100_000 * 1e6 // USDC amount (6 decimals)
      : 100_000 ether; // GOV amount (18 decimals)
    uint256 amount1 = MockERC20(Currency.unwrap(_currency1)).decimals() == 6
      ? 100_000 * 1e6 // USDC amount (6 decimals)
      : 100_000 ether; // GOV amount (18 decimals)

    seedMoreLiquidity(_key, amount0, amount1);

    return _key;
  }

  function lockTokensAndIssueBond(
    Signals _signals,
    address _user,
    uint256 _amount,
    uint256 _duration
  ) public returns (uint256 tokenId) {
    vm.startPrank(_user);
    _token.approve(address(_signals), _amount);
    (tokenId) = _signals.proposeInitiativeWithLock(
      'Some Initiative',
      'Some Description',
      _amount,
      _duration
    );
    vm.stopPrank();
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
}
