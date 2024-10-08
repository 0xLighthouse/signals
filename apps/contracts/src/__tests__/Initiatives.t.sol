// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/console.sol';
import 'forge-std/StdUtils.sol';
import 'forge-std/mocks/MockERC20.sol';
import '@openzeppelin/contracts/utils/Strings.sol';

import {SignalsFactory} from '../SignalsFactory.sol';
import {Signals} from '../Signals.sol';

contract InitiativesTest is Test {
  SignalsFactory factory;
  MockERC20 someERC20;

  address deployer;
  address instance;

  address alice;
  address bob;
  address charlie;

  // Parameters
  uint256 constant PROPOSAL_THRESHOLD = 100_000 * 1e18;
  uint256 constant ACCEPTANCE_THRESHOLD = 300_000 * 1e18;
  uint256 constant LOCK_DURATION_CAP = 1;
  uint256 constant PROPOSAL_CAP = 5;
  uint256 constant DECAY_K_VAL = 1;

  function setUp() public {
    deployer = address(this);
    alice = address(0x1111);
    bob = address(0x2222);
    charlie = address(0x3333);

    // Deploy MockERC20 token and mint 1 million tokens
    someERC20 = new MockERC20();
    someERC20.initialize('MockToken', 'MTK', 18);
    uint256 initialSupply = 1_000_000 * 1e18;
    deal(address(someERC20), deployer, initialSupply);

    // Distribute tokens to test addresses
    deal(address(someERC20), alice, 200_000 * 1e18);
    deal(address(someERC20), bob, 200_000 * 1e18);
    deal(address(someERC20), charlie, 50_000 * 1e18);

    // Deploy SignalsFactory with the Signals implementation
    factory = new SignalsFactory();

    // Ensure the caller is the owner
    vm.prank(deployer);

    // Deploy a new Signals contract using the factory
    instance = factory.create(
      alice,
      address(someERC20),
      PROPOSAL_THRESHOLD,
      ACCEPTANCE_THRESHOLD,
      LOCK_DURATION_CAP,
      PROPOSAL_CAP,
      DECAY_K_VAL
    );
  }

  function testRevertProposeInitiativeWithInsufficientTokens() public {
    // Impersonate Charlie
    vm.startPrank(charlie);

    string memory title = 'Insufficient Tokens Initiative';
    string memory body = 'This initiative should fail due to insufficient tokens';

    // Approve the contract to spend the tokens
    someERC20.approve(address(instance), 50_000);

    Signals signals = Signals(instance);

    // Charlie has InsufficientTokens, so this should revert
    vm.expectRevert(Signals.InsufficientTokens.selector);
    signals.proposeInitiative(title, body);
  }

  /// @notice Test proposing an initiative with empty title or body
  function testProposeInitiativeWithEmptyTitleOrBody() public {
    vm.startPrank(alice);

    // Load the Signals contract instance
    Signals _instance = Signals(instance);

    // Attempt to propose with empty title
    vm.expectRevert(
      abi.encodeWithSelector(Signals.InvalidInput.selector, 'Title or body cannot be empty')
    );
    _instance.proposeInitiative('', 'Some body');

    // Attempt to propose with empty body
    vm.expectRevert(
      abi.encodeWithSelector(Signals.InvalidInput.selector, 'Title or body cannot be empty')
    );
    _instance.proposeInitiative('Some title', '');

    vm.stopPrank();
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
    vm.prank(bob);

    // Load the Signals contract instance
    Signals _instance = Signals(instance);

    string memory title = 'Test Proposing Initiative with Locks';
    string memory body = 'This initiative should be proposed with a lock';

    uint256 amountToLock = 100_000 * 1e18;

    console.log('Bob balance:', someERC20.balanceOf(bob));
    console.log('Decimals:', someERC20.decimals());

    // Approve the contract to spend the tokens
    vm.startPrank(bob);
    someERC20.approve(address(_instance), amountToLock);
    _instance.proposeInitiativeWithLock(title, body, amountToLock, 1);
    vm.stopPrank();

    // Retrieve the initiative and check the details
    Signals.Initiative memory initiative = _instance.getInitiative(0);
    assertEq(uint256(initiative.state), uint256(Signals.InitiativeState.Proposed));
    assertEq(initiative.title, title);
    assertEq(initiative.body, body);
    assertEq(address(initiative.proposer), bob);

    // Check the weight
    uint256 weight = _instance.getWeight(0);

    // The weight should be equal to the amount of tokens locked
    console.log('Current weight:', weight);

    // TODO: FIXME
    // TODO: FIXME
    // TODO: FIXME
    // TODO: FIXME
    assertEq(weight, amountToLock);

    // // Let charlie vote
    // vm.startPrank(charlie);
    // someERC20.approve(address(_instance), amount);
    // _instance.supportInitiative(0, amount / 2, 4); // 50% less but double the duration
    // vm.stopPrank();

    // uint256 weight2 = _instance.getWeight(0);
    // assertEq(weight2, 300_000 * 1e18); // 100% more weight
  }
}
