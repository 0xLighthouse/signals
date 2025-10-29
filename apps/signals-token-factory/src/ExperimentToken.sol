// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/**
 * @title ExperimentToken
 * @notice ERC20 token that allows Edge City participants to claim rewards backed by
 *         an off-chain allowance signature. Each participant ID may only claim once.
 */
contract ExperimentToken is ERC20Burnable, ERC20Pausable, Ownable, EIP712 {
    /// @notice Details of a batch mint entry.
    struct BatchMintRequest {
        address to;
        uint256 amount;
    }

    address public allowanceSigner;
    mapping(uint256 => bool) private _claimed;

    bytes32 private constant CLAIM_TYPEHASH =
        keccak256("Claim(address to,uint256 participantId,uint256 amount,uint256 deadline)");

    error InvalidRecipient();
    error ParticipantAlreadyClaimed(uint256 participantId);
    error InvalidSignature();
    error SignatureExpired(uint256 deadline);
    error EmptyBatch();
    error ZeroAmount();

    event Claimed(address indexed account, uint256 indexed participantId, uint256 amountMinted);
    event BatchMinted(address indexed operator, address indexed to, uint256 amount, string reason);
    event AllowanceSignerUpdated(address indexed previousSigner, address indexed newSigner);

    constructor(
        string memory name_,
        string memory symbol_,
        address initialOwner_,
        uint256 initialSupply_,
        address allowanceSigner_
    ) ERC20(name_, symbol_) Ownable(initialOwner_) EIP712("ExperimentToken", "1") {
        address resolvedSigner = allowanceSigner_ == address(0) ? initialOwner_ : allowanceSigner_;
        allowanceSigner = resolvedSigner;

        if (initialSupply_ > 0) {
            _mint(initialOwner_, initialSupply_);
        }
    }

    /**
     * @notice Check whether a participant ID has already claimed.
     */
    function hasClaimed(uint256 participantId) external view returns (bool) {
        return _claimed[participantId];
    }

    /**
     * @notice Update the signer allowed to issue claim allowances.
     * @param newSigner Address of the new allowance signer (cannot be zero).
     */
    function setAllowanceSigner(address newSigner) external onlyOwner {
        if (newSigner == address(0)) revert InvalidRecipient();
        emit AllowanceSignerUpdated(allowanceSigner, newSigner);
        allowanceSigner = newSigner;
    }

    /**
     * @notice Claim tokens using an off-chain allowance signature.
     * @param to Recipient wallet that will receive the minted tokens.
     * @param participantId Edge City profile identifier tied to the allowance.
     * @param amount Amount of tokens authorized by the allowance.
     * @param deadline Timestamp after which the allowance is invalid.
     * @param signature EIP-712 signature from the allowance signer.
     */
    function claim(
        address to,
        uint256 participantId,
        uint256 amount,
        uint256 deadline,
        bytes calldata signature
    ) external {
        if (to == address(0)) revert InvalidRecipient();
        if (_claimed[participantId]) revert ParticipantAlreadyClaimed(participantId);
        if (block.timestamp > deadline) revert SignatureExpired(deadline);

        bytes32 digest = _hashTypedDataV4(
            keccak256(abi.encode(CLAIM_TYPEHASH, to, participantId, amount, deadline))
        );
        address recovered = ECDSA.recover(digest, signature);
        if (recovered != allowanceSigner) revert InvalidSignature();

        _claimed[participantId] = true;

        _mint(to, amount);
        emit Claimed(to, participantId, amount);
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
