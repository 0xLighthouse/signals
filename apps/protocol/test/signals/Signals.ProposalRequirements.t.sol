// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {SignalsHarness} from "../utils/SignalsHarness.sol";

import {ISignals} from "../../src/interfaces/ISignals.sol";
import {Signals} from "../../src/Signals.sol";

/**
 * @title SignalsProposalRequirementsTest
 * @notice Tests for proposal requirements configuration
 * @dev Covers None, MinBalance, and MinBalanceAndDuration modes
 */
contract SignalsProposalRequirementsTest is Test, SignalsHarness {

    /*//////////////////////////////////////////////////////////////
                        INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ProposalRequirements_DefaultNone() public {
        // Deploy with default config (None mode)
        bool dealTokens = true;
        (, Signals signals) = deploySignalsWithFactory(dealTokens);

        ISignals.ProposalRequirements memory reqs = signals.getProposalRequirements();
        assertEq(uint256(reqs.requirementType), uint256(ISignals.ProposalRequirementType.None));
        assertEq(reqs.minBalance, 0);
        assertEq(reqs.minHoldingDuration, 0);
    }

    function test_ProposalRequirements_InitializeWithMinBalance() public {
        // Create config with MinBalance requirement
        ISignals.SignalsConfig memory config = defaultConfig;
        config.proposalRequirements = ISignals.ProposalRequirements({
            requirementType: ISignals.ProposalRequirementType.MinBalance,
            minBalance: 10_000 * 1e18,
            minHoldingDuration: 0
        });

        Signals signals = new Signals();
        signals.initialize(config);

        ISignals.ProposalRequirements memory reqs = signals.getProposalRequirements();
        assertEq(uint256(reqs.requirementType), uint256(ISignals.ProposalRequirementType.MinBalance));
        assertEq(reqs.minBalance, 10_000 * 1e18);
        assertEq(reqs.minHoldingDuration, 0);
    }

    function test_ProposalRequirements_InitializeWithMinBalanceAndDuration() public {
        // Create config with MinBalanceAndDuration requirement
        ISignals.SignalsConfig memory config = getERC20VotesConfig();
        config.proposalRequirements = ISignals.ProposalRequirements({
            requirementType: ISignals.ProposalRequirementType.MinBalanceAndDuration,
            minBalance: 10_000 * 1e18,
            minHoldingDuration: 100 // blocks
        });

        Signals signals = new Signals();
        signals.initialize(config);

        ISignals.ProposalRequirements memory reqs = signals.getProposalRequirements();
        assertEq(uint256(reqs.requirementType), uint256(ISignals.ProposalRequirementType.MinBalanceAndDuration));
        assertEq(reqs.minBalance, 10_000 * 1e18);
        assertEq(reqs.minHoldingDuration, 100);
    }

    /*//////////////////////////////////////////////////////////////
                        NONE MODE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Propose_None_AllowsAnyUser() public {
        // Deploy with None mode (default)
        bool dealTokens = false;
        (, Signals signals) = deploySignalsWithFactory(dealTokens);

        // Give user enough for proposal threshold but no extra
        address user = address(0x9999);
        deal(address(_tokenERC20), user, 50_000 * 1e18);

        // User can propose even with exact threshold
        vm.startPrank(user);
        _tokenERC20.approve(address(signals), 50_000 * 1e18);
        signals.proposeInitiative("Test", "Description");
        vm.stopPrank();

        ISignals.Initiative memory initiative = signals.getInitiative(1);
        assertEq(initiative.proposer, user);
    }

    function test_CanPropose_None_AlwaysReturnsTrue() public {
        bool dealTokens = false;
        (, Signals signals) = deploySignalsWithFactory(dealTokens);

        // Anyone can propose in None mode (balance doesn't matter for eligibility)
        assertTrue(signals.canPropose(address(0x1234)));
        assertTrue(signals.canPropose(address(0x5678)));
        assertTrue(signals.canPropose(_alice));
    }

    /*//////////////////////////////////////////////////////////////
                        MIN BALANCE MODE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Propose_MinBalance_AllowsWhenMet() public {
        // Create config with 10k minimum balance
        ISignals.SignalsConfig memory config = defaultConfig;
        config.proposalRequirements = ISignals.ProposalRequirements({
            requirementType: ISignals.ProposalRequirementType.MinBalance,
            minBalance: 10_000 * 1e18,
            minHoldingDuration: 0
        });

        Signals signals = new Signals();
        signals.initialize(config);

        // Alice has 50k tokens (meets requirement)
        _dealDefaultTokens();

        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), 50_000 * 1e18);
        signals.proposeInitiative("Test", "Description");
        vm.stopPrank();

        ISignals.Initiative memory initiative = signals.getInitiative(1);
        assertEq(initiative.proposer, _alice);
    }

    function test_Propose_MinBalance_RevertsWhenNotMet() public {
        // Create config with 100k minimum balance
        ISignals.SignalsConfig memory config = defaultConfig;
        config.proposalRequirements = ISignals.ProposalRequirements({
            requirementType: ISignals.ProposalRequirementType.MinBalance,
            minBalance: 100_000 * 1e18,
            minHoldingDuration: 0
        });

        Signals signals = new Signals();
        signals.initialize(config);

        // Alice has only 50k tokens (doesn't meet 100k requirement)
        _dealDefaultTokens();

        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), 50_000 * 1e18);
        vm.expectRevert(abi.encodeWithSelector(ISignals.ProposalRequirementsNotMet.selector, "Insufficient token balance for proposal"));
        signals.proposeInitiative("Test", "Description");
        vm.stopPrank();
    }

    function test_Propose_MinBalance_ChecksExactThreshold() public {
        // Create config with exact threshold
        ISignals.SignalsConfig memory config = defaultConfig;
        config.proposalRequirements = ISignals.ProposalRequirements({
            requirementType: ISignals.ProposalRequirementType.MinBalance,
            minBalance: 50_000 * 1e18,
            minHoldingDuration: 0
        });

        Signals signals = new Signals();
        signals.initialize(config);

        // Alice has exactly 50k (should work)
        _dealDefaultTokens();

        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), 50_000 * 1e18);
        signals.proposeInitiative("Test", "Description");
        vm.stopPrank();

        ISignals.Initiative memory initiative = signals.getInitiative(1);
        assertEq(initiative.proposer, _alice);
    }

    function test_CanPropose_MinBalance_ReturnsCorrectly() public {
        ISignals.SignalsConfig memory config = defaultConfig;
        config.proposalRequirements = ISignals.ProposalRequirements({
            requirementType: ISignals.ProposalRequirementType.MinBalance,
            minBalance: 75_000 * 1e18,
            minHoldingDuration: 0
        });

        Signals signals = new Signals();
        signals.initialize(config);
        _dealDefaultTokens();

        // Alice has 50k - should return false
        assertFalse(signals.canPropose(_alice));

        // Bob has 100k - should return true
        assertTrue(signals.canPropose(_bob));

        // Charlie has 25k - should return false
        assertFalse(signals.canPropose(_charlie));
    }

    /*//////////////////////////////////////////////////////////////
                        MIN BALANCE AND DURATION TESTS (ERC20Votes)
    //////////////////////////////////////////////////////////////*/

    function test_Propose_MinBalanceAndDuration_AllowsWhenMet() public {
        // Create config with balance + duration requirement
        ISignals.SignalsConfig memory config = getERC20VotesConfig();
        config.proposalRequirements = ISignals.ProposalRequirements({
            requirementType: ISignals.ProposalRequirementType.MinBalanceAndDuration,
            minBalance: 40_000 * 1e18,
            minHoldingDuration: 10 // blocks
        });

        Signals signals = new Signals();
        signals.initialize(config);
        _dealAndDelegateERC20Votes();

        // Roll forward to establish history
        vm.roll(block.number + 15);

        // Alice has had 50k for 15 blocks (meets requirement)
        vm.startPrank(_alice);
        _tokenERC20Votes.approve(address(signals), 50_000 * 1e18);
        signals.proposeInitiative("Test", "Description");
        vm.stopPrank();

        ISignals.Initiative memory initiative = signals.getInitiative(1);
        assertEq(initiative.proposer, _alice);
    }

    function test_Propose_MinBalanceAndDuration_RevertsInsufficientBalance() public {
        ISignals.SignalsConfig memory config = getERC20VotesConfig();
        config.proposalRequirements = ISignals.ProposalRequirements({
            requirementType: ISignals.ProposalRequirementType.MinBalanceAndDuration,
            minBalance: 200_000 * 1e18, // Alice only has 50k
            minHoldingDuration: 10
        });

        Signals signals = new Signals();
        signals.initialize(config);
        _dealAndDelegateERC20Votes();

        vm.roll(block.number + 15);

        vm.startPrank(_alice);
        _tokenERC20Votes.approve(address(signals), 50_000 * 1e18);
        vm.expectRevert(abi.encodeWithSelector(ISignals.ProposalRequirementsNotMet.selector, "Insufficient token balance for proposal"));
        signals.proposeInitiative("Test", "Description");
        vm.stopPrank();
    }

    function test_Propose_MinBalanceAndDuration_RevertsInsufficientDuration() public {
        ISignals.SignalsConfig memory config = getERC20VotesConfig();
        config.proposalRequirements = ISignals.ProposalRequirements({
            requirementType: ISignals.ProposalRequirementType.MinBalanceAndDuration,
            minBalance: 40_000 * 1e18,
            minHoldingDuration: 50 // blocks
        });

        Signals signals = new Signals();
        signals.initialize(config);

        // Start from a higher block to avoid underflow
        vm.roll(100);

        // Alice gets tokens NOW
        _tokenERC20Votes.mint(_alice, 50_000 * 1e18);
        vm.prank(_alice);
        _tokenERC20Votes.delegate(_alice);

        // Only roll forward 10 blocks (requirement is 50 blocks)
        vm.roll(block.number + 10);

        vm.startPrank(_alice);
        _tokenERC20Votes.approve(address(signals), 50_000 * 1e18);
        vm.expectRevert(abi.encodeWithSelector(ISignals.ProposalRequirementsNotMet.selector, "Tokens not held long enough"));
        signals.proposeInitiative("Test", "Description");
        vm.stopPrank();
    }

    function test_Propose_MinBalanceAndDuration_RevertsUnsupportedToken() public {
        // Try to use standard ERC20 (no checkpoints) with MinBalanceAndDuration
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
        vm.expectRevert(abi.encodeWithSelector(ISignals.ProposalRequirementsNotMet.selector, "Token does not support holding duration checks"));
        signals.proposeInitiative("Test", "Description");
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        QUERY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GetProposalRequirements_ReturnsCorrectly() public {
        ISignals.SignalsConfig memory config = defaultConfig;
        config.proposalRequirements = ISignals.ProposalRequirements({
            requirementType: ISignals.ProposalRequirementType.MinBalance,
            minBalance: 12_345 * 1e18,
            minHoldingDuration: 0
        });

        Signals signals = new Signals();
        signals.initialize(config);

        ISignals.ProposalRequirements memory reqs = signals.getProposalRequirements();
        assertEq(uint256(reqs.requirementType), uint256(ISignals.ProposalRequirementType.MinBalance));
        assertEq(reqs.minBalance, 12_345 * 1e18);
        assertEq(reqs.minHoldingDuration, 0);
    }

    function test_CanPropose_ChecksCorrectly() public {
        ISignals.SignalsConfig memory config = defaultConfig;
        config.proposalRequirements = ISignals.ProposalRequirements({
            requirementType: ISignals.ProposalRequirementType.MinBalance,
            minBalance: 60_000 * 1e18,
            minHoldingDuration: 0
        });

        Signals signals = new Signals();
        signals.initialize(config);
        _dealDefaultTokens();

        // Check before any balance changes
        assertFalse(signals.canPropose(_alice)); // Has 50k
        assertTrue(signals.canPropose(_bob)); // Has 100k
        assertFalse(signals.canPropose(_charlie)); // Has 25k
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Propose_WithLock_RespectsRequirements() public {
        ISignals.SignalsConfig memory config = defaultConfig;
        config.proposalRequirements = ISignals.ProposalRequirements({
            requirementType: ISignals.ProposalRequirementType.MinBalance,
            minBalance: 75_000 * 1e18,
            minHoldingDuration: 0
        });

        Signals signals = new Signals();
        signals.initialize(config);
        _dealDefaultTokens();

        // Alice has 50k - should fail
        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), 50_000 * 1e18);
        vm.expectRevert(abi.encodeWithSelector(ISignals.ProposalRequirementsNotMet.selector, "Insufficient token balance for proposal"));
        signals.proposeInitiativeWithLock("Test", "Description", 30_000 * 1e18, 6);
        vm.stopPrank();

        // Bob has 100k - should succeed
        vm.startPrank(_bob);
        _tokenERC20.approve(address(signals), 60_000 * 1e18);
        uint256 tokenId = signals.proposeInitiativeWithLock("Test", "Description", 60_000 * 1e18, 6);
        vm.stopPrank();

        assertEq(tokenId, 1);
        assertEq(signals.ownerOf(1), _bob);
    }

    function test_Propose_RequirementsIndependentFromThreshold() public {
        // MinBalance requirement (75k) is separate from proposalThreshold (50k)
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
        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), 50_000 * 1e18);
        vm.expectRevert(abi.encodeWithSelector(ISignals.ProposalRequirementsNotMet.selector, "Insufficient token balance for proposal"));
        signals.proposeInitiative("Test", "Description");
        vm.stopPrank();

        // Bob has 100k - meets both
        assertTrue(signals.canPropose(_bob));
    }

    function test_Integration_UserGainsBalanceCanPropose() public {
        ISignals.SignalsConfig memory config = defaultConfig;
        config.proposalRequirements = ISignals.ProposalRequirements({
            requirementType: ISignals.ProposalRequirementType.MinBalance,
            minBalance: 60_000 * 1e18,
            minHoldingDuration: 0
        });

        Signals signals = new Signals();
        signals.initialize(config);

        // Alice starts with 50k - cannot propose
        deal(address(_tokenERC20), _alice, 50_000 * 1e18);
        assertFalse(signals.canPropose(_alice));

        // Alice receives 20k more - now can propose
        deal(address(_tokenERC20), _alice, 70_000 * 1e18);
        assertTrue(signals.canPropose(_alice));

        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), 70_000 * 1e18);
        signals.proposeInitiative("Test", "Description");
        vm.stopPrank();
    }

    function test_Integration_UserLosesBalanceCannotPropose() public {
        ISignals.SignalsConfig memory config = defaultConfig;
        config.proposalRequirements = ISignals.ProposalRequirements({
            requirementType: ISignals.ProposalRequirementType.MinBalance,
            minBalance: 60_000 * 1e18,
            minHoldingDuration: 0
        });

        Signals signals = new Signals();
        signals.initialize(config);

        // Alice starts with 70k - can propose
        deal(address(_tokenERC20), _alice, 70_000 * 1e18);
        assertTrue(signals.canPropose(_alice));

        // Alice transfers away tokens, now has 40k - cannot propose
        vm.prank(_alice);
        _tokenERC20.transfer(_bob, 30_000 * 1e18);
        assertFalse(signals.canPropose(_alice));

        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), 40_000 * 1e18);
        vm.expectRevert(abi.encodeWithSelector(ISignals.ProposalRequirementsNotMet.selector, "Insufficient token balance for proposal"));
        signals.proposeInitiative("Test", "Description");
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Initialize_RevertsInvalidMinBalance() public {
        ISignals.SignalsConfig memory config = defaultConfig;
        config.proposalRequirements = ISignals.ProposalRequirements({
            requirementType: ISignals.ProposalRequirementType.MinBalance,
            minBalance: 0, // Invalid!
            minHoldingDuration: 0
        });

        Signals signals = new Signals();
        vm.expectRevert(abi.encodeWithSelector(ISignals.ProposalRequirementsNotMet.selector, "MinBalance must be greater than 0"));
        signals.initialize(config);
    }

    function test_Initialize_RevertsInvalidMinBalanceAndDuration_ZeroBalance() public {
        ISignals.SignalsConfig memory config = getERC20VotesConfig();
        config.proposalRequirements = ISignals.ProposalRequirements({
            requirementType: ISignals.ProposalRequirementType.MinBalanceAndDuration,
            minBalance: 0, // Invalid!
            minHoldingDuration: 10
        });

        Signals signals = new Signals();
        vm.expectRevert(abi.encodeWithSelector(ISignals.ProposalRequirementsNotMet.selector, "MinBalance must be greater than 0"));
        signals.initialize(config);
    }

    function test_Initialize_RevertsInvalidMinBalanceAndDuration_ZeroDuration() public {
        ISignals.SignalsConfig memory config = getERC20VotesConfig();
        config.proposalRequirements = ISignals.ProposalRequirements({
            requirementType: ISignals.ProposalRequirementType.MinBalanceAndDuration,
            minBalance: 10_000 * 1e18,
            minHoldingDuration: 0 // Invalid!
        });

        Signals signals = new Signals();
        vm.expectRevert(abi.encodeWithSelector(ISignals.ProposalRequirementsNotMet.selector, "MinHoldingDuration must be greater than 0"));
        signals.initialize(config);
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Propose_MinBalance_AfterLockingTokens() public {
        ISignals.SignalsConfig memory config = defaultConfig;
        config.proposalRequirements = ISignals.ProposalRequirements({
            requirementType: ISignals.ProposalRequirementType.MinBalance,
            minBalance: 40_000 * 1e18,
            minHoldingDuration: 0
        });

        Signals signals = new Signals();
        signals.initialize(config);
        _dealDefaultTokens();

        // Alice proposes with lock (locks 30k, leaving 20k)
        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), 50_000 * 1e18);
        signals.proposeInitiativeWithLock("First", "Description", 30_000 * 1e18, 6);

        // Alice now has 20k left - cannot propose again
        assertFalse(signals.canPropose(_alice));

        vm.expectRevert(abi.encodeWithSelector(ISignals.ProposalRequirementsNotMet.selector, "Insufficient token balance for proposal"));
        signals.proposeInitiative("Second", "Description");
        vm.stopPrank();
    }

    function test_CanPropose_MinBalanceAndDuration_WithERC20Votes() public {
        ISignals.SignalsConfig memory config = getERC20VotesConfig();
        config.proposalRequirements = ISignals.ProposalRequirements({
            requirementType: ISignals.ProposalRequirementType.MinBalanceAndDuration,
            minBalance: 75_000 * 1e18,
            minHoldingDuration: 50
        });

        Signals signals = new Signals();
        signals.initialize(config);
        _dealAndDelegateERC20Votes();

        // Roll forward to establish history
        vm.roll(block.number + 100);

        // Alice has 50k - doesn't meet balance requirement
        assertFalse(signals.canPropose(_alice));

        // Bob has 100k and held for 100 blocks - meets both
        assertTrue(signals.canPropose(_bob));
    }

    function test_CanPropose_MinBalanceAndDuration_WithStandardERC20_ReturnsFalse() public {
        // Standard ERC20 doesn't support checkpoints
        ISignals.SignalsConfig memory config = defaultConfig;
        config.proposalRequirements = ISignals.ProposalRequirements({
            requirementType: ISignals.ProposalRequirementType.MinBalanceAndDuration,
            minBalance: 40_000 * 1e18,
            minHoldingDuration: 10
        });

        Signals signals = new Signals();
        signals.initialize(config);
        _dealDefaultTokens();

        vm.roll(block.number + 20);

        // Even though Alice has balance, canPropose returns false (no checkpoint support)
        assertFalse(signals.canPropose(_alice));
    }
}
