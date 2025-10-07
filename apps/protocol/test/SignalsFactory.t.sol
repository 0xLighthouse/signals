// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/StdUtils.sol";

import "solmate/src/test/utils/mocks/MockERC20.sol";

import {SignalsFactory} from "../src/SignalsFactory.sol";
import {Signals} from "../src/Signals.sol";

import {SignalsHarness} from "./utils/SignalsHarness.sol";
import {ISignalsFactory} from "../src/interfaces/ISignalsFactory.sol";

contract SignalsFactoryTest is Test, SignalsHarness {
    SignalsFactory _factory;

    function setUp() public {
        _factory = new SignalsFactory();
    }

    /*//////////////////////////////////////////////////////////////
                        INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Version_Correct() public {
        assertEq(_factory.version(), "0.1.0");
    }

    function test_Create_DeploysSignalsContract() public {
        // Ensure the caller is the owner
        vm.prank(_deployer);

        uint256[] memory _decayCurveParameters = new uint256[](1);
        _decayCurveParameters[0] = 9e17;

        // Deploy a new instance using the factory
        ISignalsFactory.FactoryDeployment memory _defaultConfig = ISignalsFactory.FactoryDeployment({
            owner: _alice,
            underlyingToken: address(_tokenERC20),
            proposalThreshold: defaultConfig.proposalThreshold,
            acceptanceThreshold: defaultConfig.acceptanceThreshold,
            maxLockIntervals: defaultConfig.maxLockIntervals,
            proposalCap: defaultConfig.proposalCap,
            lockInterval: defaultConfig.lockInterval,
            decayCurveType: defaultConfig.decayCurveType,
            decayCurveParameters: defaultConfig.decayCurveParameters,
            proposalRequirements: defaultConfig.proposalRequirements,
            releaseLockDuration: defaultConfig.releaseLockDuration
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
        assertEq(_instance.underlyingToken(), address(_tokenERC20));
        assertEq(_instance.acceptanceThreshold(), defaultConfig.acceptanceThreshold);
        assertEq(_instance.maxLockIntervals(), defaultConfig.maxLockIntervals);
        assertEq(_instance.proposalCap(), defaultConfig.proposalCap);
        assertEq(_instance.lockInterval(), defaultConfig.lockInterval);
        assertEq(_instance.decayCurveType(), defaultConfig.decayCurveType);
        assertEq(_instance.version(), _factory.version());
    }

    /*//////////////////////////////////////////////////////////////
                        ERROR HANDLING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Create_RevertsWithInvalidOwner() public {
        // Set the implementation to an invalid address and attempt to create a clone
        vm.prank(_deployer);
        vm.expectRevert(abi.encodeWithSelector(SignalsFactory.InvalidOwnerAddress.selector));

        uint256[] memory _decayCurveParameters = new uint256[](1); // 0.9
        _decayCurveParameters[0] = 9e17;

        _factory.create(
            ISignalsFactory.FactoryDeployment({
                owner: address(0), // This is an invalid owner address
                underlyingToken: address(_tokenERC20),
                proposalThreshold: defaultConfig.proposalThreshold,
                acceptanceThreshold: defaultConfig.acceptanceThreshold,
                maxLockIntervals: defaultConfig.maxLockIntervals,
                proposalCap: defaultConfig.proposalCap,
                lockInterval: defaultConfig.lockInterval,
                decayCurveType: defaultConfig.decayCurveType,
                decayCurveParameters: defaultConfig.decayCurveParameters,
                proposalRequirements: defaultConfig.proposalRequirements,
                releaseLockDuration: defaultConfig.releaseLockDuration
            })
        );
    }

    /*//////////////////////////////////////////////////////////////
                        TODO: EVENT EMISSION TESTS
    //////////////////////////////////////////////////////////////*/

    // TODO: Test that the SignalsCreated event is emitted with correct parameters
    // function test_Create_EmitsSignalsCreatedEvent() public {}

    /*//////////////////////////////////////////////////////////////
                        TODO: MULTIPLE DEPLOYMENT TESTS
    //////////////////////////////////////////////////////////////*/

    // TODO: Test creating multiple Signals contracts
    // function test_Create_MultipleSignalsContracts() public {}

    // TODO: Test creating with different underlying tokens
    // function test_Create_WithDifferentUnderlyingTokens() public {}

    // TODO: Test that duplicate deployments are handled correctly
    // function test_Create_RevertsOnDuplicateDeployment() public {}

    /*//////////////////////////////////////////////////////////////
                        TODO: PARAMETER VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    // TODO: Test with different acceptanceThreshold values
    // function test_Create_WithDifferentAcceptanceThreshold() public {}

    // TODO: Test with different maxLockIntervals values
    // function test_Create_WithDifferentMaxLockIntervals() public {}

    // TODO: Test with different proposalCap values
    // function test_Create_WithDifferentProposalCap() public {}

    // TODO: Test with different decayCurveType values
    // function test_Create_WithDifferentDecayCurveTypes() public {}

    // TODO: Test with invalid parameter combinations
    // function test_Create_RevertsWithInvalidParameters() public {}

    /*//////////////////////////////////////////////////////////////
                        TODO: CLONE VERIFICATION TESTS
    //////////////////////////////////////////////////////////////*/

    // TODO: Test that the created Signals contract is a proper clone
    // function test_Create_CreatesProperClone() public {}

    // TODO: Test that clones are independent
    // function test_Clone_AreIndependent() public {}

    /*//////////////////////////////////////////////////////////////
                        TODO: TOKEN VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    // TODO: Add guard to only allow ERC20 tokens
    // function test_Create_OnlyAllowsERC20Tokens() public {}

    // TODO: Test with invalid token address
    // function test_Create_RevertsWithInvalidTokenAddress() public {}

    // TODO: Test with non-contract address as token
    // function test_Create_RevertsWithNonContractToken() public {}

    /*//////////////////////////////////////////////////////////////
                        TODO: FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    // TODO: Fuzz test with various parameter combinations
    // function testFuzz_Create_VariousParameters(
    //     uint256 proposalThreshold,
    //     uint256 acceptanceThreshold,
    //     uint256 maxLockIntervals,
    //     uint256 proposalCap
    // ) public {}

    /*//////////////////////////////////////////////////////////////
                        TODO: INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    // TODO: Test end-to-end factory deployment and usage
    // function test_FullFlow_DeploymentAndUsage() public {}

    // TODO: Test deploying and using multiple instances simultaneously
    // function test_MultipleInstances_Simultaneously() public {}
}
