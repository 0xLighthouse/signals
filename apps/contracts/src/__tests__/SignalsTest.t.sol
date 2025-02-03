// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.26;

import 'forge-std/Test.sol';
import 'forge-std/console.sol';

import 'solmate/src/test/utils/mocks/MockERC20.sol';

import {Signals} from '../Signals.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

import {SignalsHarness} from './utils/SignalsHarness.sol';

contract SignalsTest is Test, SignalsHarness {
  Signals signals;

  function setUp() public {
    bool dealTokens = true;
    (, signals) = deploySignalsWithFactory(dealTokens);
  }

  function testDefaultConfig() public view {
    assertEq(signals.owner(), address(_deployer));
    assertEq(signals.underlyingToken(), address(_token));
    assertEq(signals.proposalThreshold(), defaultConfig.proposalThreshold);
    assertEq(signals.acceptanceThreshold(), defaultConfig.acceptanceThreshold);
    assertEq(signals.maxLockIntervals(), defaultConfig.maxLockIntervals);
    assertEq(signals.proposalCap(), defaultConfig.proposalCap);
    assertEq(signals.lockInterval(), defaultConfig.lockInterval);
    assertEq(signals.decayCurveType(), defaultConfig.decayCurveType);
    assertEq(signals.totalInitiatives(), 0);
  }

  /**
   * @notice Test revert when proposing an initiative with insufficient tokens
   */
  function testProposeInitiativeRevertsWithInsufficientTokens() public {
    vm.startPrank(_charlie);
    vm.expectRevert(Signals.InsufficientTokens.selector);
    signals.proposeInitiative('Should revert', 'Description 1');
    vm.stopPrank();
  }

  /**
   * @notice Test proposing an initiative without locking tokens
   */
  function testProposeInitiative() public {
    vm.startPrank(_alice);
    _token.approve(address(signals), defaultConfig.proposalThreshold);

    vm.expectEmit();
    emit Signals.InitiativeProposed(0, _alice, 'Initiative 1', 'Description 1');

    signals.proposeInitiative('Initiative 1', 'Description 1');

    // Check that the initiative is stored correctly
    Signals.Initiative memory initiative = signals.getInitiative(0);
    assertEq(initiative.title, 'Initiative 1');
    assertEq(initiative.body, 'Description 1');
    assertEq(uint(initiative.state), uint(Signals.InitiativeState.Proposed));
    assertEq(initiative.proposer, _alice);

    vm.stopPrank();
  }

  /**
   * @notice Test proposing an initiative with locked tokens
   */
  function testProposeInitiativeWithLock() public {
    vm.startPrank(_bob);
    // Approve the total amount needed (proposal threshold + locked amount)
    _token.approve(address(signals), defaultConfig.proposalThreshold * 2);

    uint256 balanceBefore = _token.balanceOf(_bob);
    uint256 lockedAmount = 50_000 * 1e18;

    // Propose an initiative with lock
    vm.expectEmit();
    emit Signals.InitiativeProposed(0, _bob, 'Initiative 2', 'Description 2');
    signals.proposeInitiativeWithLock('Initiative 2', 'Description 2', lockedAmount, 6);

    assertEq(_token.balanceOf(_bob), balanceBefore - lockedAmount);

    // Check that the initiative is stored correctly
    Signals.Initiative memory initiative = signals.getInitiative(0);
    assertEq(initiative.title, 'Initiative 2');
    assertEq(initiative.body, 'Description 2');
    assertEq(uint(initiative.state), uint(Signals.InitiativeState.Proposed));
    assertEq(initiative.proposer, _bob);

    // Check that the lock info is stored
    (, uint256 amount, uint256 duration, , bool withdrawn) = signals.locks(1);
    assertEq(amount, lockedAmount);
    assertEq(duration, 6);
    assertEq(withdrawn, false);

    // Check that the NFT is minted
    assertEq(signals.balanceOf(_bob), 1);
    assertEq(signals.ownerOf(1), _bob);

    vm.stopPrank();
  }

  /// Test supporting an initiative with locked tokens
  function testSupportInitiative() public {
    vm.startPrank(_alice);

    // Propose an initiative
    _token.approve(address(signals), 100 * 1e18);
    signals.proposeInitiative('Initiative 1', 'Description 1');

    vm.stopPrank();
    vm.startPrank(_bob);

    // Approve tokens
    _token.approve(address(signals), 150 * 1e18);

    // Support the initiative
    signals.supportInitiative(0, 150 * 1e18, 6);

    // Check that the lock info is stored
    (, uint256 amount, uint256 duration, , bool withdrawn) = signals.locks(1);
    assertEq(amount, 150 * 1e18);
    assertEq(duration, 6);
    assertEq(withdrawn, false);

    vm.stopPrank();
  }

  /// Test accepting an initiative
  function testAcceptInitiative() public {
    // Propose an initiative
    vm.startPrank(_alice);
    _token.approve(address(signals), 100 * 1e18);
    signals.proposeInitiative('Initiative 1', 'Description 1');

    // Accept the initiative
    vm.startPrank(_deployer);
    signals.acceptInitiative(0);

    // Check that the initiative state is updated
    Signals.Initiative memory initiative = signals.getInitiative(0);
    assertEq(uint(initiative.state), uint(Signals.InitiativeState.Accepted));
  }

  /// Test that only the owner can accept an initiative
  function test_OnlyOwnerCanAccept() public {
    // Propose an initiative
    vm.startPrank(_alice);
    _token.approve(address(signals), 100 * 1e18);
    signals.proposeInitiative('Initiative 1', 'Description 1');

    // Attempt to accept the initiative as a non-owner
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _alice));
    signals.acceptInitiative(0);
  }

  /// Test redeeming tokens after initiative is accepted
  function testRedemptions() public {
    // Propose an initiative with lock
    vm.startPrank(_bob);
    _token.approve(address(signals), 200 * 1e18);
    signals.proposeInitiativeWithLock('Initiative 2', 'Description 2', 200 * 1e18, 6);

    // Accept the initiative
    vm.startPrank(_deployer);
    signals.acceptInitiative(0);

    // Check initial token balance
    // Withdraw tokens
    vm.startPrank(_bob);
    uint256 initialBalance = _token.balanceOf(_bob);
    signals.redeem(1);

    // Check token balance after withdrawal
    uint256 finalBalance = _token.balanceOf(_bob);
    assertEq(finalBalance, initialBalance + 200 * 1e18);

    // Check that tokens cannot be withdrawn again
    // FIXME: This assertion is not working as expected
    // vm.expectRevert(Signals.TokenDoesNotExist.selector);
    // signals.redeem(1);
  }

  /// Test redeeming tokens before initiative is accepted (should fail)
  function testCannotRedeemBeforeAcceptance() public {
    // Propose an initiative with lock
    vm.startPrank(_bob);
    _token.approve(address(signals), 200 * 1e18);
    signals.proposeInitiativeWithLock('Initiative 2', 'Description 2', 200 * 1e18, 6);

    // Attempt to withdraw tokens before acceptance
    vm.expectRevert(
      abi.encodeWithSignature('InvalidInitiativeState(string)', 'Initiative not withdrawable')
    );
    signals.redeem(1);

    vm.stopPrank();
  }

  /// Test redeeming multiple escrow locks
  function testRedeemMany() public {
    // Propose an initiative with lock
    vm.startPrank(_alice);
    _token.approve(address(signals), 100 * 1e18);
    signals.proposeInitiativeWithLock('Initiative 1', 'Description 1', 100 * 1e18, 6);

    // Add a second lock to the same initiative
    _token.approve(address(signals), 75 * 1e18);
    signals.supportInitiative(0, 75 * 1e18, 6);

    // Support another initiative
    _token.approve(address(signals), 150 * 1e18);
    signals.supportInitiative(0, 150 * 1e18, 6);

    // Accept the initiative
    vm.startPrank(_deployer);
    signals.acceptInitiative(0);

    // Record the balance before withdrawal
    vm.startPrank(_alice);
    uint256 balanceBefore = _token.balanceOf(_alice);

    // List all NFTs owned by the alice
    uint256[] memory nfts = signals.openPositions(_alice);
    assertEq(nfts.length, 3);

    // Iterate over the NFTs and redeem them
    for (uint256 i = 0; i < nfts.length; i++) {
      signals.redeem(nfts[i]);
    }

    uint256 balanceAfter = _token.balanceOf(_alice);
    uint256 balanceDifference = balanceAfter - balanceBefore;

    // Assert that the balance difference is equal to the withdrawn amount
    assertEq(balanceDifference, 325 * 1e18);
  }

  /// Test expiring an initiative after inactivity
  function testExpireInitiative() public {
    // Propose an initiative
    vm.startPrank(_alice);
    _token.approve(address(signals), 100 * 1e18);
    signals.proposeInitiative('Initiative 1', 'Description 1');

    // Fast forward time beyond inactivity threshold
    vm.warp(block.timestamp + 61 days);

    // Expire the initiative
    vm.startPrank(_deployer); // Only owner can expire initiatives
    signals.expireInitiative(0);
    Signals.Initiative memory initiative = signals.getInitiative(0);
    assertEq(uint(initiative.state), uint(Signals.InitiativeState.Expired));
  }

  // Test attempting to expire an initiative before inactivity threshold (should fail)
  function testExpireInitiativeBeforeThreshold() public {
    // Propose an initiative
    vm.startPrank(_alice);
    _token.approve(address(signals), 100 * 1e18);
    signals.proposeInitiative('Initiative 1', 'Description 1');
    vm.stopPrank();

    // Attempt to expire the initiative before inactivity threshold
    vm.expectRevert(
      abi.encodeWithSignature(
        'InvalidInitiativeState(string)',
        'Initiative not yet eligible for expiration'
      )
    );
    signals.expireInitiative(0);
  }

  /// Test withdrawing tokens after initiative is expired
  function testredeemAfterExpiration() public {
    // Propose an initiative with lock
    vm.startPrank(_bob);
    _token.approve(address(signals), 200 * 1e18);
    signals.proposeInitiativeWithLock('Initiative 2', 'Description 2', 200 * 1e18, 6);

    // Fast forward time beyond inactivity threshold
    vm.warp(block.timestamp + 61 days);

    // Expire the initiative
    vm.startPrank(_deployer);
    signals.expireInitiative(0);

    // Check initial token balance
    // Withdraw tokens
    vm.startPrank(_bob);

    uint256 initialBalance = _token.balanceOf(_bob);
    signals.redeem(1);

    uint256 finalBalance = _token.balanceOf(_bob);
    assertEq(finalBalance, initialBalance + 200 * 1e18);
  }

  // Test updating inactivity threshold as owner
  function testSetInactivityThreshold() public {
    // Update the inactivity threshold
    vm.startPrank(_deployer);
    signals.setInactivityThreshold(30 days);

    // Check that the threshold is updated
    assertEq(signals.activityTimeout(), 30 days);
  }

  function test_SetInactivityThresholdOnlyOwner() public {
    vm.startPrank(_alice);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _alice));
    signals.setInactivityThreshold(30 days);
  }

  // Test that users cannot redeem tokens twice
  function testCannotRedeemTwice() public {
    // Propose an initiative with lock
    vm.startPrank(_bob);
    _token.approve(address(signals), 200 * 1e18);
    signals.proposeInitiativeWithLock('Initiative 1', 'Description 1', 200 * 1e18, 6);

    // Accept the initiative
    vm.startPrank(_deployer);
    signals.acceptInitiative(0);

    // Withdraw all tokens
    vm.startPrank(_bob);
    signals.redeem(1);

    // Attempt to withdraw again
    vm.expectRevert(Signals.InvalidRedemption.selector);
    signals.redeem(1);
  }

  /// Test that redeeming multiple escrow locks only withdraws from initiatives in withdrawable state
  function testRedeemManyPartialWithdrawal() public {
    // Propose initiative with lock
    vm.startPrank(_bob);
    _token.approve(address(signals), defaultConfig.proposalThreshold);
    signals.proposeInitiativeWithLock(
      'Initiative 1',
      'Description 1',
      defaultConfig.proposalThreshold,
      6
    );

    // Propose another initiative with lock
    _token.approve(address(signals), defaultConfig.proposalThreshold);
    signals.proposeInitiativeWithLock(
      'Initiative 2',
      'Description 2',
      defaultConfig.proposalThreshold,
      6
    );

    // Accept the first initiative
    vm.startPrank(_deployer);
    signals.acceptInitiative(0);

    // Record the balance before first withdrawal
    vm.startPrank(_bob);
    uint256 initialBalance = _token.balanceOf(_bob);

    // Withdraw all tokens (should only withdraw from the accepted initiative)
    signals.redeem(1); // veBond 1

    // Record the balance after first withdrawal
    uint256 balanceAfterFirstWithdraw = _token.balanceOf(_bob);
    uint256 balanceDifference = balanceAfterFirstWithdraw - initialBalance;
    assertEq(balanceDifference, defaultConfig.proposalThreshold);

    // Attempt to withdraw the second lock...
    vm.startPrank(_bob);
    vm.expectRevert(
      abi.encodeWithSignature('InvalidInitiativeState(string)', 'Initiative not withdrawable')
    );
    signals.redeem(2); // veBond 2

    // Fast forward time beyond inactivity threshold
    skip(61 days);

    // Expire the second initiative
    vm.startPrank(_deployer);
    signals.expireInitiative(1);

    // Withdraw tokens from the expired initiative
    vm.startPrank(_bob);
    signals.redeem(2); // veBond 2

    // Assert that the total balance difference equals the sum of both withdrawals
    uint256 finalBalance = _token.balanceOf(_bob);
    uint256 totalBalanceDifference = finalBalance - initialBalance;
    assertEq(totalBalanceDifference, defaultConfig.proposalThreshold * 2);
  }
}
