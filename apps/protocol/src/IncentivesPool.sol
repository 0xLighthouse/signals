// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "solady/src/utils/ReentrancyGuard.sol";

import {IIncentivesPool} from "./interfaces/IIncentivesPool.sol";

/**
 * @title IncentivesPool
 * @notice Manages board-wide participation rewards for Signals protocol
 * @dev Calculates time-weighted rewards based on the board's incentive curve
 * @dev Supports 1:M relationship - one pool can fund multiple boards
 *
 * @author Lighthouse Labs <https://lighthouse.cx>
 */
contract IncentivesPool is IIncentivesPool, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice The which ERC20 token is used as the reward
    address public immutable REWARD_TOKEN;

    /// @notice The total amount of rewards left in the pool
    uint256 public availableRewards;

    /// @notice The total amount of budgets for all approved boards
    uint256 public totalBoardBudgets;

    /// @notice The amount of rewards that have been distributed
    uint256 public distributedRewards;

    /// @notice Mapping of approved board addresses
    mapping(address => bool) public approvedBoards;

    /// @notice Mapping of board addresses to the maximum reward one person can claim per initiative
    mapping(address => uint256) public maxRewardPerInitiative;

    /// @notice Mapping of board addresses to the remaining budget for the board
    mapping(address => uint256) public boardRemainingBudget;

    /**
     * @notice Constructor
     */
    constructor(address REWARD_TOKEN_) Ownable(msg.sender) {
        // Validate reward token address
        if (REWARD_TOKEN_ == address(0)) {
            revert IIncentivesPool.IncentivesPool_InvalidConfiguration();
        }

        // Verify token implements ERC20 interface by attempting a basic call
        try IERC20(REWARD_TOKEN_).totalSupply() returns (uint256) {}
        catch {
            revert IIncentivesPool.IncentivesPool_InvalidConfiguration();
        }
        REWARD_TOKEN = REWARD_TOKEN_;
    }

    /// @inheritdoc IIncentivesPool
    function addFundsToPool(uint256 amount) external {
        if (amount == 0) revert IIncentivesPool.IncentivesPool_InvalidConfiguration();

        availableRewards += amount;

        // Transfer tokens from owner to this contract
        IERC20(REWARD_TOKEN).safeTransferFrom(msg.sender, address(this), amount);

        emit FundsAddedToPool(amount);
    }

    /// @inheritdoc IIncentivesPool
    function updateAvailableRewards(uint256 newBalance) external onlyOwner {
        if (
            newBalance <= availableRewards
                || newBalance > IERC20(REWARD_TOKEN).balanceOf(address(this))
        ) {
            revert IIncentivesPool.IncentivesPool_InvalidConfiguration();
        }

        availableRewards = newBalance;

        emit AvailableRewardsUpdated(newBalance);
    }

    /// @inheritdoc IIncentivesPool
    function approveBoard(address board, uint256 boardBudget_, uint256 maxRewardPerInitiative_)
        external
        onlyOwner
    {
        if (board == address(0)) {
            revert IIncentivesPool.IncentivesPool_InvalidConfiguration();
        }
        if (maxRewardPerInitiative_ == 0) {
            revert IIncentivesPool.IncentivesPool_InvalidConfiguration();
        }
        if (boardBudget_ == 0) {
            revert IIncentivesPool.IncentivesPool_InvalidConfiguration();
        }
        if (approvedBoards[board]) revert IIncentivesPool.IncentivesPool_BoardAlreadyApproved();
        // The requested budget is too big
        if (boardBudget_ > availableRewards - totalBoardBudgets) {
            revert IIncentivesPool.IncentivesPool_InsufficientFunds();
        }

        approvedBoards[board] = true;
        maxRewardPerInitiative[board] = maxRewardPerInitiative_;
        boardRemainingBudget[board] = boardBudget_;
        totalBoardBudgets += boardBudget_;

        emit BoardApproved(board);
    }

    /// @inheritdoc IIncentivesPool
    function revokeBoard(address board) external onlyOwner {
        if (!approvedBoards[board]) revert IIncentivesPool.IncentivesPool_BoardNotApproved();

        approvedBoards[board] = false;
        maxRewardPerInitiative[board] = 0;
        totalBoardBudgets -= boardRemainingBudget[board];
        boardRemainingBudget[board] = 0;

        emit BoardRevoked(board);
    }

    function claimRewards(uint256 initiativeId, address payee, uint256 amount)
        external
        nonReentrant
    {
        if (!approvedBoards[msg.sender]) revert IIncentivesPool.IncentivesPool_NotApprovedBoard();
        // If the rewards are too big, reduce to the max
        if (amount > maxRewardPerInitiative[msg.sender]) {
            amount = maxRewardPerInitiative[msg.sender];
        }
        if (amount > boardRemainingBudget[msg.sender]) {
            amount = boardRemainingBudget[msg.sender];
        }

        // NOTE: This should never happen, but just in case
        if (amount > availableRewards) revert IIncentivesPool.IncentivesPool_InsufficientFunds();

        boardRemainingBudget[msg.sender] -= amount;
        totalBoardBudgets -= amount;
        availableRewards -= amount;
        distributedRewards += amount;

        // Transfer rewards
        IERC20(REWARD_TOKEN).safeTransfer(payee, amount);

        emit RewardsClaimed(msg.sender, initiativeId, payee, amount);
    }

    /// @inheritdoc IIncentivesPool
    function isBoardApproved(address board) external view returns (bool) {
        return approvedBoards[board];
    }
}
