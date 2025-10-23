// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ExperimentTokenFactory, ExperimentToken} from "../src/ExperimentTokenFactory.sol";

contract ExperimentTokenFactoryTest is Test {
    ExperimentTokenFactory private factory;

    // Pre-computed participant identifiers
    uint256 private constant PARTICIPANT_A = 5461;
    uint256 private constant PARTICIPANT_B = 7021;

    bytes32 private proofElementForA;
    bytes32 private proofElementForB;
    bytes32 private merkleRoot;

    function setUp() public {
        factory = new ExperimentTokenFactory();

        bytes32 leafA = keccak256(abi.encodePacked(PARTICIPANT_A));
        bytes32 leafB = keccak256(abi.encodePacked(PARTICIPANT_B));

        proofElementForA = leafB;
        proofElementForB = leafA;
        merkleRoot = _hashPair(leafA, leafB);
    }

    function test_DeployInitialSupplyAndOwner() public {
        address owner = makeAddr("owner");
        uint256 supply = 1_000 ether;

        address tokenAddress = factory.deployToken(
            "Experiment Token",
            "EDGE",
            supply,
            owner,
            merkleRoot,
            100 ether,
            10 ether
        );
        ExperimentToken token = ExperimentToken(tokenAddress);

        assertEq(token.name(), "Experiment Token");
        assertEq(token.symbol(), "EDGE");
        assertEq(token.totalSupply(), supply);
        assertEq(token.balanceOf(owner), supply);
        assertEq(token.owner(), owner);
        assertEq(token.merkleRoot(), merkleRoot);
        assertEq(token.baseClaimAmount(), 100 ether);
        assertEq(token.bonusPerClaim(), 10 ether);
    }

    function test_ClaimMintsTokensForAllowlistedParticipant() public {
        address claimant = makeAddr("claimant");
        uint256 baseAmount = 200 ether;
        uint256 bonusAmount = 20 ether;

        ExperimentToken token = ExperimentToken(
            factory.deployToken(
                "Experiment Token",
                "EDGE",
                0,
                address(this),
                merkleRoot,
                baseAmount,
                bonusAmount
            )
        );

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = proofElementForA;

        token.claim(claimant, PARTICIPANT_A, proof);

        assertEq(token.balanceOf(claimant), baseAmount + bonusAmount);
        assertTrue(token.hasClaimed(PARTICIPANT_A));
    }

    function test_ClaimRevertsForDuplicateClaims() public {
        ExperimentToken token = ExperimentToken(
            factory.deployToken(
                "Experiment Token",
                "EDGE",
                0,
                address(this),
                merkleRoot,
                100 ether,
                10 ether
            )
        );

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = proofElementForA;

        token.claim(address(this), PARTICIPANT_A, proof);

        vm.expectRevert(abi.encodeWithSelector(ExperimentToken.ParticipantAlreadyClaimed.selector, PARTICIPANT_A));
        token.claim(address(this), PARTICIPANT_A, proof);
    }

    function test_ClaimRevertsForInvalidProof() public {
        ExperimentToken token = ExperimentToken(
            factory.deployToken(
                "Experiment Token",
                "EDGE",
                0,
                address(this),
                merkleRoot,
                100 ether,
                10 ether
            )
        );

        bytes32[] memory badProof = new bytes32[](1);
        badProof[0] = bytes32(uint256(123));

        vm.expectRevert(abi.encodeWithSelector(ExperimentToken.InvalidParticipantProof.selector, PARTICIPANT_B));
        token.claim(address(this), PARTICIPANT_B, badProof);
    }

    function test_ClaimRevertsForZeroRecipient() public {
        ExperimentToken token = ExperimentToken(
            factory.deployToken(
                "Experiment Token",
                "EDGE",
                0,
                address(this),
                merkleRoot,
                100 ether,
                10 ether
            )
        );

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = proofElementForA;

        vm.expectRevert(ExperimentToken.InvalidRecipient.selector);
        token.claim(address(0), PARTICIPANT_A, proof);
    }

    function test_PauseBlocksTransfers() public {
        address recipient = makeAddr("recipient");

        ExperimentToken token = ExperimentToken(
            factory.deployToken(
                "Experiment Token",
                "EDGE",
                1_000 ether,
                address(this),
                merkleRoot,
                100 ether,
                10 ether
            )
        );

        bool initialTransfer = token.transfer(recipient, 10 ether);
        assertTrue(initialTransfer);
        assertEq(token.balanceOf(recipient), 10 ether);

        token.pause();

        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        token.transfer(recipient, 1 ether);

        token.unpause();
        bool finalTransfer = token.transfer(recipient, 1 ether);
        assertTrue(finalTransfer);
        assertEq(token.balanceOf(recipient), 11 ether);
    }

    function test_UpdateClaimParameters() public {
        ExperimentToken token = ExperimentToken(
            factory.deployToken(
                "Experiment Token",
                "EDGE",
                0,
                address(this),
                merkleRoot,
                100 ether,
                10 ether
            )
        );

        token.setClaimParameters(500 ether, 50 ether);

        assertEq(token.baseClaimAmount(), 500 ether);
        assertEq(token.bonusPerClaim(), 50 ether);
    }

    function test_BatchMintMintsTokensAndEmits() public {
        ExperimentToken token = ExperimentToken(
            factory.deployToken(
                "Experiment Token",
                "EDGE",
                0,
                address(this),
                merkleRoot,
                100 ether,
                10 ether
            )
        );

        ExperimentToken.BatchMintRequest[] memory mints = new ExperimentToken.BatchMintRequest[](2);
        mints[0] = ExperimentToken.BatchMintRequest({to: makeAddr("alice"), amount: 50 ether});
        mints[1] = ExperimentToken.BatchMintRequest({to: makeAddr("bob"), amount: 75 ether});

        token.batchMint(mints, "Genesis drop");

        assertEq(token.balanceOf(mints[0].to), 50 ether);
        assertEq(token.balanceOf(mints[1].to), 75 ether);
    }

    function test_BatchMintRevertsForZeroAmount() public {
        ExperimentToken token = ExperimentToken(
            factory.deployToken(
                "Experiment Token",
                "EDGE",
                0,
                address(this),
                merkleRoot,
                100 ether,
                10 ether
            )
        );

        ExperimentToken.BatchMintRequest[] memory mints = new ExperimentToken.BatchMintRequest[](1);
        mints[0] = ExperimentToken.BatchMintRequest({to: makeAddr("zero"), amount: 0});

        vm.expectRevert(ExperimentToken.ZeroAmount.selector);
        token.batchMint(mints, "invalid");
    }

    function test_BatchMintRevertsForEmptyBatch() public {
        ExperimentToken token = ExperimentToken(
            factory.deployToken(
                "Experiment Token",
                "EDGE",
                0,
                address(this),
                merkleRoot,
                100 ether,
                10 ether
            )
        );

        ExperimentToken.BatchMintRequest[] memory emptyMints = new ExperimentToken.BatchMintRequest[](0);

        vm.expectRevert(ExperimentToken.EmptyBatch.selector);
        token.batchMint(emptyMints, "none");
    }

    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }
}
