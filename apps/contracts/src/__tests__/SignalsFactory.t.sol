// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/StdUtils.sol';
import 'forge-std/mocks/MockERC20.sol';
import {SignalsFactory} from '../SignalsFactory.sol';
import {Signals} from '../Signals.sol';

contract SignalsFactoryTest is Test {
  SignalsFactory signalsFactory;
  Signals signalsImplementation;
  MockERC20 mockToken;
  address owner;
  address addr1;
  address addr2;
  address addr3;
  address addr4;
  address addr5;

  function setUp() public {
    owner = address(this);
    addr1 = address(0x1234);
    addr2 = address(0x2345);
    addr3 = address(0x3456);
    addr4 = address(0x4567);
    addr5 = address(0x5678);

    // Deploy MockERC20 token and mint 1 million tokens
    mockToken = new MockERC20();
    mockToken.initialize('MockToken', 'MTK', 18);
    uint256 initialSupply = 1_000_000 * 10 ** 18;
    deal(address(mockToken), owner, initialSupply);

    // Distribute tokens to test addresses
    deal(address(mockToken), addr1, 200_000 * 10 ** 18);
    deal(address(mockToken), addr2, 200_000 * 10 ** 18);
    deal(address(mockToken), addr3, 200_000 * 10 ** 18);
    deal(address(mockToken), addr4, 200_000 * 10 ** 18);
    deal(address(mockToken), addr5, 200_000 * 10 ** 18);

    // Deploy Signals implementation
    signalsImplementation = new Signals();

    // Deploy SignalsFactory with the Signals implementation
    signalsFactory = new SignalsFactory(
      address(signalsImplementation),
      address(mockToken), // Use MockERC20 token address for testing
      true // isERC20 is set to true for testing purposes
    );
  }

  function testDeploySignalsContractWithCorrectParameters() public {
    // Ensure the caller is the owner
    vm.prank(owner);

    // Deploy a new Signals contract using the factory
    address newSignalsAddress = signalsFactory.createSignals(
      addr1,
      100, // threshold
      12, // lockDurationCap
      5, // proposalCap
      1 // decayCurveType
    );

    // Check that the Signals contract was deployed
    assertTrue(newSignalsAddress != address(0));

    // Get the deployed Signals contract instance
    Signals newSignals = Signals(newSignalsAddress);

    // Verify the parameters were initialized correctly
    assertEq(newSignals.threshold(), 100);
    assertEq(newSignals.lockDurationCap(), 12);
    assertEq(newSignals.proposalCap(), 5);
    assertEq(newSignals.decayCurveType(), 1);
    assertEq(newSignals.underlyingToken(), address(mockToken));
    assertTrue(newSignals.isERC20());
  }

  function testRevertIfInvalidOwnerAddress() public {
    // Attempt to deploy with an invalid owner address (address(0))
    vm.prank(owner);
    vm.expectRevert(bytes('Invalid owner address'));
    signalsFactory.createSignals(
      address(0), // Invalid owner address
      100, // threshold
      12, // lockDurationCap
      5, // proposalCap
      1 // decayCurveType
    );
  }

  function testRevertIfCloneCreationFails() public {
    // Set the implementation to an invalid address and attempt to create a clone
    vm.prank(owner);
    signalsFactory.setImplementation(address(0));
    vm.expectRevert(bytes('Clone creation failed'));
    vm.prank(owner);
    signalsFactory.createSignals(
      addr1,
      100, // threshold
      12, // lockDurationCap
      5, // proposalCap
      1 // decayCurveType
    );
  }
}
