// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/StdUtils.sol";

import "solmate/src/test/utils/mocks/MockERC20.sol";

import {SignalsFactory} from "../src/SignalsFactory.sol";
import {Signals} from "../src/Signals.sol";

import {SignalsHarness} from "./utils/SignalsHarness.sol";
import {ISignals} from "../src/interfaces/ISignals.sol";
import {ISignalsFactory} from "../src/interfaces/ISignalsFactory.sol";

contract SignalsFactoryTest is Test, SignalsHarness {
    SignalsFactory _factory;

    function setUp() public {
        _factory = new SignalsFactory();
    }

    function testVersion() public {
        assertEq(_factory.version(), "0.1.0");
    }

    function testFactoryDeployment() public {
        // Ensure the caller is the owner
        vm.prank(_deployer);

        uint256[] memory _decayCurveParameters = new uint256[](1);
        _decayCurveParameters[0] = 9e17;

        // Deploy a new instance using the factory
        ISignalsFactory.FactoryDeployment memory _defaultConfig = ISignalsFactory.FactoryDeployment({
            owner: _alice,
            underlyingToken: address(_token),
            proposalThreshold: defaultConfig.proposalThreshold,
            acceptanceThreshold: defaultConfig.acceptanceThreshold,
            maxLockIntervals: defaultConfig.maxLockIntervals,
            proposalCap: defaultConfig.proposalCap,
            lockInterval: defaultConfig.lockInterval,
            decayCurveType: defaultConfig.decayCurveType,
            decayCurveParameters: defaultConfig.decayCurveParameters
        });

        // Check that the Signals contract was deployed
        address instanceAddress = _factory.create(_defaultConfig);
        assertTrue(instanceAddress != address(0));

        // Load the Signals contract instance
        Signals _instance = Signals(instanceAddress);

        console.log("[signals:instance]", instanceAddress);
        console.log("[signals:owner]", _instance.owner());

        // Verify the parameters were initialized correctly
        assertEq(_instance.owner(), _alice);
        assertEq(_instance.underlyingToken(), address(_token));
        assertEq(_instance.acceptanceThreshold(), defaultConfig.acceptanceThreshold);
        assertEq(_instance.maxLockIntervals(), defaultConfig.maxLockIntervals);
        assertEq(_instance.proposalCap(), defaultConfig.proposalCap);
        assertEq(_instance.lockInterval(), defaultConfig.lockInterval);
        assertEq(_instance.decayCurveType(), defaultConfig.decayCurveType);
        assertEq(_instance.version(), _factory.version());
    }

    function testRevertsWithInvalidOwnerAddress() public {
        // Set the implementation to an invalid address and attempt to create a clone
        vm.prank(_deployer);
        vm.expectRevert(abi.encodeWithSelector(SignalsFactory.InvalidOwnerAddress.selector));

        uint256[] memory _decayCurveParameters = new uint256[](1); // 0.9
        _decayCurveParameters[0] = 9e17;

        _factory.create(
            ISignalsFactory.FactoryDeployment({
                owner: address(0), // --- invalid owner address
                underlyingToken: address(_token),
                proposalThreshold: defaultConfig.proposalThreshold,
                acceptanceThreshold: defaultConfig.acceptanceThreshold,
                maxLockIntervals: defaultConfig.maxLockIntervals,
                proposalCap: defaultConfig.proposalCap,
                lockInterval: defaultConfig.lockInterval,
                decayCurveType: defaultConfig.decayCurveType,
                decayCurveParameters: defaultConfig.decayCurveParameters
            })
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
