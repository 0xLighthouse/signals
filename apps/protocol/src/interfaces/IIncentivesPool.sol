// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

/**
 * @title IIncentivesPool
 * @notice Interface for the IncentivesPool contract that manages board-wide participation rewards
 * @dev Incentives are calculated based on time-weighted support using the board's incentive curve
 */
interface IIncentivesPool {
    /**
     * @notice Configuration for the incentives pool
     *
     * @param token Address of the reward token
     * @param totalAmount Total tokens deposited by DAO
     * @param allocated Amount already allocated to accepted initiatives
     * @param maxRewardPerInitiative Maximum tokens to allocate per initiative acceptance
     * @param enabled Whether the pool is active
     */
    struct PoolConfig {
        address token;
        uint256 totalAmount;
        uint256 allocated;
        uint256 maxRewardPerInitiative;
        bool enabled;
    }

    // Events
    event PoolInitialized(address indexed token, uint256 amount, uint256 maxRewardPerInitiative);
    event PoolConfigUpdated(uint256 maxRewardPerInitiative);
    event PoolFunded(uint256 amount);
    event BoardApproved(address indexed board);
    event BoardRevoked(address indexed board);
    event IncentivesCalculated(
        address indexed board,
        uint256 indexed initiativeId,
        uint256 totalWeight,
        uint256 rewardAmount,
        uint256 supporterCount
    );
    event RewardsClaimed(address indexed board, uint256 indexed initiativeId, address indexed supporter, uint256 amount);

    // Errors

    /// @notice Thrown when attempting to initialize an already initialized pool
    error IncentivesPool_AlreadyInitialized();

    /// @notice Thrown when performing operations on uninitialized pool
    error IncentivesPool_NotInitialized();

    /// @notice Thrown when attempting to approve a board after it has already opened
    error IncentivesPool_BoardAlreadyOpened();

    /// @notice Thrown when pool has insufficient funds to allocate rewards
    error IncentivesPool_InsufficientFunds();

    /// @notice Thrown when non-approved board attempts protected operations
    error IncentivesPool_NotApprovedBoard();

    /// @notice Thrown when attempting to approve an already approved board
    error IncentivesPool_BoardAlreadyApproved();

    /// @notice Thrown when attempting operations on a board that is not approved
    error IncentivesPool_BoardNotApproved();

    /// @notice Thrown when caller is not authorized for the operation
    error IncentivesPool_NotAuthorized();

    /// @notice Thrown when incentives already calculated for an initiative
    error IncentivesPool_AlreadyCalculated();

    /// @notice Thrown when attempting to claim before calculation
    error IncentivesPool_NotCalculated();

    /// @notice Thrown when supporter has no rewards available to claim
    error IncentivesPool_NoRewards();

    /// @notice Thrown when token transfer fails
    error IncentivesPool_TransferFailed();

    /// @notice Thrown when pool configuration is invalid
    error IncentivesPool_InvalidConfiguration();

    /**
     * @notice Initialize the pool with token, amount, and max reward per initiative
     * @dev Can only be called once
     *
     * @param token Address of the reward token
     * @param amount Initial amount of tokens to deposit
     * @param maxRewardPerInitiative Maximum tokens to allocate per initiative
     */
    function initializePool(address token, uint256 amount, uint256 maxRewardPerInitiative) external;

    /**
     * @notice Approve a board to use this pool for incentives
     * @dev Can only be called by owner
     *
     * @param board Address of the Signals board to approve
     */
    function approveBoard(address board) external;

    /**
     * @notice Remove approval for a board
     * @dev Can only be called by owner. Does not affect already allocated rewards.
     *
     * @param board Address of the Signals board to revoke
     */
    function revokeBoard(address board) external;

    /**
     * @notice Update the maximum reward per initiative
     * @dev Can only be called by owner
     *
     * @param maxRewardPerInitiative New maximum reward per initiative
     */
    function setMaxRewardPerInitiative(uint256 maxRewardPerInitiative) external;

    /**
     * @notice Add more tokens to the pool
     * @dev Can be called anytime by owner
     *
     * @param amount Amount of tokens to add
     */
    function addToPool(uint256 amount) external;

    /**
     * @notice Calculate and allocate incentives for an accepted initiative
     * @dev Only callable by approved Signals boards when initiative is accepted
     *
     * @param initiativeId ID of the accepted initiative
     * @param boardOpensAt Timestamp when the board opened
     * @param acceptanceTimestamp Timestamp when initiative was accepted
     * @return rewardAmount Total amount of rewards allocated for this initiative
     */
    function calculateIncentives(uint256 initiativeId, uint256 boardOpensAt, uint256 acceptanceTimestamp)
        external
        returns (uint256 rewardAmount);

    /**
     * @notice Claim allocated rewards for a specific initiative and supporter
     * @dev Transfers rewards to the supporter and marks as claimed
     * @dev Can be called by Signals contract (auto-claim on redeem) or by supporter directly
     *
     * @param board Address of the Signals board
     * @param initiativeId ID of the initiative to claim rewards for
     * @param supporter Address of the supporter claiming rewards
     */
    function claimRewards(address board, uint256 initiativeId, address supporter) external;

    /**
     * @notice Preview rewards for a supporter on a specific initiative
     *
     * @param board Address of the Signals board
     * @param initiativeId ID of the initiative
     * @param supporter Address of the supporter
     * @return Amount of rewards claimable
     */
    function previewRewards(address board, uint256 initiativeId, address supporter) external view returns (uint256);

    /**
     * @notice Get rewards allocated to a supporter for a specific initiative
     *
     * @param board Address of the Signals board
     * @param initiativeId ID of the initiative
     * @param supporter Address of the supporter
     * @return Amount of rewards allocated (0 if already claimed)
     */
    function getSupporterRewards(address board, uint256 initiativeId, address supporter)
        external
        view
        returns (uint256);

    /**
     * @notice Get the current pool configuration
     *
     * @return PoolConfig struct with current pool state
     */
    function getPoolConfig() external view returns (PoolConfig memory);

    /**
     * @notice Get available pool balance (total - allocated)
     *
     * @return Amount of tokens available for future allocations
     */
    function getAvailablePoolBalance() external view returns (uint256);

    /**
     * @notice Check if distributions have been calculated for an initiative
     *
     * @param board Address of the Signals board
     * @param initiativeId ID of the initiative
     * @return True if distributions calculated, false otherwise
     */
    function isDistributionCalculated(address board, uint256 initiativeId) external view returns (bool);

    /**
     * @notice Get the total weight calculated for an initiative
     *
     * @param board Address of the Signals board
     * @param initiativeId ID of the initiative
     * @return Total weight sum for the initiative
     */
    function getInitiativeTotalWeight(address board, uint256 initiativeId) external view returns (uint256);

    /**
     * @notice Get the total reward pool allocated for an initiative
     *
     * @param board Address of the Signals board
     * @param initiativeId ID of the initiative
     * @return Amount of rewards allocated for this initiative
     */
    function getInitiativeRewardPool(address board, uint256 initiativeId) external view returns (uint256);

    /**
     * @notice Get all approved boards
     *
     * @return Array of approved board addresses
     */
    function getApprovedBoards() external view returns (address[] memory);

    /**
     * @notice Check if a board is approved
     *
     * @param board Address of the board to check
     * @return True if board is approved, false otherwise
     */
    function isBoardApproved(address board) external view returns (bool);
}
