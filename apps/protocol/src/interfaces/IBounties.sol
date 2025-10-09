// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ISignals.sol";

/**
 * @title IBounties
 * @notice Interface for managing bounties on Signals initiatives
 * @dev Bounties are rewards that can be attached to initiatives with various conditions
 */
interface IBounties {
    /**
     * @notice Conditions that must be met for bounty distribution
     * @param NONE No special conditions - distribute immediately on acceptance
     * @param ACCEPTED_ON_OR_BEFORE_TIMESTAMP Bounty only valid if accepted before timestamp
     */
    enum Conditions {
        NONE,
        ACCEPTED_ON_OR_BEFORE_TIMESTAMP
    }

    /**
     * @notice Structure representing a bounty on an initiative
     *
     * @param initiativeId ID of the initiative this bounty is attached to
     * @param token ERC20 token to be distributed as bounty
     * @param amount Total amount of tokens in the bounty
     * @param paid Amount already paid out
     * @param refunded Amount refunded to contributor
     * @param expiresAt Timestamp when bounty expires (0 = no expiration)
     * @param contributor Address that contributed the bounty
     * @param terms Conditions that must be met for distribution
     */
    struct Bounty {
        uint256 initiativeId;
        IERC20 token;
        uint256 amount;
        uint256 paid;
        uint256 refunded;
        uint256 expiresAt;
        address contributor;
        Conditions terms;
    }

    event BountyAdded(
        uint256 indexed bountyId,
        uint256 indexed initiativeId,
        address indexed token,
        uint256 amount,
        uint256 expiresAt,
        Conditions terms
    );

    event BountyPaidOut(
        uint256 indexed bountyId, uint256 protocolAmount, uint256 voterAmount, uint256 treasuryAmount
    );

    event BountiesUpdated(uint256 version);

    event RewardClaimed(uint256 indexed initiativeId, address indexed supporter, uint256 amount);

    event BountyRefunded(uint256 indexed initiativeId, address indexed contributor, uint256 amount);

    // Errors

    /// @notice Thrown when total allocation percentages don't equal 100%
    error Bounties_InvalidAllocation();

    /// @notice Thrown when token is not registered in the token registry
    error Bounties_TokenNotRegistered();

    /// @notice Thrown when initiative ID is invalid
    error Bounties_InvalidInitiative();

    /// @notice Thrown when contributor has insufficient token balance
    error Bounties_InsufficientBalance();

    /// @notice Thrown when contributor has insufficient token allowance
    error Bounties_InsufficientAllowance();

    /// @notice Thrown when caller is not the Signals contract
    error Bounties_NotAuthorized();

    /// @notice Get the associated Signals contract
    /// @return The ISignals contract instance
    function signalsContract() external view returns (ISignals);

    /// @notice Get balance for an account and token
    /// @param account Address to check balance for
    /// @param token Token address to check
    /// @return Balance amount
    function balances(address account, address token) external view returns (uint256);

    /// @notice Get current configuration version
    /// @return Current version number
    function version() external view returns (uint256);

    /// @notice Get total number of bounties created
    /// @return Total bounty count
    function bountyCount() external view returns (uint256);

    /**
     * @notice Update the split allocations for bounty distribution
     * @param _allocations Array of [protocolFee, voterRewards, treasuryShare] (must sum to 100)
     * @param _receivers Array of addresses to receive each allocation
     */
    function updateSplits(uint256[3] memory _allocations, address[3] memory _receivers) external;

    /**
     * @notice Get configuration for a specific version
     * @param _version Version number to query
     * @return version Version number
     * @return allocations Split allocations for that version
     * @return receivers Receiver addresses for that version
     */
    function config(uint256 _version) external view returns (uint256, uint256[3] memory, address[3] memory);

    /**
     * @notice Get all bounties for an initiative aggregated by token
     * @param _initiativeId Initiative ID to query
     * @return tokens Array of token addresses
     * @return amounts Array of total amounts per token
     * @return expiredCount Number of expired bounties
     */
    function getBounties(uint256 _initiativeId) external view returns (address[] memory, uint256[] memory, uint256);

    /**
     * @notice Add a bounty to an initiative
     * @param _initiativeId Initiative ID to attach bounty to
     * @param _token Token address for the bounty
     * @param _amount Amount of tokens to bounty
     * @param _expiresAt Expiration timestamp (0 for no expiration)
     * @param _terms Conditions for bounty distribution
     */
    function addBounty(uint256 _initiativeId, address _token, uint256 _amount, uint256 _expiresAt, Conditions _terms)
        external
        payable;

    /**
     * @notice Preview rewards for a specific lock position
     * @param _initiativeId Initiative ID
     * @param _tokenId Lock position token ID
     * @return Estimated reward amount
     */
    function previewRewards(uint256 _initiativeId, uint256 _tokenId) external view returns (uint256);

    /**
     * @notice Handle initiative acceptance (called by Signals contract)
     * @param _initiativeId ID of accepted initiative
     */
    function handleInitiativeAccepted(uint256 _initiativeId) external;

    /**
     * @notice Handle initiative expiration (called by Signals contract)
     * @param _initiativeId ID of expired initiative
     */
    function handleInitiativeExpired(uint256 _initiativeId) external;
}
