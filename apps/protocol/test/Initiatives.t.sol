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

        ISignals.Metadata memory metadata = ISignals.Metadata({
            title: "Insufficient Tokens Initiative",
            body: "This initiative should fail due to insufficient tokens",
            attachments: new ISignals.Attachment[](0)
        });

        // Approve the contract to spend the tokens
        _tokenERC20.approve(address(signals), 40_000);

        // Charlie has InsufficientTokens, so this should revert
        vm.expectRevert(ISignals.Signals_InsufficientTokens.selector);
        signals.proposeInitiative(metadata);
    }

    /// @notice Test proposing an initiative with empty title or body
    function testProposeInitiativeWithEmptyTitle() public {
        // Mint tokens to the alice account
        deal(address(_tokenERC20), _alice, 200_000 * 1e18);

        // Propose an initiative
        vm.startPrank(_alice);

        // Attempt to propose with empty title
        ISignals.Metadata memory metadataEmptyTitle = ISignals.Metadata({
            title: "",
            body: "Some body",
            attachments: new ISignals.Attachment[](0)
        });
        vm.expectRevert(ISignals.Signals_EmptyTitleOrBody.selector);
        signals.proposeInitiative(metadataEmptyTitle);
    }

    function testProposeInitiativeWithLock() public {
        // Bob has enough tokens to propose an initiative with a lock
        vm.prank(_bob);

        uint256 amountToLock = 100_000 * 1e18;

        console.log("Bob balance:", _tokenERC20.balanceOf(_bob));
        console.log("Decimals:", _tokenERC20.decimals());

        ISignals.Metadata memory metadata = _metadata(1);
        console.log("Metadata title:", metadata.title);
        console.log("Metadata body:", metadata.body);

        // Approve the contract to spend the tokens
        vm.startPrank(_bob);
        _tokenERC20.approve(address(signals), amountToLock);
        signals.proposeInitiativeWithLock(_metadata(1), amountToLock, 1);
        vm.stopPrank();

        // Retrieve the initiative and check the details
        ISignals.Initiative memory initiative = signals.getInitiative(1);
        assertEq(uint256(initiative.state), uint256(ISignals.InitiativeState.Proposed));
        assertEq(address(initiative.proposer), _bob);

        // Retrieve the initiative metadata and check the details
        // ISignals.Metadata memory retrievedMetadata = signals.getInitiativeMetadata(1);
        // assertEq(retrievedMetadata.title, "Initiative 1");
        // assertEq(retrievedMetadata.body, "Description 1");

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

        ISignals.Metadata memory metadata = ISignals.Metadata({
            title: "Initiative 1",
            body: "Description 1",
            attachments: attachments
        });

        vm.expectEmit(true, true, true, true);
        emit ISignals.InitiativeProposed(1, _alice, metadata);

        signals.proposeInitiative(metadata);
        vm.stopPrank();

        // ISignals.Metadata memory retrievedMetadata = signals.getInitiativeMetadata(1);
        // assertEq(retrievedMetadata.attachments.length, 2);
        // assertEq(retrievedMetadata.attachments[0].uri, attachments[0].uri);
        // assertEq(retrievedMetadata.attachments[0].mimeType, attachments[0].mimeType);
        // assertEq(retrievedMetadata.attachments[0].description, attachments[0].description);
        // assertEq(retrievedMetadata.attachments[1].uri, attachments[1].uri);
        // assertEq(retrievedMetadata.attachments[1].mimeType, attachments[1].mimeType);
        // assertEq(retrievedMetadata.attachments[1].description, attachments[1].description);
    }
}
