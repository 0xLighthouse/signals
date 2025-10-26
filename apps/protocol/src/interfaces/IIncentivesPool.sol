// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

/**
 * @title IIncentivesPool
 * @notice Interface for the IncentivesPool contract that manages board-wide participation rewards
 * @dev Incentives are calculated based on time-weighted support using the board's incentive curve
 */
interface IIncentivesPool {
    // Events
    event FundsAddedToPool(uint256 amount);
    event BoardApproved(address indexed board);
    event BoardRevoked(address indexed board);
    event RewardsClaimed(
        address indexed board,
        uint256 indexed initiativeId,
        address indexed supporter,
        uint256 amount
    );
    event AvailableRewardsUpdated(uint256 newBalance);

    // Errors

    /// @notice Thrown when non-approved board attempts protected operations
    error IncentivesPool_NotApprovedBoard();

    /// @notice Thrown when attempting to approve an already approved board
    error IncentivesPool_BoardAlreadyApproved();

    /// @notice Thrown when attempting operations on a board that is not approved
    error IncentivesPool_BoardNotApproved();

    /// @notice Thrown when pool has insufficient funds to allocate rewards
    error IncentivesPool_InsufficientFunds();

    /// @notice Thrown when pool configuration is invalid
    error IncentivesPool_InvalidConfiguration();

    /**
     * @notice Add more tokens to the pool
     * @dev Can be called anytime by owner
     *
     * @param amount Amount of tokens to add
     */
    function addFundsToPool(uint256 amount) external;

    /**
     * @notice Update the available rewards balance if funds have been added externally
     * @dev Can only be called by owner
     *
     * @param newBalance New available rewards balance
     */
    function updateAvailableRewards(uint256 newBalance) external;

    /**
     * @notice Approve a board to use this pool for incentives
     * @dev Can only be called by owner
     *
     * @param board Address of the Signals board to approve
     * @param boardMaxBudget_ Maximum total budget allocated for this board
     * @param maxRewardPerInitiative_ Maximum reward per initiative for this board
     */
    function approveBoard(address board, uint256 boardMaxBudget_, uint256 maxRewardPerInitiative_)
        external;

    /**
     * @notice Remove approval for a board
     * @dev Can only be called by owner. Does not affect already allocated rewards.
     *
     * @param board Address of the Signals board to revoke
     */
    function revokeBoard(address board) external;

    /**
     * @notice Claim allocated rewards for a specific initiative and supporter
     * @dev Transfers rewards to the supporter and marks as claimed
     * @dev Can be called by Signals contract (auto-claim on redeem) or by supporter directly
     *
     * @param initiativeId ID of the initiative to claim rewards for
     * @param payee Address of the payee receiving rewards
     * @param amount Amount of rewards to claim
     */
    function claimRewards(uint256 initiativeId, address payee, uint256 amount) external;

    /**
     * @notice Check if a board is approved
     *
     * @param board Address of the board to check
     * @return True if board is approved, false otherwise
     */
    function isBoardApproved(address board) external view returns (bool);
}
