// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/console.sol';
import 'forge-std/StdUtils.sol';
import 'forge-std/mocks/MockERC20.sol';
import {SignalsFactory} from '../SignalsFactory.sol';
import {Signals} from '../Signals.sol';

contract ProposeInitiativesTest is Test {
  SignalsFactory factory;
  MockERC20 someERC20;

  address deployer;
  address instance;

  address alice;
  address bob;
  address charlie;

  function setUp() public {
    deployer = address(this);

    alice = address(0x1111);
    bob = address(0x2222);
    charlie = address(0x3333);

    // Log the test addresses
    console.log('Deployer:', deployer);
    console.log('Alice:', alice);
    console.log('Bob:', bob);

    // Deploy MockERC20 token and mint 1 million tokens
    someERC20 = new MockERC20();
    someERC20.initialize('MockToken', 'MTK', 18);
    uint256 initialSupply = 1_000_000 * 1e18;
    deal(address(someERC20), deployer, initialSupply);

    // Distribute tokens to test addresses
    deal(address(someERC20), alice, 200_000 * 1e18);
    deal(address(someERC20), bob, 200_000 * 1e18);
    deal(address(someERC20), charlie, 200_000 * 1e18);

    // Deploy SignalsFactory with the Signals implementation
    factory = new SignalsFactory();

    // Ensure the caller is the owner
    vm.prank(deployer);

    // Deploy a new Signals contract using the factory
    instance = factory.create(
      alice,
      address(someERC20),
      100, // threshold
      12, // lockDurationCap
      5, // proposalCap
      1 // decayCurveType
    );
  }

  function testProposeInitiative() public {
    vm.prank(alice);

    // Load the Signals contract instance
    Signals _instance = Signals(instance);

    string memory title = 'Some title';
    string memory body = 'Some body';

    _instance.proposeInitiative(title, body);

    // Retrieve the initiative
    Signals.Initiative memory initiative = _instance.getInitiative(0);

    // Check the initiative's state
    assertEq(uint256(initiative.state), uint256(Signals.InitiativeState.Proposed));
    assertEq(initiative.title, title);
    assertEq(initiative.body, body);
    assertEq(address(initiative.proposer), alice);

    // Check the weight
    uint256 weight = _instance.getWeight(0);
    assertEq(weight, 0); // Weight should be 0
  }

  function testProposeInitiativeWithLock() public {
    vm.prank(bob);

    // Load the Signals contract instance
    Signals _instance = Signals(instance);
    string memory title = 'Some title';
    string memory body = 'Some body';

    uint256 amount = 100_000 * 1e18;

    console.log('Bob balance:', someERC20.balanceOf(bob));
    console.log('Decimals:', someERC20.decimals());

    // Approve the contract to spend the tokens
    vm.startPrank(bob);
    someERC20.approve(address(_instance), someERC20.balanceOf(bob));
    vm.stopPrank();

    // Ensure the caller is the owner
    vm.prank(bob);
    _instance.proposeInitiativeWithLock(title, body, amount, 1);

    // Retrieve the initiative
    Signals.Initiative memory initiative = _instance.getInitiative(0);

    // Check the initiative's state
    assertEq(uint256(initiative.state), uint256(Signals.InitiativeState.Proposed));
    assertEq(initiative.title, title);
    assertEq(initiative.body, body);

    assertEq(address(initiative.proposer), bob);

    // Check the weight
    uint256 weight = _instance.getWeight(0);
    assertEq(weight, amount);
  }
}
