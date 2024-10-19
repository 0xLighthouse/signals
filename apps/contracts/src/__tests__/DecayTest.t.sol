// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/mocks/MockERC20.sol';

import {Signals} from '../Signals.sol';
import {DecayCurves} from '../DecayCurves.sol';

contract DecayTest is Test {
  Signals _signalsContract;

  MockERC20 _token;

  address _deployer;
  address _alice;
  address _bob;

  uint256 constant _PROPOSAL_THRESHOLD = 50_000 * 1e18; // 50k
  uint256 constant _ACCEPTANCE_THRESHOLD = 100_000 * 1e18; // 100k
  uint256 constant _LOCK_DURATION_CAP = 365 days; // 1 year
  uint256 constant _PROPOSAL_CAP = 100; // 100 proposals
  uint256 constant _LOCK_INTERVAL = 1 days; // 1 day
  uint256 constant _DECAY_CURVE_TYPE = 0; // Linear

  uint256[] _decayCurveParameters = new uint256[](1);

  function setUp() public {
    _deployer = address(this);
    _alice = address(0x1111);

    // Deploy the mock ERC20 token
    _token = new MockERC20();

    // Deploy the Signals contract
    _signalsContract = new Signals();

    _decayCurveParameters[0] = 1e18;

    // Initialize the Signals contract
    _signalsContract.initialize(
      _deployer,
      address(_token),
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
    deal(address(_token), _alice, _PROPOSAL_THRESHOLD); // Alice has 50k
  }

  /// @notice Test the linear decay curve
  function testLinearDecayCurve() public pure {
    uint256 lockDuration = 20;
    uint256 lockAmount = 50_000 * 1e18;
    uint256 currentInterval = 3;
    uint256[] memory curveParameters = new uint256[](1);

    // A parameter value of 11e17 is the equivalent of 1.1 in base 1e18.
    curveParameters[0] = 11e17;
    // The starting weight will be 50k * 20 = 1M
    // After 3 intervals, the weight should reduce by 3 / 20. Multiple by parameter means 3.3 / 20.
    // 1M - (3.3 / 20 * 1M) = 165_000
    assertEq(
      DecayCurves.linear(lockDuration, lockAmount, currentInterval, curveParameters),
      835_000 * 1e18
    );
  }

  /// @notice Test the exponential decay curve
  function testExponentialDecayCurve() public pure {
    uint256 lockDuration = 20;
    uint256 lockAmount = 50_000 * 1e18;
    uint256 currentInterval = 3;
    uint256[] memory curveParameters = new uint256[](1);

    // A parameter value of 9e17 is the equivalent of 0.9 in base 1e18.
    curveParameters[0] = 9e17;
    // The starting weight will be 50k * 20 = 1M
    // After 3 intervals, the weight should be 1M * 0.9^3 = 729_000
    assertEq(
      DecayCurves.exponential(lockDuration, lockAmount, currentInterval, curveParameters),
      729_000 * 1e18
    );
  }

  /// @notice Passing 0 for interval must always return the starting weight
  function testDecayIntervalZero() public pure {
    uint256 lockDuration = 20;
    uint256 lockAmount = 50_000 * 1e18;
    uint256[] memory curveParameters = new uint256[](1);
    curveParameters[0] = 9e17;

    assertEq(
      DecayCurves.linear(lockDuration, lockAmount, 0, curveParameters),
      lockAmount * lockDuration
    );
    assertEq(
      DecayCurves.exponential(lockDuration, lockAmount, 0, curveParameters),
      lockAmount * lockDuration
    );
  }
}
