// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title ExperimentToken
 * @notice ERC20 token that allows allowlisted Edge City participants to claim rewards.
 *         Claims are verified against a Merkle tree of participant IDs and only minted once per ID.
 */
contract ExperimentToken is ERC20Burnable, ERC20Pausable, Ownable {
    /// @notice Details of a batch mint entry.
    struct BatchMintRequest {
        address to;
        uint256 amount;
    }

    bytes32 public merkleRoot;
    uint256 public baseClaimAmount;
    uint256 public bonusPerClaim;

    mapping(uint256 => bool) private _claimed;

    error InvalidRecipient();
    error ParticipantAlreadyClaimed(uint256 participantId);
    error InvalidParticipantProof(uint256 participantId);
    error ClaimAmountZero();
    error EmptyBatch();
    error ZeroAmount();

    event MerkleRootUpdated(bytes32 indexed previousRoot, bytes32 indexed newRoot);
    event ClaimParametersUpdated(uint256 baseClaimAmount, uint256 bonusPerClaim);
    event Claimed(address indexed account, uint256 indexed participantId, uint256 amountMinted);
    event BatchMinted(address indexed operator, address indexed to, uint256 amount, string reason);

    constructor(
        string memory name_,
        string memory symbol_,
        address initialOwner_,
        uint256 initialSupply_,
        bytes32 merkleRoot_,
        uint256 baseClaimAmount_,
        uint256 bonusPerClaim_
    ) ERC20(name_, symbol_) Ownable(initialOwner_) {
        merkleRoot = merkleRoot_;
        baseClaimAmount = baseClaimAmount_;
        bonusPerClaim = bonusPerClaim_;

        if (initialSupply_ > 0) {
            _mint(initialOwner_, initialSupply_);
        }
    }

    /**
     * @notice Update the Merkle root used to validate participant IDs.
     */
    function setMerkleRoot(bytes32 newRoot) external onlyOwner {
        emit MerkleRootUpdated(merkleRoot, newRoot);
        merkleRoot = newRoot;
    }

    /**
     * @notice Adjust the base claim amount and bonus per claim.
     */
    function setClaimParameters(uint256 baseAmount, uint256 bonusAmount) external onlyOwner {
        baseClaimAmount = baseAmount;
        bonusPerClaim = bonusAmount;
        emit ClaimParametersUpdated(baseAmount, bonusAmount);
    }

    /**
     * @notice Check whether a participant ID has already claimed.
     */
    function hasClaimed(uint256 participantId) external view returns (bool) {
        return _claimed[participantId];
    }

    /**
     * @notice Claim tokens for an allowlisted participant.
     * @param to Recipient wallet that will receive the minted tokens.
     * @param participantId Edge City profile identifier proved in the Merkle tree.
     * @param proof Merkle proof demonstrating `participantId` is in the current allowlist.
     */
    function claim(address to, uint256 participantId, bytes32[] calldata proof) external {
        if (to == address(0)) revert InvalidRecipient();
        if (_claimed[participantId]) revert ParticipantAlreadyClaimed(participantId);

        bytes32 leaf = keccak256(abi.encodePacked(participantId));
        bool isValid = MerkleProof.verify(proof, merkleRoot, leaf);
        if (!isValid) revert InvalidParticipantProof(participantId);

        _claimed[participantId] = true;

        uint256 mintAmount = baseClaimAmount + bonusPerClaim;
        if (mintAmount == 0) revert ClaimAmountZero();

        _mint(to, mintAmount);
        emit Claimed(to, participantId, mintAmount);
    }

    /**
     * @notice Mint arbitrary amounts to multiple recipients. Restricted to the contract owner.
     * @param mints Batch entries specifying recipients and amounts.
     * @param reason Free-form string describing the distribution rationale.
     */
    function batchMint(BatchMintRequest[] calldata mints, string calldata reason) external onlyOwner {
        uint256 length = mints.length;
        if (length == 0) revert EmptyBatch();

        for (uint256 i = 0; i < length; i++) {
            BatchMintRequest calldata entry = mints[i];
            if (entry.to == address(0)) revert InvalidRecipient();
            if (entry.amount == 0) revert ZeroAmount();

            _mint(entry.to, entry.amount);
            emit BatchMinted(msg.sender, entry.to, entry.amount, reason);
        }
    }

    /**
     * @notice Pauses all token transfers, mints, and burns.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Resumes token transfers, mints, and burns.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Resolve multiple inheritance of `_update`.
     */
    function _update(address from, address to, uint256 value) internal virtual override(ERC20, ERC20Pausable) {
        super._update(from, to, value);
    }
}
