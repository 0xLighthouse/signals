// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.28;

import 'forge-std/Test.sol';
import 'forge-std/mocks/MockERC20.sol';
import 'forge-std/console.sol';

import {Signals} from '../Signals.sol';

/// @title SignalsTest
contract SignalsTest is Test {
  Signals _signalsContract;
  MockERC20 _token;

  address _deployer;
  address _alice;
  address _bob;
  address _charlie;

  uint256 constant _PROPOSAL_THRESHOLD = 50_000 * 1e18; // 50k
  uint256 constant _ACCEPTANCE_THRESHOLD = 100_000 * 1e18; // 100k
  uint256 constant _LOCK_DURATION_CAP = 365 days; // 1 year
  uint256 constant _PROPOSAL_CAP = 100; // 100 proposals
  uint256 constant _LOCK_INTERVAL = 1 days; // 1 day
  uint256 constant _DECAY_CURVE_TYPE = 0; // Linear

  function setUp() public {
    _deployer = address(this);
    _alice = address(0x1111);
    _bob = address(0x2222);
    _charlie = address(0x3333);

    // Deploy the mock ERC20 token
    _token = new MockERC20();

    // Deploy the Signals contract
    _signalsContract = new Signals();

    uint256[] memory _decayCurveParameters = new uint256[](1);
    _decayCurveParameters[0] = 9e17;

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
    deal(address(_token), _bob, _PROPOSAL_THRESHOLD * 2); // Bob has 100k
    deal(address(_token), _charlie, _PROPOSAL_THRESHOLD / 2); // Charlie has 25k
  }

  function testInitialState() public view {
    assertEq(_signalsContract.owner(), address(_deployer));
    assertEq(_signalsContract.token(), address(_token));
    assertEq(_signalsContract.proposalThreshold(), _PROPOSAL_THRESHOLD);
    assertEq(_signalsContract.acceptanceThreshold(), _ACCEPTANCE_THRESHOLD);
    assertEq(_signalsContract.maxLockIntervals(), _LOCK_DURATION_CAP);
    assertEq(_signalsContract.proposalCap(), _PROPOSAL_CAP);
    assertEq(_signalsContract.lockInterval(), _LOCK_INTERVAL);
    assertEq(_signalsContract.decayCurveType(), _DECAY_CURVE_TYPE);
    assertEq(_signalsContract.totalInitiatives(), 0);
  }

  // /**
  //  * @notice Test revert when proposing an initiative with insufficient tokens
  //  */
  // function testProposeInitiativeRevertsWithInsufficientTokens() public {
  //   vm.startPrank(_charlie);
  //   vm.expectRevert(Signals.InsufficientTokens.selector);
  //   _signalsContract.proposeInitiative('Should revert', 'Description 1');
  //   vm.stopPrank();
  // }

  // /**
  //  * @notice Test proposing an initiative without locking tokens
  //  */
  // function testProposeInitiative() public {
  //   vm.startPrank(_alice);
  //   _token.approve(address(_signalsContract), _PROPOSAL_THRESHOLD);

  //   vm.expectEmit();
  //   emit Signals.InitiativeProposed(0, _alice, 'Initiative 1', 'Description 1');

  //   _signalsContract.proposeInitiative('Initiative 1', 'Description 1');

  //   // Check that the initiative is stored correctly
  //   Signals.Initiative memory initiative = _signalsContract.getInitiative(0);
  //   assertEq(initiative.title, 'Initiative 1');
  //   assertEq(initiative.body, 'Description 1');
  //   assertEq(uint(initiative.state), uint(Signals.InitiativeState.Proposed));
  //   assertEq(initiative.proposer, _alice);
  //   vm.stopPrank();
  // }

  // /**
  //  * @notice Test proposing an initiative with locked tokens
  //  */
  // function testProposeInitiativeWithLock() public {
  //   vm.startPrank(_bob);
  //   _token.approve(address(_signalsContract), _PROPOSAL_THRESHOLD);

  //   uint256 balanceBefore = _token.balanceOf(_bob);
  //   uint256 lockedAmount = 50_000 * 1e18;

  //   // Propose an initiative with lock
  //   vm.expectEmit();
  //   emit Signals.InitiativeProposed(0, _bob, 'Initiative 2', 'Description 2');
  //   _signalsContract.proposeInitiativeWithLock('Initiative 2', 'Description 2', lockedAmount, 6);

  //   assertEq(_token.balanceOf(_bob), balanceBefore - lockedAmount);

  //   // Check that the initiative is stored correctly
  //   Signals.Initiative memory initiative = _signalsContract.getInitiative(0);
  //   assertEq(initiative.title, 'Initiative 2');
  //   assertEq(initiative.body, 'Description 2');
  //   assertEq(uint(initiative.state), uint(Signals.InitiativeState.Proposed));
  //   assertEq(initiative.proposer, _bob);

  //   // Check that the lock info is stored
  //   (uint256 amount, uint256 duration, , bool withdrawn) = _signalsContract.locks(0, _bob, 0);
  //   assertEq(amount, lockedAmount);
  //   assertEq(duration, 6);
  //   assertEq(withdrawn, false);

  //   vm.stopPrank();
  // }

  // /// Test supporting an initiative with locked tokens
  // function testSupportInitiative() public {
  //   vm.startPrank(_alice);

  //   // Propose an initiative
  //   _token.approve(address(_signalsContract), 100 * 1e18);
  //   _signalsContract.proposeInitiative('Initiative 1', 'Description 1');

  //   vm.stopPrank();

  //   vm.startPrank(_bob);

  //   // Approve tokens
  //   _token.approve(address(_signalsContract), 150 * 1e18);

  //   // Support the initiative
  //   _signalsContract.supportInitiative(0, 150 * 1e18, 6);

  //   // Check that the lock info is stored
  //   (uint256 amount, uint256 duration, , bool withdrawn) = _signalsContract.locks(0, _bob, 0);
  //   assertEq(amount, 150 * 1e18);
  //   assertEq(duration, 6);
  //   assertEq(withdrawn, false);

  //   vm.stopPrank();
  // }

  // /// Test accepting an initiative
  // function testAcceptInitiative() public {
  //   vm.startPrank(_alice);

  //   // Propose an initiative
  //   _token.approve(address(_signalsContract), 100 * 1e18);
  //   _signalsContract.proposeInitiative('Initiative 1', 'Description 1');

  //   vm.stopPrank();

  //   vm.startPrank(_deployer);

  //   // Accept the initiative
  //   _signalsContract.acceptInitiative(0);

  //   // Check that the initiative state is updated
  //   Signals.Initiative memory initiative = _signalsContract.getInitiative(0);
  //   assertEq(uint(initiative.state), uint(Signals.InitiativeState.Accepted));

  //   vm.stopPrank();
  // }

  // /// Test that only owner can accept initiatives
  // function testAcceptInitiativeOnlyOwner() public {
  //   vm.startPrank(_alice);

  //   // Propose an initiative
  //   _token.approve(address(_signalsContract), 100 * 1e18);
  //   _signalsContract.proposeInitiative('Initiative 1', 'Description 1');

  //   // Attempt to accept the initiative as a non-owner
  //   vm.expectRevert('Ownable: caller is not the owner');
  //   _signalsContract.acceptInitiative(0);

  //   vm.stopPrank();
  // }

  // /// Test withdrawing tokens after initiative is accepted
  // function testWithdrawTokens() public {
  //   // Propose an initiative with lock
  //   vm.startPrank(_bob);
  //   _token.approve(address(_signalsContract), 200 * 1e18);
  //   _signalsContract.proposeInitiativeWithLock('Initiative 2', 'Description 2', 200 * 1e18, 6);

  //   vm.stopPrank();

  //   vm.startPrank(_deployer);
  //   _signalsContract.acceptInitiative(0);

  //   vm.stopPrank();

  //   vm.startPrank(_bob);

  //   // Check initial token balance
  //   uint256 initialBalance = _token.balanceOf(_bob);

  //   // Withdraw tokens
  //   _signalsContract.withdrawTokens(0);

  //   // Check token balance after withdrawal
  //   uint256 finalBalance = _token.balanceOf(_bob);
  //   assertEq(finalBalance, initialBalance + 200 * 1e18);

  //   // Check that tokens cannot be withdrawn again
  //   vm.expectRevert(Signals.NothingToWithdraw.selector);
  //   _signalsContract.withdrawTokens(0);

  //   vm.stopPrank();
  // }

  // /// Test withdrawing tokens before initiative is accepted (should fail)
  // function testWithdrawTokensBeforeAcceptance() public {
  //   // Propose an initiative with lock
  //   vm.startPrank(_bob);
  //   _token.approve(address(_signalsContract), 200 * 1e18);
  //   _signalsContract.proposeInitiativeWithLock('Initiative 2', 'Description 2', 200 * 1e18, 6);

  //   // Attempt to withdraw tokens before acceptance
  //   vm.expectRevert(
  //     abi.encodeWithSignature(
  //       'InvalidInitiativeState(string)',
  //       'Initiative not in a withdrawable state'
  //     )
  //   );
  //   _signalsContract.withdrawTokens(0);

  //   vm.stopPrank();
  // }

  // /// Test withdrawAll function
  // function testWithdrawAll() public {
  //   // Propose an initiative with lock
  //   vm.startPrank(_alice);
  //   _token.approve(address(_signalsContract), 100 * 1e18);
  //   _signalsContract.proposeInitiativeWithLock('Initiative 1', 'Description 1', 100 * 1e18, 6);

  //   // Add a second lock to the same initiative
  //   _token.approve(address(_signalsContract), 75 * 1e18);
  //   _signalsContract.supportInitiative(0, 75 * 1e18, 6);

  //   // Support another initiative
  //   _token.approve(address(_signalsContract), 150 * 1e18);
  //   _signalsContract.supportInitiative(0, 150 * 1e18, 6);
  //   vm.stopPrank();

  //   // Accept the initiative
  //   vm.startPrank(_deployer);
  //   _signalsContract.acceptInitiative(0);
  //   vm.stopPrank();

  //   // Record the balance before withdrawal
  //   vm.startPrank(_alice);
  //   uint256 balanceBefore = _token.balanceOf(_alice);

  //   // Withdraw all tokens
  //   _signalsContract.withdrawAllTokens();

  //   // Record the balance after withdrawal
  //   uint256 balanceAfter = _token.balanceOf(_alice);

  //   // Calculate the balance difference
  //   uint256 balanceDifference = balanceAfter - balanceBefore;

  //   // Assert that the balance difference is equal to the withdrawn amount
  //   assertEq(balanceDifference, 325 * 1e18);

  //   vm.stopPrank();
  // }

  // /// Test expiring an initiative after inactivity
  // function testExpireInitiative() public {
  //   // Propose an initiative
  //   vm.startPrank(_alice);
  //   _token.approve(address(_signalsContract), 100 * 1e18);
  //   _signalsContract.proposeInitiative('Initiative 1', 'Description 1');
  //   vm.stopPrank();

  //   // Fast forward time beyond inactivity threshold
  //   vm.warp(block.timestamp + 61 days);

  //   // Expire the initiative
  //   _signalsContract.expireInitiative(0);
  //   Signals.Initiative memory initiative = _signalsContract.getInitiative(0);
  //   assertEq(uint(initiative.state), uint(Signals.InitiativeState.Expired));
  // }

  // /// Test attempting to expire an initiative before inactivity threshold (should fail)
  // function testExpireInitiativeBeforeThreshold() public {
  //   // Propose an initiative
  //   vm.startPrank(_alice);
  //   _token.approve(address(_signalsContract), 100 * 1e18);
  //   _signalsContract.proposeInitiative('Initiative 1', 'Description 1');
  //   vm.stopPrank();

  //   // Attempt to expire the initiative before inactivity threshold
  //   vm.expectRevert(
  //     abi.encodeWithSignature(
  //       'InvalidInitiativeState(string)',
  //       'Initiative not yet eligible for expiration'
  //     )
  //   );
  //   _signalsContract.expireInitiative(0);
  // }

  // /// Test withdrawing tokens after initiative is expired
  // function testWithdrawTokensAfterExpiration() public {
  //   // Propose an initiative with lock
  //   vm.startPrank(_bob);
  //   _token.approve(address(_signalsContract), 200 * 1e18);
  //   _signalsContract.proposeInitiativeWithLock('Initiative 2', 'Description 2', 200 * 1e18, 6);

  //   vm.stopPrank();

  //   // Fast forward time beyond inactivity threshold
  //   vm.warp(block.timestamp + 61 days);

  //   // Expire the initiative
  //   _signalsContract.expireInitiative(0);

  //   // Check initial token balance
  //   vm.startPrank(_bob);
  //   uint256 initialBalance = _token.balanceOf(_bob);

  //   // Withdraw tokens
  //   _signalsContract.withdrawTokens(0);

  //   // Check token balance after withdrawal
  //   uint256 finalBalance = _token.balanceOf(_bob);
  //   assertEq(finalBalance, initialBalance + 200 * 1e18);
  // }

  // /// Test updating inactivity threshold as owner
  // function testSetInactivityThreshold() public {
  //   // Update the inactivity threshold
  //   vm.startPrank(_deployer);
  //   _signalsContract.setInactivityThreshold(30 days);

  //   // Check that the threshold is updated
  //   assertEq(_signalsContract.activityTimeout(), 30 days);
  // }

  // /// Test that non-owners cannot update inactivity threshold
  // function testSetInactivityThresholdNonOwner() public {
  //   vm.startPrank(_alice);

  //   // Attempt to update the inactivity threshold as a non-owner
  //   vm.expectRevert('Ownable: caller is not the owner');
  //   _signalsContract.setInactivityThreshold(30 days);
  // }

  // /// Test that users cannot withdraw tokens twice using withdrawAll
  // function testWithdrawAllCannotWithdrawTwice() public {
  //   // Propose an initiative with lock
  //   vm.startPrank(_bob);
  //   _token.approve(address(_signalsContract), 200 * 1e18);
  //   _signalsContract.proposeInitiativeWithLock('Initiative 1', 'Description 1', 200 * 1e18, 6);
  //   vm.stopPrank();

  //   // Accept the initiative
  //   vm.startPrank(_deployer);
  //   _signalsContract.acceptInitiative(0);
  //   vm.stopPrank();

  //   // Withdraw all tokens
  //   vm.startPrank(_bob);
  //   _signalsContract.withdrawAllTokens();

  //   // Attempt to withdraw again
  //   vm.expectRevert(Signals.NothingToWithdraw.selector);
  //   _signalsContract.withdrawAllTokens();

  //   vm.stopPrank();
  // }

  // /// Test that withdrawAll only withdraws from initiatives in withdrawable state
  // function testWithdrawAllPartialWithdrawal() public {
  //   // Propose initiative with lock
  //   vm.startPrank(_bob);
  //   _token.approve(address(_signalsContract), _PROPOSAL_THRESHOLD);
  //   _signalsContract.proposeInitiativeWithLock(
  //     'Initiative 1',
  //     'Description 1',
  //     _PROPOSAL_THRESHOLD,
  //     6
  //   );

  //   // Propose another initiative with lock
  //   _token.approve(address(_signalsContract), _PROPOSAL_THRESHOLD);
  //   _signalsContract.proposeInitiativeWithLock(
  //     'Initiative 2',
  //     'Description 2',
  //     _PROPOSAL_THRESHOLD,
  //     6
  //   );
  //   vm.stopPrank();

  //   // Accept the first initiative
  //   vm.startPrank(_deployer);
  //   _signalsContract.acceptInitiative(0);
  //   vm.stopPrank();

  //   // Record the balance before first withdrawal
  //   vm.startPrank(_bob);
  //   uint256 initialBalance = _token.balanceOf(_bob);

  //   // Withdraw all tokens (should only withdraw from the accepted initiative)
  //   _signalsContract.withdrawAllTokens();

  //   // Record the balance after first withdrawal
  //   uint256 balanceAfterFirstWithdraw = _token.balanceOf(_bob);
  //   uint256 balanceDifference = balanceAfterFirstWithdraw - initialBalance;
  //   assertEq(balanceDifference, _PROPOSAL_THRESHOLD);

  //   // Attempt to withdraw tokens again (should fail)
  //   vm.expectRevert(Signals.NothingToWithdraw.selector);
  //   _signalsContract.withdrawAllTokens();
  //   vm.stopPrank();

  //   // Fast forward time beyond inactivity threshold
  //   skip(61 days);

  //   // Expire the second initiative
  //   vm.startPrank(_deployer);
  //   _signalsContract.expireInitiative(1);
  //   vm.stopPrank();

  //   // Withdraw tokens from the expired initiative
  //   vm.startPrank(_bob);
  //   _signalsContract.withdrawAllTokens();
  //   vm.stopPrank();

  //   // Assert that the total balance difference equals the sum of both withdrawals
  //   uint256 finalBalance = _token.balanceOf(_bob);
  //   uint256 totalBalanceDifference = finalBalance - initialBalance;
  //   assertEq(totalBalanceDifference, _PROPOSAL_THRESHOLD * 2);
  // }
}
