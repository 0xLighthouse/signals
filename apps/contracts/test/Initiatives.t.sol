// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/console.sol';
import 'forge-std/StdUtils.sol';

import 'solmate/src/test/utils/mocks/MockERC20.sol';

import '@openzeppelin/contracts/utils/Strings.sol';

import {SignalsFactory} from '../src/SignalsFactory.sol';
import {Signals} from '../src/Signals.sol';
import {SignalsHarness} from './utils/SignalsHarness.sol';
import {ISignals} from '../src/interfaces/ISignals.sol';

contract InitiativesTest is Test, SignalsHarness {
  // SignalsFactory factory;
  Signals signals;

  function setUp() public {
    // Deploy SignalsFactory with the Signals implementation
    bool dealTokens = true;
    (, signals) = deploySignalsWithFactory(dealTokens);
  }

  function testRevertProposeInitiativeWithInsufficientTokens() public {
    // Impersonate Charlie
    vm.startPrank(_charlie);

    string memory title = 'Insufficient Tokens Initiative';
    string memory body = 'This initiative should fail due to insufficient tokens';

    // Approve the contract to spend the tokens
    _token.approve(address(signals), 40_000);

    // Charlie has InsufficientTokens, so this should revert
    vm.expectRevert(Signals.InsufficientTokens.selector);
    signals.proposeInitiative(title, body);
  }

  /// @notice Test proposing an initiative with empty title or body
  function testProposeInitiativeWithEmptyTitleOrBody() public {
    // Mint tokens to the alice account
    deal(address(_token), _alice, 200_000 * 1e18);

    // Propose an initiative
    vm.startPrank(_alice);

    // Attempt to propose with empty title
    vm.expectRevert(
      abi.encodeWithSelector(Signals.InvalidInput.selector, 'Title or body cannot be empty')
    );
    signals.proposeInitiative('', 'Some body');

    // Attempt to propose with empty body
    vm.expectRevert(
      abi.encodeWithSelector(Signals.InvalidInput.selector, 'Title or body cannot be empty')
    );
    signals.proposeInitiative('Some title', '');
  }

  /**
   * @notice Test proposing multiple initiatives up to the cap
   *
   *  - TODO: Cap {n} of initiatives proposed in a given period
   *  - TODO: Bonus feature
   *  - TODO: Bonus feature
   *  - TODO: Bonus feature
   */
  // function testProposeMultipleInitiatives() public {
  //   vm.startPrank(alice);

  //   // Load the Signals contract instance
  //   Signals _instance = Signals(instance);

  //   // Propose initiatives up to the cap (5 in this case)
  //   for (uint i = 0; i < 5; i++) {
  //       string memory title = string(abi.encodePacked("Initiative ", Strings.toString(i+1)));
  //       string memory body = string(abi.encodePacked("Description for initiative ", Strings.toString(i+1)));
  //       _instance.proposeInitiative(title, body);
  //   }

  //   // Attempt to propose one more initiative (should fail)
  //   vm.expectRevert(abi.encodeWithSelector(Signals.ProposalCapReached.selector));
  //   _instance.proposeInitiative("Extra Initiative", "This should fail");

  //   vm.stopPrank();
  // }

  function testProposeInitiativeWithLock() public {
    // Bob has enough tokens to propose an initiative with a lock
    vm.prank(_bob);

    string memory title = 'Test Proposing Initiative with Locks';
    string memory body = 'This initiative should be proposed with a lock';

    uint256 amountToLock = 100_000 * 1e18;

    console.log('Bob balance:', _token.balanceOf(_bob));
    console.log('Decimals:', _token.decimals());

    // Approve the contract to spend the tokens
    vm.startPrank(_bob);
    _token.approve(address(signals), amountToLock);
    signals.proposeInitiativeWithLock(title, body, amountToLock, 1);
    vm.stopPrank();

    // Retrieve the initiative and check the details
    Signals.Initiative memory initiative = signals.getInitiative(0);
    assertEq(uint256(initiative.state), uint256(Signals.InitiativeState.Proposed));
    assertEq(initiative.title, title);
    assertEq(initiative.body, body);
    assertEq(address(initiative.proposer), _bob);

    // The weight should be equal to the amount of tokens locked
    uint256 weight = signals.getWeightAt(0, block.timestamp);
    assertEq(weight, amountToLock);
  }
}
