// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/StdUtils.sol";

import "solady/test/utils/mocks/MockERC20.sol";

import "@openzeppelin/contracts/utils/Strings.sol";

import {Signals} from "../src/Signals.sol";
import {SignalsHarness} from "./utils/SignalsHarness.sol";
import {ISignals} from "../src/interfaces/ISignals.sol";

contract InitiativesTest is Test, SignalsHarness {
    Signals signals;

    function setUp() public {
        signals = deploySignals(defaultConfig);
        dealMockTokens();
    }

    function testRevertProposeInitiativeWithInsufficientTokens() public {
        // Impersonate Charlie
        vm.startPrank(_charlie);

        string memory title = "Insufficient Tokens Initiative";
        string memory body = "This initiative should fail due to insufficient tokens";

        // Approve the contract to spend the tokens
        _tokenERC20.approve(address(signals), 40_000);

        // Charlie has InsufficientTokens, so this should revert
        vm.expectRevert(ISignals.Signals_ParticipantInsufficientBalance.selector);
        signals.proposeInitiative(title, body, new ISignals.Attachment[](0));
    }

    /// @notice Test proposing an initiative with empty title or body
    function testProposeInitiativeWithEmptyTitleOrBody() public {
        // Mint tokens to the alice account
        deal(address(_tokenERC20), _alice, 200_000 * 1e18);

        // Propose an initiative
        vm.startPrank(_alice);

        // Attempt to propose with empty title
        vm.expectRevert(ISignals.Signals_EmptyTitle.selector);
        signals.proposeInitiative("", "Some body", new ISignals.Attachment[](0));

        // Attempt to propose with empty body
        vm.expectRevert(ISignals.Signals_EmptyBody.selector);
        signals.proposeInitiative("Some title", "", new ISignals.Attachment[](0));
    }

    /**
     * @notice Test proposing multiple initiatives up to the cap
     *
     *  - TODO: Cap {n} of initiatives proposed in a given period
     *  - TODO: Bonus feature
     *  - TODO: Bonus feature
     *  - TODO: Bonus feature
     */
    // function testProposeMultipleInitiatives() public {
    //   vm.startPrank(alice);

    //   // Load the Signals contract instance
    //   Signals _instance = Signals(instance);

    //   // Propose initiatives up to the cap (5 in this case)
    //   for (uint i = 0; i < 5; i++) {
    //       string memory title = string(abi.encodePacked("Initiative ", Strings.toString(i+1)));
    //       string memory body = string(abi.encodePacked("Description for initiative ", Strings.toString(i+1)));
    //       _instance.proposeInitiative(title, body);
    //   }

    //   // Attempt to propose one more initiative (should fail)
    //   vm.expectRevert(abi.encodeWithSelector(Signals.ProposalCapReached.selector));
    //   _instance.proposeInitiative("Extra Initiative", "This should fail");

    //   vm.stopPrank();
    // }

    function testProposeInitiativeWithLock() public {
        // Bob has enough tokens to propose an initiative with a lock
        vm.prank(_bob);

        string memory title = "Test Proposing Initiative with Locks";
        string memory body = "This initiative should be proposed with a lock";

        uint256 amountToLock = 100_000 * 1e18;

        console.log("Bob balance:", _tokenERC20.balanceOf(_bob));
        console.log("Decimals:", _tokenERC20.decimals());

        // Approve the contract to spend the tokens
        vm.startPrank(_bob);
        _tokenERC20.approve(address(signals), amountToLock);
        signals.proposeInitiativeWithLock(
            title, body, new ISignals.Attachment[](0), amountToLock, 1
        );
        vm.stopPrank();

        // Retrieve the initiative and check the details
        ISignals.Initiative memory initiative = signals.getInitiative(1);
        assertEq(uint256(initiative.state), uint256(ISignals.InitiativeState.Proposed));
        assertEq(initiative.title, title);
        assertEq(initiative.body, body);
        assertEq(address(initiative.proposer), _bob);

        // The weight should be equal to the amount of tokens locked
        uint256 weight = signals.getWeightAt(1, block.timestamp);
        assertEq(weight, amountToLock);
    }

    function testProposeInitiativePersistsAttachments() public {
        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), defaultConfig.proposerRequirements.minBalance);

        ISignals.Attachment[] memory attachments = new ISignals.Attachment[](2);
        attachments[0] = ISignals.Attachment({
            uri: "ipfs://proposal",
            mimeType: "application/pdf",
            description: "Full specification"
        });
        attachments[1] = ISignals.Attachment({
            uri: "https://example.com/thread",
            mimeType: "text/html",
            description: "Community discussion"
        });

        vm.expectEmit(true, true, true, true);
        emit ISignals.InitiativeProposed(1, _alice, "Initiative 1", "Description 1", attachments);

        signals.proposeInitiative("Initiative 1", "Description 1", attachments);
        vm.stopPrank();

        ISignals.Initiative memory initiative = signals.getInitiative(1);
        assertEq(initiative.attachments.length, 2);
        assertEq(initiative.attachments[0].uri, attachments[0].uri);
        assertEq(initiative.attachments[0].mimeType, attachments[0].mimeType);
        assertEq(initiative.attachments[0].description, attachments[0].description);
        assertEq(initiative.attachments[1].uri, attachments[1].uri);
        assertEq(initiative.attachments[1].mimeType, attachments[1].mimeType);
        assertEq(initiative.attachments[1].description, attachments[1].description);
    }
}
