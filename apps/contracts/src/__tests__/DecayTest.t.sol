// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/mocks/MockERC20.sol';

import {Signals} from '../Signals.sol';

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

    // Initialize the Signals contract
    signalsContract.initialize(
      deployer,
      address(token),
      PROPOSAL_THRESHOLD,
      ACCEPTANCE_THRESHOLD,
      LOCK_DURATION_CAP,
      PROPOSAL_CAP,
      LOCK_INTERVAL,
      DECAY_CURVE_TYPE
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
}
