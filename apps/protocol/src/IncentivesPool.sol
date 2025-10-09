// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "solady/src/utils/ReentrancyGuard.sol";

import {ISignals} from "./interfaces/ISignals.sol";
import {IIncentivesPool} from "./interfaces/IIncentivesPool.sol";

/**
 * @title IncentivesPool
 * @notice Manages board-wide participation rewards for Signals protocol
 * @dev Calculates time-weighted rewards based on the board's incentive curve
 * @dev Supports 1:M relationship - one pool can fund multiple boards
 *
 * @author Lighthouse Labs <https://lighthouse.cx>
 */
contract IncentivesPool is IIncentivesPool, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice The owner of this pool (typically the DAO)
    address public owner;

    /// @notice Pool configuration
    PoolConfig public poolConfig;

    /// @notice Mapping of approved board addresses
    mapping(address => bool) public approvedBoards;

    /// @notice Array of all approved boards for enumeration
    address[] public boardList;

    /// @notice Mapping from board => initiativeId => supporter => reward amount
    mapping(address => mapping(uint256 => mapping(address => uint256))) public supporterRewards;

    /// @notice Mapping from board => initiativeId => total rewards allocated for this initiative
    mapping(address => mapping(uint256 => uint256)) public initiativeRewardPool;

    /// @notice Mapping from board => initiativeId => whether distributions have been calculated
    mapping(address => mapping(uint256 => bool)) public distributionsCalculated;

    /// @notice Mapping from board => initiativeId => total weight sum
    mapping(address => mapping(uint256 => uint256)) public initiativeTotalWeight;

    /// @notice Modifier to check if caller is the owner
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotAuthorized();
        _;
    }

    /// @notice Modifier to check if caller is an approved board
    modifier onlyApprovedBoard() {
        if (!approvedBoards[msg.sender]) revert NotApprovedBoard();
        _;
    }

    /**
     * @notice Constructor
     */
    constructor() {
        owner = msg.sender;
    }

    /**
     * @notice Initialize the pool with token, amount, and max reward per initiative
     * @dev Can only be called once
     *
     * @param token Address of the reward token
     * @param amount Initial amount of tokens to deposit
     * @param maxRewardPerInitiative Maximum tokens to allocate per initiative
     */
    function initializePool(address token, uint256 amount, uint256 maxRewardPerInitiative)
        external
        onlyOwner
    {
        if (poolConfig.token != address(0)) revert PoolAlreadyInitialized();
        if (token == address(0)) revert InvalidConfiguration();
        if (amount == 0) revert InvalidConfiguration();
        if (maxRewardPerInitiative == 0) revert InvalidConfiguration();
        if (amount < maxRewardPerInitiative) revert InvalidConfiguration();

        poolConfig = PoolConfig({
            token: token,
            totalAmount: amount,
            allocated: 0,
            maxRewardPerInitiative: maxRewardPerInitiative,
            enabled: true
        });

        // Transfer tokens from owner to this contract
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit PoolInitialized(token, amount, maxRewardPerInitiative);
    }

    /**
     * @notice Approve a board to use this pool for incentives
     * @dev Can only be called by owner
     *
     * @param board Address of the Signals board to approve
     */
    function approveBoard(address board) external onlyOwner {
        if (board == address(0)) revert InvalidConfiguration();
        if (approvedBoards[board]) revert BoardAlreadyApproved();

        approvedBoards[board] = true;
        boardList.push(board);

        emit BoardApproved(board);
    }

    /**
     * @notice Remove approval for a board
     * @dev Can only be called by owner. Does not affect already allocated rewards.
     *
     * @param board Address of the Signals board to revoke
     */
    function revokeBoard(address board) external onlyOwner {
        if (!approvedBoards[board]) revert BoardNotApproved();

        approvedBoards[board] = false;

        emit BoardRevoked(board);
    }

    /**
     * @notice Update the maximum reward per initiative
     * @dev Can only be called by owner
     *
     * @param maxRewardPerInitiative New maximum reward per initiative
     */
    function setMaxRewardPerInitiative(uint256 maxRewardPerInitiative) external onlyOwner {
        if (poolConfig.token == address(0)) revert PoolNotInitialized();
        if (maxRewardPerInitiative == 0) revert InvalidConfiguration();
        if (maxRewardPerInitiative > poolConfig.totalAmount - poolConfig.allocated) {
            revert InvalidConfiguration();
        }

        poolConfig.maxRewardPerInitiative = maxRewardPerInitiative;
        emit PoolConfigUpdated(maxRewardPerInitiative);
    }

    /**
     * @notice Add more tokens to the pool
     * @dev Can be called anytime by owner
     *
     * @param amount Amount of tokens to add
     */
    function addToPool(uint256 amount) external onlyOwner {
        if (poolConfig.token == address(0)) revert PoolNotInitialized();
        if (amount == 0) revert InvalidConfiguration();

        poolConfig.totalAmount += amount;

        // Transfer tokens from owner to this contract
        IERC20(poolConfig.token).safeTransferFrom(msg.sender, address(this), amount);

        emit PoolFunded(amount);
    }

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
        onlyApprovedBoard
        returns (uint256 rewardAmount)
    {
        address board = msg.sender;

        // If pool not initialized or disabled, return 0 (non-blocking)
        if (poolConfig.token == address(0) || !poolConfig.enabled) {
            return 0;
        }

        // Check if already calculated
        if (distributionsCalculated[board][initiativeId]) revert AlreadyCalculated();

        // Check if board has opened
        if (block.timestamp < boardOpensAt) revert InvalidConfiguration();

        // Calculate reward allocation for this initiative
        uint256 availableBalance = poolConfig.totalAmount - poolConfig.allocated;
        rewardAmount = availableBalance < poolConfig.maxRewardPerInitiative
            ? availableBalance
            : poolConfig.maxRewardPerInitiative;

        // If no rewards available, return early (non-blocking)
        if (rewardAmount == 0) {
            distributionsCalculated[board][initiativeId] = true;
            return 0;
        }

        // Get board incentive configuration
        ISignals signals = ISignals(board);
        ISignals.BoardIncentives memory incentives = signals.boardIncentives();

        // If incentives not enabled, return early (non-blocking)
        if (!incentives.enabled) {
            distributionsCalculated[board][initiativeId] = true;
            return 0;
        }

        // Get all supporters for this initiative
        address[] memory supporters = signals.getSupporters(initiativeId);
        if (supporters.length == 0) {
            distributionsCalculated[board][initiativeId] = true;
            return 0;
        }

        // Calculate time-weighted rewards for each supporter
        uint256 totalWeight = 0;
        mapping(address => uint256) storage rewards = supporterRewards[board][initiativeId];

        // Get incentive curve parameter k (scaled by 1e18)
        uint256 k = incentives.curveParameters.length > 0 ? incentives.curveParameters[0] : 0;

        // Calculate weights for each supporter
        for (uint256 i = 0; i < supporters.length; i++) {
            address supporter = supporters[i];
            uint256 supporterWeight = _calculateSupporterWeight(
                signals, initiativeId, supporter, boardOpensAt, acceptanceTimestamp, k, incentives.curveType
            );

            if (supporterWeight > 0) {
                rewards[supporter] = supporterWeight;
                totalWeight += supporterWeight;
            }
        }

        // If no weight, return early (non-blocking)
        if (totalWeight == 0) {
            distributionsCalculated[board][initiativeId] = true;
            return 0;
        }

        // Allocate proportional rewards to each supporter
        for (uint256 i = 0; i < supporters.length; i++) {
            address supporter = supporters[i];
            uint256 supporterWeight = rewards[supporter];

            if (supporterWeight > 0) {
                // Calculate proportional share: (supporterWeight / totalWeight) * rewardAmount
                uint256 supporterReward = (supporterWeight * rewardAmount) / totalWeight;
                rewards[supporter] = supporterReward;
            }
        }

        // Update state
        poolConfig.allocated += rewardAmount;
        initiativeRewardPool[board][initiativeId] = rewardAmount;
        initiativeTotalWeight[board][initiativeId] = totalWeight;
        distributionsCalculated[board][initiativeId] = true;

        emit IncentivesCalculated(board, initiativeId, totalWeight, rewardAmount, supporters.length);

        return rewardAmount;
    }

    /**
     * @notice Calculate time-weighted support for a supporter
     * @dev Uses the board's incentive curve to calculate weight
     *
     * @param signals The Signals board contract
     * @param initiativeId ID of the initiative
     * @param supporter Address of the supporter
     * @param boardOpensAt Timestamp when board opened
     * @param acceptanceTimestamp Timestamp when initiative was accepted
     * @param k Decay rate parameter (scaled by 1e18)
     * @param curveType Type of curve (0 = linear)
     * @return Total weight for this supporter
     */
    function _calculateSupporterWeight(
        ISignals signals,
        uint256 initiativeId,
        address supporter,
        uint256 boardOpensAt,
        uint256 acceptanceTimestamp,
        uint256 k,
        uint256 curveType
    ) internal view returns (uint256) {
        // Get all lock positions for this supporter on this initiative
        uint256[] memory lockIds = signals.getLocksForSupporter(supporter);

        uint256 totalWeight = 0;
        uint256 duration = acceptanceTimestamp - boardOpensAt;

        // If acceptance happened immediately at board open, everyone gets equal weight
        if (duration == 0) {
            for (uint256 i = 0; i < lockIds.length; i++) {
                ISignals.TokenLock memory lock = signals.getTokenLock(lockIds[i]);
                if (lock.initiativeId == initiativeId && !lock.withdrawn) {
                    totalWeight += lock.tokenAmount;
                }
            }
            return totalWeight;
        }

        // Calculate time-weighted support for each lock position
        for (uint256 i = 0; i < lockIds.length; i++) {
            ISignals.TokenLock memory lock = signals.getTokenLock(lockIds[i]);

            // Only include locks for this initiative that haven't been withdrawn
            if (lock.initiativeId == initiativeId && !lock.withdrawn) {
                // Calculate normalized time: t = (lockTime - boardOpensAt) / (acceptTime - boardOpensAt)
                // Scaled by 1e18 for precision
                uint256 timeSinceBoardOpen = lock.created >= boardOpensAt ? lock.created - boardOpensAt : 0;
                uint256 t = (timeSinceBoardOpen * 1e18) / duration;

                // Calculate weight based on curve type
                uint256 weight;
                if (curveType == 0) {
                    // Linear decay: weight = lockAmount * (1 - k * t)
                    // Ensure we don't underflow: if k * t > 1e18, weight = 0
                    uint256 decay = (k * t) / 1e18;
                    if (decay >= 1e18) {
                        weight = 0;
                    } else {
                        weight = (lock.tokenAmount * (1e18 - decay)) / 1e18;
                    }
                } else {
                    // Future: exponential or other curves
                    // For now, default to no decay
                    weight = lock.tokenAmount;
                }

                totalWeight += weight;
            }
        }

        return totalWeight;
    }

    /**
     * @notice Claim allocated rewards for a specific initiative and supporter
     * @dev Transfers rewards to the supporter and marks as claimed
     * @dev Can be called by Signals contract (auto-claim on redeem) or by supporter directly
     *
     * @param board Address of the Signals board
     * @param initiativeId ID of the initiative to claim rewards for
     * @param supporter Address of the supporter claiming rewards
     */
    function claimRewards(address board, uint256 initiativeId, address supporter) external nonReentrant {
        if (!distributionsCalculated[board][initiativeId]) revert NotCalculated();

        uint256 reward = supporterRewards[board][initiativeId][supporter];
        if (reward == 0) revert NoRewardsAvailable();

        // Mark as claimed
        supporterRewards[board][initiativeId][supporter] = 0;

        // Transfer rewards
        IERC20(poolConfig.token).safeTransfer(supporter, reward);

        emit RewardsClaimed(board, initiativeId, supporter, reward);
    }

    /**
     * @notice Preview rewards for a supporter on a specific initiative
     *
     * @param board Address of the Signals board
     * @param initiativeId ID of the initiative
     * @param supporter Address of the supporter
     * @return Amount of rewards claimable
     */
    function previewRewards(address board, uint256 initiativeId, address supporter)
        external
        view
        returns (uint256)
    {
        return supporterRewards[board][initiativeId][supporter];
    }

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
        returns (uint256)
    {
        return supporterRewards[board][initiativeId][supporter];
    }

    /**
     * @notice Get the current pool configuration
     *
     * @return PoolConfig struct with current pool state
     */
    function getPoolConfig() external view returns (PoolConfig memory) {
        return poolConfig;
    }

    /**
     * @notice Get available pool balance (total - allocated)
     *
     * @return Amount of tokens available for future allocations
     */
    function getAvailablePoolBalance() external view returns (uint256) {
        return poolConfig.totalAmount - poolConfig.allocated;
    }

    /**
     * @notice Check if distributions have been calculated for an initiative
     *
     * @param board Address of the Signals board
     * @param initiativeId ID of the initiative
     * @return True if distributions calculated, false otherwise
     */
    function isDistributionCalculated(address board, uint256 initiativeId) external view returns (bool) {
        return distributionsCalculated[board][initiativeId];
    }

    /**
     * @notice Get the total weight calculated for an initiative
     *
     * @param board Address of the Signals board
     * @param initiativeId ID of the initiative
     * @return Total weight sum for the initiative
     */
    function getInitiativeTotalWeight(address board, uint256 initiativeId) external view returns (uint256) {
        return initiativeTotalWeight[board][initiativeId];
    }

    /**
     * @notice Get the total reward pool allocated for an initiative
     *
     * @param board Address of the Signals board
     * @param initiativeId ID of the initiative
     * @return Amount of rewards allocated for this initiative
     */
    function getInitiativeRewardPool(address board, uint256 initiativeId) external view returns (uint256) {
        return initiativeRewardPool[board][initiativeId];
    }

    /**
     * @notice Get all approved boards
     *
     * @return Array of approved board addresses
     */
    function getApprovedBoards() external view returns (address[] memory) {
        return boardList;
    }

    /**
     * @notice Check if a board is approved
     *
     * @param board Address of the board to check
     * @return True if board is approved, false otherwise
     */
    function isBoardApproved(address board) external view returns (bool) {
        return approvedBoards[board];
    }
}
