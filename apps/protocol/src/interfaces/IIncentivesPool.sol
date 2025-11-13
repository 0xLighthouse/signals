// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {IIncentivizer} from "./IIncentivizer.sol";

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
    event RewardsPaidOut(
        address indexed board,
        uint256 indexed initiativeId,
        address indexed supporter,
        uint256 percentOfInitiativeRewards,
        uint256 remainingBoardBudget,
        uint256 amountPaid
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

    function approvedBoards(address board) external view returns (bool);
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
     * @param totalRewardPerInitiative_ Total reward per initiative for this board
     */
    function approveBoard(address board, uint256 boardMaxBudget_, uint256 totalRewardPerInitiative_)
        external;

    /**
     * @notice Remove approval for a board
     * @dev Can only be called by owner. Does not affect already allocated rewards.
     *
     * @param board Address of the Signals board to revoke
     */
    function revokeBoard(address board) external;

    /**
     * @notice Get the total reward per initiative for a board
     *
     * @param board Address of the board to get the total reward per initiative for
     * @return Total reward per initiative for the board
     */
    function totalRewardPerInitiative(address board) external view returns (uint256);

    /**
     * @notice Record how much a user participated so we can calculate incentives later
     * @dev Called by approved boards to track lock contributions
     *
     * @param initiativeId The ID of the initiative
     * @param lockId The ID of the lock
     * @param credit The amount of contributions added to the initiative
     */
    function addIncentivesCreditForLock(uint256 initiativeId, uint256 lockId, uint128 credit)
        external;
    /**
     * @notice Remove the incentive credits for a set of locks
     * @dev Called by approved boards to remove lock contributions
     *
     * @param initiativeId The ID of the initiative
     * @param lockIds The IDs of the locks
     */
    function removeIncentivesCreditForLocks(uint256 initiativeId, uint256[] calldata lockIds)
        external;
    /**
     * @notice Claim incentives for a set of locks
     * @dev Called by approved boards to distribute rewards
     *
     * @param initiativeId The ID of the initiative
     * @param lockIds The IDs of the locks
     * @param payee The address to pay the incentives to
     * @param config The incentives configuration for the board
     */
    function claimIncentivesForLocks(
        uint256 initiativeId,
        uint256[] memory lockIds,
        address payee,
        IIncentivizer.IncentivesConfig calldata config
    ) external;
}
