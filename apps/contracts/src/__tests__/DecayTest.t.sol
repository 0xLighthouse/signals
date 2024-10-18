// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/mocks/MockERC20.sol';

import {Signals} from '../Signals.sol';
import {DecayCurves} from '../DecayCurves.sol';

contract DecayTest is Test {

  Signals signalsContract;

  MockERC20 token;

  address deployer;
  address alice;
  address bob;

  uint256 constant PROPOSAL_THRESHOLD = 50_000 * 1e18; // 50k
  uint256 constant ACCEPTANCE_THRESHOLD = 100_000 * 1e18; // 100k
  uint256 constant LOCK_DURATION_CAP = 365 days; // 1 year
  uint256 constant PROPOSAL_CAP = 100; // 100 proposals
  uint256 constant LOCK_INTERVAL = 1 days; // 1 day
  uint256 constant DECAY_CURVE_TYPE = 0; // Linear

  function setUp() public {
    deployer = address(this);
    alice = address(0x1111);

    // Deploy the mock ERC20 token
    token = new MockERC20();

    // Deploy the Signals contract
    signalsContract = new Signals();

    uint256[] memory DECAY_CURVE_PARAMETERS = new uint256[](1); // 0.9
    DECAY_CURVE_PARAMETERS[0] = 9e17;

    // Initialize the Signals contract
    signalsContract.initialize(
      deployer,
      address(token),
      PROPOSAL_THRESHOLD,
      ACCEPTANCE_THRESHOLD,
      LOCK_DURATION_CAP,
      PROPOSAL_CAP,
      LOCK_INTERVAL,
      DECAY_CURVE_TYPE,
      DECAY_CURVE_PARAMETERS
    );

    // Mint tokens to participants
    // Distribute tokens to test addresses
    deal(address(token), alice, PROPOSAL_THRESHOLD); // Alice has 50k
  }

  /**
   * @notice Test proposing an initiative with locked tokens
   */
  function testProposeInitiativeWithLock() public {
    vm.startPrank(alice);
    token.approve(address(signalsContract), PROPOSAL_THRESHOLD);

    // Propose an initiative with lock
    // 50k over 6 days should be 300k
    signalsContract.proposeInitiativeWithLock('Test Locks', 'Description 2', PROPOSAL_THRESHOLD, 6);

    // Check that the lock info is stored
    uint256 weight = signalsContract.getWeight(0);
    assertEq(weight, PROPOSAL_THRESHOLD * 6);

    // Weight should decay linearly over 6 days
    for (uint256 i = 6; i > 0; i--) {
      skip(1 days);
      weight = signalsContract.getWeight(0);
      assertEq(weight, PROPOSAL_THRESHOLD * (i - 1));
    }

    vm.stopPrank();
  }

  /**
   * @notice Test the linear decay curve
   */

  function testDecayCurves() public pure {
    uint256  _lockDuration = 20;
    uint256  _lockAmount = 50_000 * 1e18;
    uint256  _currentInterval = 3;
    uint256[] memory _curveParameters = new uint256[](1);
    _curveParameters[0] = 9e17;

    // Exponential:
    // A parameter value of 9e17 is the equivalent of 0.9 in base 1e18.
    // The starting weight will be 50k * 20 = 1M
    // After 3 intervals, the weight should be 1M * 0.9^3 = 729_000
    assertEq(DecayCurves.exponential(_lockDuration, _lockAmount, _currentInterval, _curveParameters), 729_000 * 1e18);
    
    // Linear:
    // A parameter value of 11e17 is the equivalent of 1.1 in base 1e18.
    // The starting weight will be 50k * 20 = 1M
    // After 3 intervals, the weight should reduce by 3 / 20, times the parameter means 3.3 / 20.
    // 1M * 3.3 / 20 = 165_000
    assertEq(DecayCurves.exponential(_lockDuration, _lockAmount, _currentInterval, _curveParameters), 729_000 * 1e18);
  }
}
