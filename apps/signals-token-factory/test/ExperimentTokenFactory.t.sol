// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ExperimentTokenFactory, ExperimentToken} from "../src/ExperimentTokenFactory.sol";

contract ExperimentTokenFactoryTest is Test {
    ExperimentTokenFactory private factory;

    uint256 private constant PARTICIPANT_A = 5461;
    uint256 private constant PARTICIPANT_B = 7021;
    uint256 private constant SIGNER_PK = 0xA11CE;
    address private immutable SIGNER = vm.addr(SIGNER_PK);

    bytes32 private constant CLAIM_TYPEHASH =
        keccak256("Claim(address to,uint256 participantId,uint256 amount,uint256 deadline)");

    function setUp() public {
        factory = new ExperimentTokenFactory(SIGNER);
    }

    function test_DeployInitialSupplyAndOwner() public {
        address owner = makeAddr("owner");

        ExperimentToken token = ExperimentToken(factory.deployToken("Experiment Token", "EDGE"));

        assertEq(token.name(), "Experiment Token");
        assertEq(token.symbol(), "EDGE");
        assertEq(token.owner(), owner);
        assertEq(token.allowanceSigner(), SIGNER);
    }

    function test_DeployWithExplicitSigner() public {
        address owner = makeAddr("owner");
        address customSigner = makeAddr("signer");

        ExperimentToken token = ExperimentToken(factory.deployToken("Experiment Token", "EDGE"));

        assertEq(token.owner(), owner);
        assertEq(token.allowanceSigner(), customSigner);
    }

    function test_ClaimMintsTokensWithValidSignature() public {
        ExperimentToken token = ExperimentToken(factory.deployToken("Experiment Token", "EDGE"));

        address claimant = makeAddr("claimant");
        uint256 amount = 200 ether;
        uint256 deadline = block.timestamp + 1 days;

        bytes memory signature = _sign(token, claimant, PARTICIPANT_A, amount, deadline);

        token.claim(claimant, PARTICIPANT_A, amount, deadline, signature);

        assertEq(token.balanceOf(claimant), amount);
        assertTrue(token.hasClaimed(PARTICIPANT_A));
    }

    function test_ClaimRevertsForDuplicateClaims() public {
        ExperimentToken token = ExperimentToken(factory.deployToken("Experiment Token", "EDGE"));

        address claimant = makeAddr("claimant");
        uint256 amount = 100 ether;
        uint256 deadline = block.timestamp + 1 days;
        bytes memory signature = _sign(token, claimant, PARTICIPANT_A, amount, deadline);

        token.claim(claimant, PARTICIPANT_A, amount, deadline, signature);

        vm.expectRevert(abi.encodeWithSelector(ExperimentToken.ParticipantAlreadyClaimed.selector, PARTICIPANT_A));
        token.claim(claimant, PARTICIPANT_A, amount, deadline, signature);
    }

    function test_ClaimRevertsForInvalidSignature() public {
        ExperimentToken token = ExperimentToken(factory.deployToken("Experiment Token", "EDGE"));

        address claimant = makeAddr("claimant");
        uint256 amount = 100 ether;
        uint256 deadline = block.timestamp + 1 days;
        bytes memory signature = _signWithKey(token, claimant, PARTICIPANT_A, amount, deadline, 0xBEEF);

        vm.expectRevert(ExperimentToken.InvalidSignature.selector);
        token.claim(claimant, PARTICIPANT_A, amount, deadline, signature);
    }

    function test_ClaimRevertsWhenExpired() public {
        ExperimentToken token = ExperimentToken(factory.deployToken("Experiment Token", "EDGE"));

        address claimant = makeAddr("claimant");
        uint256 amount = 100 ether;
        uint256 deadline = block.timestamp - 1;
        bytes memory signature = _sign(token, claimant, PARTICIPANT_A, amount, deadline);

        vm.expectRevert(abi.encodeWithSelector(ExperimentToken.SignatureExpired.selector, deadline));
        token.claim(claimant, PARTICIPANT_A, amount, deadline, signature);
    }

    function test_ClaimRevertsForZeroRecipient() public {
        ExperimentToken token = ExperimentToken(factory.deployToken("Experiment Token", "EDGE"));

        uint256 amount = 100 ether;
        uint256 deadline = block.timestamp + 1 days;
        bytes memory signature = _sign(token, address(0), PARTICIPANT_A, amount, deadline);

        vm.expectRevert(ExperimentToken.InvalidRecipient.selector);
        token.claim(address(0), PARTICIPANT_A, amount, deadline, signature);
    }

    function test_PauseBlocksTransfers() public {
        ExperimentToken token = ExperimentToken(factory.deployToken("Experiment Token", "EDGE"));

        address recipient = makeAddr("recipient");

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

    function test_SetAllowanceSigner() public {
        ExperimentToken token = ExperimentToken(factory.deployToken("Experiment Token", "EDGE"));

        address newSigner = makeAddr("new-signer");

        token.setAllowanceSigner(newSigner);
        assertEq(token.allowanceSigner(), newSigner);
    }

    function test_BatchMintMintsTokensAndEmits() public {
        ExperimentToken token = ExperimentToken(factory.deployToken("Experiment Token", "EDGE"));

        ExperimentToken.BatchMintRequest[] memory mints = new ExperimentToken.BatchMintRequest[](2);
        mints[0] = ExperimentToken.BatchMintRequest({to: makeAddr("alice"), amount: 50 ether});
        mints[1] = ExperimentToken.BatchMintRequest({to: makeAddr("bob"), amount: 75 ether});

        token.batchMint(mints, "Genesis drop");

        assertEq(token.balanceOf(mints[0].to), 50 ether);
        assertEq(token.balanceOf(mints[1].to), 75 ether);
    }

    function test_BatchMintRevertsForZeroAmount() public {
        ExperimentToken token = ExperimentToken(factory.deployToken("Experiment Token", "EDGE"));

        ExperimentToken.BatchMintRequest[] memory mints = new ExperimentToken.BatchMintRequest[](1);
        mints[0] = ExperimentToken.BatchMintRequest({to: makeAddr("zero"), amount: 0});

        vm.expectRevert(ExperimentToken.ZeroAmount.selector);
        token.batchMint(mints, "invalid");
    }

    function test_BatchMintRevertsForEmptyBatch() public {
        ExperimentToken token = ExperimentToken(factory.deployToken("Experiment Token", "EDGE"));

        ExperimentToken.BatchMintRequest[] memory emptyMints = new ExperimentToken.BatchMintRequest[](0);

        vm.expectRevert(ExperimentToken.EmptyBatch.selector);
        token.batchMint(emptyMints, "none");
    }

    function _sign(ExperimentToken token, address to, uint256 participantId, uint256 amount, uint256 deadline)
        private
        view
        returns (bytes memory)
    {
        return _signWithKey(token, to, participantId, amount, deadline, SIGNER_PK);
    }

    function _signWithKey(
        ExperimentToken token,
        address to,
        uint256 participantId,
        uint256 amount,
        uint256 deadline,
        uint256 privateKey
    ) private view returns (bytes memory) {
        bytes32 digest = _digest(address(token), to, participantId, amount, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _digest(address token, address to, uint256 participantId, uint256 amount, uint256 deadline)
        private
        view
        returns (bytes32)
    {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("ExperimentToken")),
                keccak256(bytes("1")),
                block.chainid,
                token
            )
        );

        bytes32 structHash = keccak256(abi.encode(CLAIM_TYPEHASH, to, participantId, amount, deadline));

        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }
}
