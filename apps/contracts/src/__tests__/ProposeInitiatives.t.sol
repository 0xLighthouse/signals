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
  MockERC20 mockToken;

  address deployer;
  address instance;

  address alice;
  address bob;
  address charlie;

  function setUp() public {
    deployer = address(this);

    alice = address(0x1234);
    bob = address(0x2345);
    charlie = address(0x3456);

    // Log the test addresses
    console.log('Deployer:', deployer);
    console.log('Alice:', alice);

    // Deploy MockERC20 token and mint 1 million tokens
    mockToken = new MockERC20();
    mockToken.initialize('MockToken', 'MTK', 18);
    uint256 initialSupply = 1_000_000 * 10 ** 18;
    deal(address(mockToken), deployer, initialSupply);

    // Distribute tokens to test addresses
    deal(address(mockToken), alice, 200_000 * 10 ** 18);
    deal(address(mockToken), bob, 200_000 * 10 ** 18);
    deal(address(mockToken), charlie, 200_000 * 10 ** 18);

    // Deploy SignalsFactory with the Signals implementation
    factory = new SignalsFactory();

    // Ensure the caller is the owner
    vm.prank(deployer);

    // Deploy a new Signals contract using the factory
    instance = factory.create(
      alice,
      address(mockToken),
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
}
