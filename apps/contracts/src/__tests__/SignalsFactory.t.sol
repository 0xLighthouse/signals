// SPDX-License-Identifier: GPL-3.0-or-later

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

  function setUp() public {
    deployer = address(this);
    alice = address(0x1111);

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

    // Deploy the SignalsFactory contract
    factory = new SignalsFactory();
  }

  function testFactoryDeployment() public {
    // Ensure the caller is the owner
    vm.prank(deployer);

    // Deploy a new instance using the factory
    address instanceAddress = factory.create(
      alice,
      address(mockToken),
      100, // proposalThreshold
      100, // acceptanceThreshold
      12, // lockDurationCap
      5, // proposalCap
      1 // decayCurveType
    );

    // Check that the Signals contract was deployed
    assertTrue(instanceAddress != address(0));

    // Load the Signals contract instance
    Signals _instance = Signals(instanceAddress);

    console.log('[signals:instance]', instanceAddress);
    console.log('[signals:owner]', _instance.owner());

    // Verify the parameters were initialized correctly
    assertEq(_instance.owner(), alice);
    assertEq(_instance.underlyingToken(), address(mockToken));
    assertEq(_instance.acceptanceThreshold(), 100);
    assertEq(_instance.lockDurationCap(), 12);
    assertEq(_instance.proposalCap(), 5);
    assertEq(_instance.decayInterval(), 1);
  }

  function testRevertsWithInvalidOwnerAddress() public {
    // Set the implementation to an invalid address and attempt to create a clone
    vm.prank(deployer);
    vm.expectRevert(abi.encodeWithSelector(SignalsFactory.InvalidOwnerAddress.selector));

    factory.create(
      address(0), // --- invalid owner address
      address(mockToken),
      100,
      100,
      12,
      5,
      1
    );
  }

  // TODO: Test that the SignalsCreated event is emitted with correct parameters
  // function testSignalsCreatedEvent() public {
  //   // Implement this test
  // }

  // TODO: Test creating multiple Signals contracts
  // function testCreateMultipleSignals() public {
  //   // Implement this test
  // }

  // TODO: Test with different parameters (e.g. acceptanceThreshold, lockDurationCap, proposalCap, decayCurveType)
  // Also include fuzzing tests
  // function testCreateWithDifferentParameters() public {
  //   // Implement this test
  // }

  // TODO: Test that the created Signals contract is a clone
  // function testCreatedContractIsClone() public {
  //   // Implement this test
  // }

  // TODO: Add guard to only allow ERC20 tokens
  // function testUnderlyingTokenInteraction() public {
  //   // Implement this test
  // }

  // TODO: Add guard to only allow ERC20 tokens
  // function testUnderlyingTokenInteraction() public {
  //   // Implement this test
  // }
}
