// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/console.sol';
import 'forge-std/StdUtils.sol';
import 'forge-std/mocks/MockERC20.sol';

import {SignalsFactory} from '../SignalsFactory.sol';
import {Signals} from '../Signals.sol';

contract SignalsFactoryTest is Test {
  SignalsFactory _factory;
  MockERC20 _mockToken;

  address _deployer;
  address _alice;

  uint256 constant _PROPOSAL_THRESHOLD = 50_000 * 1e18; // 50k
  uint256 constant _ACCEPTANCE_THRESHOLD = 100_000 * 1e18; // 100k
  uint256 constant _LOCK_DURATION_CAP = 365 days; // 1 year
  uint256 constant _PROPOSAL_CAP = 100; // 100 proposals
  uint256 constant _LOCK_INTERVAL = 1 days; // 1 day
  uint256 constant _DECAY_CURVE_TYPE = 0; // Linear

  function setUp() public {
    _deployer = address(this);
    _alice = address(0x1111);

    // Log the test addresses
    console.log('Deployer:', _deployer);
    console.log('Alice:', _alice);

    // Deploy MockERC20 token and mint 1 million tokens
    _mockToken = new MockERC20();
    _mockToken.initialize('MockToken', 'MTK', 18);
    uint256 initialSupply = 1_000_000 * 10 ** 18;
    deal(address(_mockToken), _deployer, initialSupply);

    // Distribute tokens to test addresses
    deal(address(_mockToken), _alice, 200_000 * 10 ** 18);

    // Deploy the SignalsFactory contract
    _factory = new SignalsFactory();
  }

  function testFactoryDeployment() public {
    // Ensure the caller is the owner
      vm.prank(_deployer);

    uint256[] memory _decayCurveParameters = new uint256[](1);
    _decayCurveParameters[0] = 9e17;

    // Deploy a new instance using the factory
    address instanceAddress = _factory.create(
      _alice,
      address(_mockToken),
      _PROPOSAL_THRESHOLD,
      _ACCEPTANCE_THRESHOLD,
      _LOCK_DURATION_CAP,
      _PROPOSAL_CAP,
      _LOCK_INTERVAL,
      _DECAY_CURVE_TYPE,
      _decayCurveParameters
    );

    // Check that the Signals contract was deployed
    assertTrue(instanceAddress != address(0));

    // Load the Signals contract instance
    Signals _instance = Signals(instanceAddress);

    console.log('[signals:instance]', instanceAddress);
    console.log('[signals:owner]', _instance.owner());

    // Verify the parameters were initialized correctly
    assertEq(_instance.owner(), _alice);
    assertEq(_instance.underlyingToken(), address(_mockToken));
    assertEq(_instance.acceptanceThreshold(), _ACCEPTANCE_THRESHOLD);
    assertEq(_instance.maxLockIntervals(), _LOCK_DURATION_CAP);
    assertEq(_instance.proposalCap(), _PROPOSAL_CAP);
    assertEq(_instance.lockInterval(), _LOCK_INTERVAL);
    assertEq(_instance.decayCurveType(), _DECAY_CURVE_TYPE);
  }

  function testRevertsWithInvalidOwnerAddress() public {
    // Set the implementation to an invalid address and attempt to create a clone
    vm.prank(_deployer);
    vm.expectRevert(abi.encodeWithSelector(SignalsFactory.InvalidOwnerAddress.selector));

    uint256[] memory _decayCurveParameters = new uint256[](1); // 0.9
    _decayCurveParameters[0] = 9e17;

    _factory.create(
      address(0), // --- invalid owner address
      address(_mockToken),
      _PROPOSAL_THRESHOLD,
      _ACCEPTANCE_THRESHOLD,
      _LOCK_DURATION_CAP,
      _PROPOSAL_CAP,
      _LOCK_INTERVAL,
      _DECAY_CURVE_TYPE,
      _decayCurveParameters
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
