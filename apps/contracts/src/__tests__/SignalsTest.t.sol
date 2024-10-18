// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/mocks/MockERC20.sol';

import {Signals} from '../Signals.sol';

/// @title SignalsTest
contract SignalsTest is Test {
  Signals signalsContract;
  MockERC20 token;
  address deployer;
  address alice;
  address bob;
  address charlie;

  uint256 constant PROPOSAL_THRESHOLD = 50_000 * 1e18; // 50k
  uint256 constant ACCEPTANCE_THRESHOLD = 100_000 * 1e18; // 100k
  uint256 constant LOCK_DURATION_CAP = 365 days; // 1 year
  uint256 constant PROPOSAL_CAP = 100; // 100 proposals
  uint256 constant LOCK_INTERVAL = 1 days; // 1 day
  uint256 constant DECAY_CURVE_TYPE = 0; // Linear

  function setUp() public {
    deployer = address(this);
    alice = address(0x1111);
    bob = address(0x2222);
    charlie = address(0x3333);

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
    deal(address(token), bob, PROPOSAL_THRESHOLD * 2); // Bob has 100k
    deal(address(token), charlie, PROPOSAL_THRESHOLD / 2); // Charlie has 25k
  }

  function testInitialState() public {
    assertEq(signalsContract.owner(), address(deployer));
    assertEq(signalsContract.token(), address(token));
    assertEq(signalsContract.proposalThreshold(), PROPOSAL_THRESHOLD);
    assertEq(signalsContract.acceptanceThreshold(), ACCEPTANCE_THRESHOLD);
    assertEq(signalsContract.maxLockIntervals(), LOCK_DURATION_CAP);
    assertEq(signalsContract.proposalCap(), PROPOSAL_CAP);
    assertEq(signalsContract.lockInterval(), LOCK_INTERVAL);
    assertEq(signalsContract.decayCurveType(), DECAY_CURVE_TYPE);
    assertEq(signalsContract.totalProposals(), 0);
  }

  /**
   * @notice Test revert when proposing an initiative with insufficient tokens
   */
  function testProposeInitiativeRevertsWithInsufficientTokens() public {
    vm.startPrank(charlie);
    vm.expectRevert(Signals.InsufficientTokens.selector);
    signalsContract.proposeInitiative('Should revert', 'Description 1');
    vm.stopPrank();
  }

  /**
   * @notice Test proposing an initiative without locking tokens
   */
  function testProposeInitiative() public {
    vm.startPrank(alice);
    token.approve(address(signalsContract), PROPOSAL_THRESHOLD);

    // Propose an initiative
    signalsContract.proposeInitiative('Initiative 1', 'Description 1');

    // Check that the initiative is stored correctly
    Signals.Initiative memory initiative = signalsContract.getInitiative(0);
    assertEq(initiative.title, 'Initiative 1');
    assertEq(initiative.body, 'Description 1');
    assertEq(uint(initiative.state), uint(Signals.InitiativeState.Proposed));
    assertEq(initiative.proposer, alice);
    vm.stopPrank();
  }

  /**
   * @notice Test proposing an initiative with locked tokens
   */
  function testProposeInitiativeWithLock() public {
    // Approve tokens
    vm.startPrank(bob);
    token.approve(address(signalsContract), PROPOSAL_THRESHOLD);

    // Propose an initiative with lock
    signalsContract.proposeInitiativeWithLock('Initiative 2', 'Description 2', 200 * 1e18, 6);

    // Check that the initiative is stored correctly
    Signals.Initiative memory initiative = signalsContract.getInitiative(0);
    assertEq(initiative.title, 'Initiative 2');
    assertEq(initiative.body, 'Description 2');
    assertEq(uint(initiative.state), uint(Signals.InitiativeState.Proposed));
    assertEq(initiative.proposer, bob);

    // Check that the lock info is stored
    (uint256 amount, uint256 duration, , bool withdrawn) = signalsContract.locks(0, bob);
    assertEq(amount, 200 * 1e18);
    assertEq(duration, 6);
    assertEq(withdrawn, false);

    vm.stopPrank();
  }

  /// Test supporting an initiative with locked tokens
  function testSupportInitiative() public {
    vm.startPrank(alice);

    // Propose an initiative
    token.approve(address(signalsContract), 100 * 1e18);
    signalsContract.proposeInitiative('Initiative 1', 'Description 1');

    vm.stopPrank();

    vm.startPrank(bob);

    // Approve tokens
    token.approve(address(signalsContract), 150 * 1e18);

    // Support the initiative
    signalsContract.supportInitiative(0, 150 * 1e18, 6);

    // Check that the lock info is stored
    (uint256 amount, uint256 duration, , bool withdrawn) = signalsContract.locks(0, bob);
    assertEq(amount, 150 * 1e18);
    assertEq(duration, 6);
    assertEq(withdrawn, false);

    vm.stopPrank();
  }

  /// Test accepting an initiative
  function testAcceptInitiative() public {
    vm.startPrank(alice);

    // Propose an initiative
    token.approve(address(signalsContract), 100 * 1e18);
    signalsContract.proposeInitiative('Initiative 1', 'Description 1');

    vm.stopPrank();

    vm.startPrank(deployer);

    // Accept the initiative
    signalsContract.acceptInitiative(0);

    // Check that the initiative state is updated
    Signals.Initiative memory initiative = signalsContract.getInitiative(0);
    assertEq(uint(initiative.state), uint(Signals.InitiativeState.Accepted));

    vm.stopPrank();
  }

  /// Test that only owner can accept initiatives
  function testAcceptInitiativeOnlyOwner() public {
    vm.startPrank(alice);

    // Propose an initiative
    token.approve(address(signalsContract), 100 * 1e18);
    signalsContract.proposeInitiative('Initiative 1', 'Description 1');

    // Attempt to accept the initiative as a non-owner
    vm.expectRevert('Ownable: caller is not the owner');
    signalsContract.acceptInitiative(0);

    vm.stopPrank();
  }

  /// Test withdrawing tokens after initiative is accepted
  function testWithdrawTokens() public {
    vm.startPrank(bob);

    // Propose an initiative with lock
    token.approve(address(signalsContract), 200 * 1e18);
    signalsContract.proposeInitiativeWithLock('Initiative 2', 'Description 2', 200 * 1e18, 6);

    vm.stopPrank();

    vm.startPrank(deployer);

    // Accept the initiative
    signalsContract.acceptInitiative(0);

    vm.stopPrank();

    vm.startPrank(bob);

    // Check initial token balance
    uint256 initialBalance = token.balanceOf(bob);

    // Withdraw tokens
    signalsContract.withdrawTokens(0);

    // Check token balance after withdrawal
    uint256 finalBalance = token.balanceOf(bob);
    assertEq(finalBalance, initialBalance + 200 * 1e18);

    // Check that tokens cannot be withdrawn again
    vm.expectRevert(Signals.NothingToWithdraw.selector);
    signalsContract.withdrawTokens(0);

    vm.stopPrank();
  }

  /// Test withdrawing tokens before initiative is accepted (should fail)
  function testWithdrawTokensBeforeAcceptance() public {
    vm.startPrank(bob);

    // Propose an initiative with lock
    token.approve(address(signalsContract), 200 * 1e18);
    signalsContract.proposeInitiativeWithLock('Initiative 2', 'Description 2', 200 * 1e18, 6);

    // Attempt to withdraw tokens before acceptance
    vm.expectRevert(
      abi.encodeWithSignature(
        'InvalidInitiativeState(string)',
        'Initiative not in a withdrawable state'
      )
    );
    signalsContract.withdrawTokens(0);

    vm.stopPrank();
  }

  /// Test withdrawAll function
  function testWithdrawAll() public {
    vm.startPrank(alice);

    // Propose an initiative with lock
    token.approve(address(signalsContract), 100 * 1e18);
    signalsContract.proposeInitiativeWithLock('Initiative 1', 'Description 1', 100 * 1e18, 6);

    // Support another initiative
    token.approve(address(signalsContract), 150 * 1e18);
    signalsContract.supportInitiative(0, 150 * 1e18, 6);

    vm.stopPrank();

    vm.startPrank(deployer);

    // Accept the initiative
    signalsContract.acceptInitiative(0);

    vm.stopPrank();

    vm.startPrank(alice);

    // Record the balance before withdrawal
    uint256 balanceBefore = token.balanceOf(alice);

    // Withdraw all tokens
    signalsContract.withdrawAll();

    // Record the balance after withdrawal
    uint256 balanceAfter = token.balanceOf(alice);

    // Calculate the balance difference
    uint256 balanceDifference = balanceAfter - balanceBefore;

    // Assert that the balance difference is equal to the withdrawn amount
    assertEq(balanceDifference, 250 * 1e18);

    vm.stopPrank();
  }

  /// Test expiring an initiative after inactivity
  function testExpireInitiative() public {
    vm.startPrank(alice);

    // Propose an initiative
    token.approve(address(signalsContract), 100 * 1e18);
    signalsContract.proposeInitiative('Initiative 1', 'Description 1');

    vm.stopPrank();

    // Fast forward time beyond inactivity threshold
    vm.warp(block.timestamp + 61 days);

    // Expire the initiative
    signalsContract.expireInitiative(0);

    // Check that the initiative state is updated
    Signals.Initiative memory initiative = signalsContract.getInitiative(0);
    assertEq(uint(initiative.state), uint(Signals.InitiativeState.Expired));
  }

  /// Test attempting to expire an initiative before inactivity threshold (should fail)
  function testExpireInitiativeBeforeThreshold() public {
    vm.startPrank(alice);

    // Propose an initiative
    token.approve(address(signalsContract), 100 * 1e18);
    signalsContract.proposeInitiative('Initiative 1', 'Description 1');

    vm.stopPrank();

    // Attempt to expire the initiative before inactivity threshold
    vm.expectRevert(
      abi.encodeWithSignature(
        'InvalidInitiativeState(string)',
        'Initiative not yet eligible for expiration'
      )
    );
    signalsContract.expireInitiative(0);
  }

  /// Test withdrawing tokens after initiative is expired
  function testWithdrawTokensAfterExpiration() public {
    vm.startPrank(bob);

    // Propose an initiative with lock
    token.approve(address(signalsContract), 200 * 1e18);
    signalsContract.proposeInitiativeWithLock('Initiative 2', 'Description 2', 200 * 1e18, 6);

    vm.stopPrank();

    // Fast forward time beyond inactivity threshold
    vm.warp(block.timestamp + 61 days);

    // Expire the initiative
    signalsContract.expireInitiative(0);

    vm.startPrank(bob);

    // Check initial token balance
    uint256 initialBalance = token.balanceOf(bob);

    // Withdraw tokens
    signalsContract.withdrawTokens(0);

    // Check token balance after withdrawal
    uint256 finalBalance = token.balanceOf(bob);
    assertEq(finalBalance, initialBalance + 200 * 1e18);

    vm.stopPrank();
  }

  /// Test updating inactivity threshold as owner
  function testSetInactivityThreshold() public {
    vm.startPrank(deployer);

    // Update the inactivity threshold
    signalsContract.setInactivityThreshold(30 days);

    // Check that the threshold is updated
    assertEq(signalsContract.activityTimeout(), 30 days);

    vm.stopPrank();
  }

  /// Test that non-owners cannot update inactivity threshold
  function testSetInactivityThresholdNonOwner() public {
    vm.startPrank(alice);

    // Attempt to update the inactivity threshold as a non-owner
    vm.expectRevert('Ownable: caller is not the owner');
    signalsContract.setInactivityThreshold(30 days);

    vm.stopPrank();
  }

  /// Test that users cannot withdraw tokens twice using withdrawAll
  function testWithdrawAllCannotWithdrawTwice() public {
    vm.startPrank(bob);

    // Propose an initiative with lock
    token.approve(address(signalsContract), 200 * 1e18);
    signalsContract.proposeInitiativeWithLock('Initiative 1', 'Description 1', 200 * 1e18, 6);

    vm.stopPrank();

    vm.startPrank(deployer);

    // Accept the initiative
    signalsContract.acceptInitiative(0);

    vm.stopPrank();

    vm.startPrank(bob);

    // Withdraw all tokens
    signalsContract.withdrawAll();

    // Attempt to withdraw again
    vm.expectRevert(Signals.NothingToWithdraw.selector);
    signalsContract.withdrawAll();

    vm.stopPrank();
  }

  /// Test that withdrawAll only withdraws from initiatives in withdrawable state
  /// Test that withdrawAll only withdraws from initiatives in withdrawable state
  function testWithdrawAllPartialWithdrawal() public {
    // Propose initiative with lock
    vm.startPrank(bob);
    token.approve(address(signalsContract), PROPOSAL_THRESHOLD);
    signalsContract.proposeInitiativeWithLock(
      'Initiative 1',
      'Description 1',
      PROPOSAL_THRESHOLD,
      6
    );

    // Propose another initiative with lock
    token.approve(address(signalsContract), PROPOSAL_THRESHOLD);
    signalsContract.proposeInitiativeWithLock(
      'Initiative 2',
      'Description 2',
      PROPOSAL_THRESHOLD,
      6
    );
    vm.stopPrank();

    vm.startPrank(deployer);
    signalsContract.acceptInitiative(0);
    vm.stopPrank();

    // Record the balance before first withdrawal
    vm.startPrank(bob);
    uint256 initialBalance = token.balanceOf(bob);
    // Withdraw all tokens (should only withdraw from the accepted initiative)
    signalsContract.withdrawAll();

    // Record the balance after first withdrawal
    uint256 balanceAfterFirstWithdraw = token.balanceOf(bob);

    // Calculate the balance difference
    uint256 balanceDifference = balanceAfterFirstWithdraw - initialBalance;

    // Assert that the balance difference is equal to the withdrawn amount
    assertEq(balanceDifference, PROPOSAL_THRESHOLD);

    // Attempt to withdraw tokens again (should fail)
    vm.expectRevert(Signals.NothingToWithdraw.selector);
    signalsContract.withdrawAll();

    // Fast forward time beyond inactivity threshold
    skip(61 days);

    // Expire the second initiative
    signalsContract.expireInitiative(1);

    // Withdraw tokens from the expired initiative
    signalsContract.withdrawAll();

    // Record the final balance
    uint256 finalBalance = token.balanceOf(bob);

    // Calculate the total balance difference
    uint256 totalBalanceDifference = finalBalance - initialBalance;

    // Assert that the total balance difference equals the sum of both withdrawals
    assertEq(totalBalanceDifference, 2 * PROPOSAL_THRESHOLD);

    vm.stopPrank();
  }
}
