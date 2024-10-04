// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/console.sol';
import 'forge-std/StdUtils.sol';
import 'forge-std/mocks/MockERC20.sol';
import {SignalsFactory} from '../SignalsFactory.sol';
import {Signals} from '../Signals.sol';

contract SignalsFactoryTest is Test {
  SignalsFactory factory;
  MockERC20 mockToken;

  address deployer;

  address alice;
  address bob;
  address charlie;

  function setUp() public {
    deployer = address(this);

    alice = address(0x1234);
    bob = address(0x2345);
    charlie = address(0x3456);

    // Log the test addresses
    console.log('Owner:', deployer);
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
  }

  function testFactoryDeploymentWithCorrectParameters() public {
    // Ensure the caller is the owner
    vm.prank(deployer);

    // Deploy a new Signals contract using the factory
    address newSignalsAddress = factory.create(
      alice,
      address(mockToken),
      100, // threshold
      12, // lockDurationCap
      5, // proposalCap
      1 // decayCurveType
    );

    // Check that the Signals contract was deployed
    assertTrue(newSignalsAddress != address(0));

    console.log('[signals:instance]', newSignalsAddress);

    // Load the Signals contract instance
    Signals instance = Signals(newSignalsAddress);

    // Verify the parameters were initialized correctly
    // assertEq(newSignals.threshold(), 100);
    assertEq(instance.owner(), address(alice));
    assertEq(instance.lockDurationCap(), 12);
    assertEq(instance.proposalCap(), 5);
    assertEq(instance.decayCurveType(), 1);
    assertEq(instance.underlyingToken(), address(mockToken));
  }

  function testRevertCreatingInstancesWithAnInvalidOwner() public {
    // Set the implementation to an invalid address and attempt to create a clone
    vm.prank(deployer);
    vm.expectRevert(abi.encodeWithSelector(SignalsFactory.InvalidOwnerAddress.selector));
    factory.create(
      address(0), // --- invalid owner address
      address(mockToken),
      100,
      12,
      5,
      1
    );
  }
}
