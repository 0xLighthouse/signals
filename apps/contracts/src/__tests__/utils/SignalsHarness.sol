// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import {Signals} from '../../Signals.sol';
import {SignalsFactory} from '../../SignalsFactory.sol';
import {ISignals} from '../../interfaces/ISignals.sol';
import {MockERC20} from 'solmate/src/test/utils/mocks/MockERC20.sol';
import {MockStable} from '../../__mocks__/MockStable.m.sol';
import {TokenRegistry} from '../../TokenRegistry.sol';

contract SignalsHarness is Test {
  address _deployer = address(this);
  address _alice = address(0x1111);
  address _bob = address(0x2222);
  address _charlie = address(0x3333);

  MockERC20 internal _token = new MockERC20('SomeGovToken', 'GOV', 18);

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
