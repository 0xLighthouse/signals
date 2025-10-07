// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {SignalsHarness} from "../utils/SignalsHarness.sol";

import {ISignals} from "../../src/interfaces/ISignals.sol";
import {Signals} from "../../src/Signals.sol";

/**
 * @title SignalsProposalRequirementsTest
 * @notice Tests for proposal requirements configuration
 */
contract SignalsProposalRequirementsTest is Test, SignalsHarness {
    /*//////////////////////////////////////////////////////////////
                        INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Initialize_AllRequirementModes() public {
        // None mode (default)
        (, Signals signals1) = deploySignalsWithFactory(false);
        ISignals.ProposalRequirements memory reqs1 = signals1.getProposalRequirements();
        assertEq(uint256(reqs1.requirementType), uint256(ISignals.ProposalRequirementType.None));

        // MinBalance mode
        ISignals.SignalsConfig memory config2 = defaultConfig;
        config2.proposalRequirements = ISignals.ProposalRequirements({
            requirementType: ISignals.ProposalRequirementType.MinBalance,
            minBalance: 10_000 * 1e18,
            minHoldingDuration: 0
        });
        Signals signals2 = new Signals();
        signals2.initialize(config2);
        ISignals.ProposalRequirements memory reqs2 = signals2.getProposalRequirements();
        assertEq(uint256(reqs2.requirementType), uint256(ISignals.ProposalRequirementType.MinBalance));
        assertEq(reqs2.minBalance, 10_000 * 1e18);

        // MinBalanceAndDuration mode
        ISignals.SignalsConfig memory config3 = getERC20VotesConfig();
        config3.proposalRequirements = ISignals.ProposalRequirements({
            requirementType: ISignals.ProposalRequirementType.MinBalanceAndDuration,
            minBalance: 10_000 * 1e18,
            minHoldingDuration: 100
        });
        Signals signals3 = new Signals();
        signals3.initialize(config3);
        ISignals.ProposalRequirements memory reqs3 = signals3.getProposalRequirements();
        assertEq(uint256(reqs3.requirementType), uint256(ISignals.ProposalRequirementType.MinBalanceAndDuration));
        assertEq(reqs3.minHoldingDuration, 100);
    }

    /*//////////////////////////////////////////////////////////////
                        NONE MODE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Propose_None_AllowsAnyUser() public {
        (, Signals signals) = deploySignalsWithFactory(false);
        address user = address(0x9999);
        deal(address(_tokenERC20), user, 50_000 * 1e18);

        vm.startPrank(user);
        _tokenERC20.approve(address(signals), 50_000 * 1e18);
        signals.proposeInitiative("Test", "Description");
        vm.stopPrank();

        assertEq(signals.getInitiative(1).proposer, user);
    }

    /*//////////////////////////////////////////////////////////////
                        MIN BALANCE MODE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Propose_MinBalance_EnforcesThreshold() public {
        ISignals.SignalsConfig memory config = defaultConfig;
        config.proposalRequirements = ISignals.ProposalRequirements({
            requirementType: ISignals.ProposalRequirementType.MinBalance,
            minBalance: 75_000 * 1e18,
            minHoldingDuration: 0
        });

        Signals signals = new Signals();
        signals.initialize(config);
        _dealDefaultTokens();

        // Alice (50k) - should fail
        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), 50_000 * 1e18);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISignals.ProposalRequirementsNotMet.selector, "Insufficient token balance for proposal"
            )
        );
        signals.proposeInitiative("Test", "Description");
        vm.stopPrank();

        // Bob (100k) - should succeed
        vm.startPrank(_bob);
        _tokenERC20.approve(address(signals), 100_000 * 1e18);
        signals.proposeInitiative("Test", "Description");
        vm.stopPrank();

        assertEq(signals.getInitiative(1).proposer, _bob);
    }

    function test_CanPropose_MinBalance_ChecksCorrectly() public {
        ISignals.SignalsConfig memory config = defaultConfig;
        config.proposalRequirements = ISignals.ProposalRequirements({
            requirementType: ISignals.ProposalRequirementType.MinBalance,
            minBalance: 75_000 * 1e18,
            minHoldingDuration: 0
        });

        Signals signals = new Signals();
        signals.initialize(config);
        _dealDefaultTokens();

        assertFalse(signals.canPropose(_alice)); // 50k
        assertTrue(signals.canPropose(_bob)); // 100k
        assertFalse(signals.canPropose(_charlie)); // 25k
    }

    /*//////////////////////////////////////////////////////////////
                        MIN BALANCE AND DURATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Propose_MinBalanceAndDuration_AllowsWhenMet() public {
        ISignals.SignalsConfig memory config = getERC20VotesConfig();
        config.proposalRequirements = ISignals.ProposalRequirements({
            requirementType: ISignals.ProposalRequirementType.MinBalanceAndDuration,
            minBalance: 40_000 * 1e18,
            minHoldingDuration: 10
        });

        Signals signals = new Signals();
        signals.initialize(config);
        _dealAndDelegateERC20Votes();

        vm.roll(block.number + 15);

        vm.startPrank(_alice);
        _tokenERC20Votes.approve(address(signals), 50_000 * 1e18);
        signals.proposeInitiative("Test", "Description");
        vm.stopPrank();

        assertEq(signals.getInitiative(1).proposer, _alice);
    }

    function test_Propose_MinBalanceAndDuration_RevertsOnFailure() public {
        ISignals.SignalsConfig memory config = getERC20VotesConfig();
        config.proposalRequirements = ISignals.ProposalRequirements({
            requirementType: ISignals.ProposalRequirementType.MinBalanceAndDuration,
            minBalance: 40_000 * 1e18,
            minHoldingDuration: 50
        });

        Signals signals = new Signals();
        signals.initialize(config);

        vm.roll(100);
        _tokenERC20Votes.mint(_alice, 50_000 * 1e18);
        vm.prank(_alice);
        _tokenERC20Votes.delegate(_alice);

        // Only 10 blocks elapsed (needs 50)
        vm.roll(block.number + 10);

        vm.startPrank(_alice);
        _tokenERC20Votes.approve(address(signals), 50_000 * 1e18);
        vm.expectRevert(
            abi.encodeWithSelector(ISignals.ProposalRequirementsNotMet.selector, "Tokens not held long enough")
        );
        signals.proposeInitiative("Test", "Description");
        vm.stopPrank();
    }

    function test_Propose_MinBalanceAndDuration_RevertsForStandardERC20() public {
        ISignals.SignalsConfig memory config = defaultConfig;
        config.proposalRequirements = ISignals.ProposalRequirements({
            requirementType: ISignals.ProposalRequirementType.MinBalanceAndDuration,
            minBalance: 10_000 * 1e18,
            minHoldingDuration: 10
        });

        Signals signals = new Signals();
        signals.initialize(config);
        _dealDefaultTokens();

        vm.roll(block.number + 15);

        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), 50_000 * 1e18);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISignals.ProposalRequirementsNotMet.selector, "Token does not support holding duration checks"
            )
        );
        signals.proposeInitiative("Test", "Description");
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Initialize_RevertsInvalidConfigurations() public {
        // MinBalance with zero balance
        ISignals.SignalsConfig memory config1 = defaultConfig;
        config1.proposalRequirements = ISignals.ProposalRequirements({
            requirementType: ISignals.ProposalRequirementType.MinBalance,
            minBalance: 0,
            minHoldingDuration: 0
        });
        Signals signals1 = new Signals();
        vm.expectRevert(
            abi.encodeWithSelector(ISignals.ProposalRequirementsNotMet.selector, "MinBalance must be greater than 0")
        );
        signals1.initialize(config1);

        // MinBalanceAndDuration with zero duration
        ISignals.SignalsConfig memory config2 = getERC20VotesConfig();
        config2.proposalRequirements = ISignals.ProposalRequirements({
            requirementType: ISignals.ProposalRequirementType.MinBalanceAndDuration,
            minBalance: 10_000 * 1e18,
            minHoldingDuration: 0
        });
        Signals signals2 = new Signals();
        vm.expectRevert(
            abi.encodeWithSelector(
                ISignals.ProposalRequirementsNotMet.selector, "MinHoldingDuration must be greater than 0"
            )
        );
        signals2.initialize(config2);
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Integration_RequirementsIndependentFromThreshold() public {
        ISignals.SignalsConfig memory config = defaultConfig;
        config.proposalThreshold = 50_000 * 1e18;
        config.proposalRequirements = ISignals.ProposalRequirements({
            requirementType: ISignals.ProposalRequirementType.MinBalance,
            minBalance: 75_000 * 1e18,
            minHoldingDuration: 0
        });

        Signals signals = new Signals();
        signals.initialize(config);
        _dealDefaultTokens();

        // Alice has 50k - meets threshold but NOT requirement
        assertFalse(signals.canPropose(_alice));

        // Bob has 100k - meets both
        assertTrue(signals.canPropose(_bob));
    }

    function test_Integration_BalanceChangesAffectEligibility() public {
        ISignals.SignalsConfig memory config = defaultConfig;
        config.proposalRequirements = ISignals.ProposalRequirements({
            requirementType: ISignals.ProposalRequirementType.MinBalance,
            minBalance: 60_000 * 1e18,
            minHoldingDuration: 0
        });

        Signals signals = new Signals();
        signals.initialize(config);

        // Alice gains tokens
        deal(address(_tokenERC20), _alice, 50_000 * 1e18);
        assertFalse(signals.canPropose(_alice));

        deal(address(_tokenERC20), _alice, 70_000 * 1e18);
        assertTrue(signals.canPropose(_alice));

        // Alice loses tokens
        vm.prank(_alice);
        _tokenERC20.transfer(_bob, 30_000 * 1e18);
        assertFalse(signals.canPropose(_alice));
    }

    function test_Integration_LockingReducesEligibility() public {
        ISignals.SignalsConfig memory config = defaultConfig;
        config.proposalRequirements = ISignals.ProposalRequirements({
            requirementType: ISignals.ProposalRequirementType.MinBalance,
            minBalance: 40_000 * 1e18,
            minHoldingDuration: 0
        });

        Signals signals = new Signals();
        signals.initialize(config);
        _dealDefaultTokens();

        // Alice locks 30k, leaving 20k
        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), 50_000 * 1e18);
        signals.proposeInitiativeWithLock("First", "Description", 30_000 * 1e18, 6);

        // Alice now has 20k - cannot propose again
        assertFalse(signals.canPropose(_alice));
        vm.expectRevert(
            abi.encodeWithSelector(
                ISignals.ProposalRequirementsNotMet.selector, "Insufficient token balance for proposal"
            )
        );
        signals.proposeInitiative("Second", "Description");
        vm.stopPrank();
    }
}
