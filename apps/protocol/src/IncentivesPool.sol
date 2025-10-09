// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "solady/src/utils/ReentrancyGuard.sol";

import {ISignals} from "./interfaces/ISignals.sol";
import {IIncentivesPool} from "./interfaces/IIncentivesPool.sol";

import {SignalsConstants} from "./utils/Constants.sol";

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
        if (msg.sender != owner) revert IIncentivesPool.IncentivesPool_NotAuthorized();
        _;
    }

    /// @notice Modifier to check if caller is an approved board
    modifier onlyApprovedBoard() {
        if (!approvedBoards[msg.sender]) revert IIncentivesPool.IncentivesPool_NotApprovedBoard();
        _;
    }

    /**
     * @notice Constructor
     */
    constructor() {
        owner = msg.sender;
    }

    /// @inheritdoc IIncentivesPool
    function initializePool(address token, uint256 amount, uint256 maxRewardPerInitiative)
        external
        onlyOwner
    {
        if (poolConfig.token != SignalsConstants.ADDRESS_ZERO) {
            revert IIncentivesPool.IncentivesPool_AlreadyInitialized();
        }
        if (token == SignalsConstants.ADDRESS_ZERO) {
            revert IIncentivesPool.IncentivesPool_InvalidConfiguration();
        }
        if (amount == 0) revert IIncentivesPool.IncentivesPool_InvalidConfiguration();
        if (maxRewardPerInitiative == 0) revert IIncentivesPool.IncentivesPool_InvalidConfiguration();
        if (amount < maxRewardPerInitiative) revert IIncentivesPool.IncentivesPool_InvalidConfiguration();

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

    /// @inheritdoc IIncentivesPool
    function approveBoard(address board) external onlyOwner {
        if (board == SignalsConstants.ADDRESS_ZERO) {
            revert IIncentivesPool.IncentivesPool_InvalidConfiguration();
        }
        if (approvedBoards[board]) revert IIncentivesPool.IncentivesPool_BoardAlreadyApproved();

        approvedBoards[board] = true;
        boardList.push(board);

        emit BoardApproved(board);
    }

    /// @inheritdoc IIncentivesPool
    function revokeBoard(address board) external onlyOwner {
        if (!approvedBoards[board]) revert IIncentivesPool.IncentivesPool_BoardNotApproved();

        approvedBoards[board] = false;

        emit BoardRevoked(board);
    }

    /// @inheritdoc IIncentivesPool
    function setMaxRewardPerInitiative(uint256 maxRewardPerInitiative) external onlyOwner {
        if (poolConfig.token == SignalsConstants.ADDRESS_ZERO) {
            revert IIncentivesPool.IncentivesPool_NotInitialized();
        }
        if (maxRewardPerInitiative == 0) revert IIncentivesPool.IncentivesPool_InvalidConfiguration();
        if (maxRewardPerInitiative > poolConfig.totalAmount - poolConfig.allocated) {
            revert IIncentivesPool.IncentivesPool_InvalidConfiguration();
        }

        poolConfig.maxRewardPerInitiative = maxRewardPerInitiative;
        emit PoolConfigUpdated(maxRewardPerInitiative);
    }

    /// @inheritdoc IIncentivesPool
    function addToPool(uint256 amount) external onlyOwner {
        if (poolConfig.token == SignalsConstants.ADDRESS_ZERO) {
            revert IIncentivesPool.IncentivesPool_NotInitialized();
        }
        if (amount == 0) revert IIncentivesPool.IncentivesPool_InvalidConfiguration();

        poolConfig.totalAmount += amount;

        // Transfer tokens from owner to this contract
        IERC20(poolConfig.token).safeTransferFrom(msg.sender, address(this), amount);

        emit PoolFunded(amount);
    }

    /// @inheritdoc IIncentivesPool
    function calculateIncentives(uint256 initiativeId, uint256 boardOpensAt, uint256 acceptanceTimestamp)
        external
        onlyApprovedBoard
        returns (uint256 rewardAmount)
    {
        address board = msg.sender;

        // If pool not initialized or disabled, return 0 (non-blocking)
        if (poolConfig.token == SignalsConstants.ADDRESS_ZERO || !poolConfig.enabled) {
            return 0;
        }

        // Check if already calculated
        if (distributionsCalculated[board][initiativeId]) revert IIncentivesPool.IncentivesPool_AlreadyCalculated();

        // Check if board has opened
        if (block.timestamp < boardOpensAt) revert IIncentivesPool.IncentivesPool_InvalidConfiguration();

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

    /// @inheritdoc IIncentivesPool
    function claimRewards(address board, uint256 initiativeId, address supporter) external nonReentrant {
        if (!distributionsCalculated[board][initiativeId]) revert IIncentivesPool.IncentivesPool_NotCalculated();

        uint256 reward = supporterRewards[board][initiativeId][supporter];
        if (reward == 0) revert IIncentivesPool.IncentivesPool_NoRewards();

        // Mark as claimed
        supporterRewards[board][initiativeId][supporter] = 0;

        // Transfer rewards
        IERC20(poolConfig.token).safeTransfer(supporter, reward);

        emit RewardsClaimed(board, initiativeId, supporter, reward);
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
        // Early supporters get more weight, later supporters get less
        for (uint256 i = 0; i < lockIds.length; i++) {
            ISignals.TokenLock memory lock = signals.getTokenLock(lockIds[i]);

            // Only include locks for this initiative that haven't been withdrawn
            if (lock.initiativeId == initiativeId && !lock.withdrawn) {
                // Calculate normalized time: t = (lockTime - boardOpensAt) / (acceptTime - boardOpensAt)
                // This gives a value between 0 (locked at board open) and 1e18 (locked at acceptance)
                // Example: Board opens at T=0, initiative accepted at T=100, lock at T=25
                //   timeSinceBoardOpen = 25
                //   t = (25 * 1e18) / 100 = 0.25e18 (25% of the way through)
                uint256 timeSinceBoardOpen = lock.created >= boardOpensAt ? lock.created - boardOpensAt : 0;
                uint256 t = (timeSinceBoardOpen * SignalsConstants.PRECISION) / duration;

                // Calculate weight based on curve type
                uint256 weight;
                if (curveType == SignalsConstants.INCENTIVE_CURVE_LINEAR) {
                    // Linear decay: weight = lockAmount * (1 - k * t)
                    // k is the decay rate (e.g., 1e18 means full decay from 100% to 0%)
                    // Example: k=1e18, t=0.5e18 (locked halfway through)
                    //   decay = (1e18 * 0.5e18) / 1e18 = 0.5e18
                    //   weight = lockAmount * (1e18 - 0.5e18) / 1e18 = lockAmount * 50%
                    // Early supporters (t≈0) get full weight, late supporters (t≈1) get minimal weight
                    uint256 decay = (k * t) / SignalsConstants.PRECISION;
                    if (decay >= SignalsConstants.PRECISION) {
                        // Decay rate too high - no weight for this lock
                        weight = 0;
                    } else {
                        // Apply time-weighted decay
                        weight = (lock.tokenAmount * (SignalsConstants.PRECISION - decay)) / SignalsConstants.PRECISION;
                    }
                } else {
                    // Future: exponential or other curves
                    // For now, default to no decay (all supporters weighted equally)
                    weight = lock.tokenAmount;
                }

                totalWeight += weight;
            }
        }

        return totalWeight;
    }

    /// @inheritdoc IIncentivesPool
    function previewRewards(address board, uint256 initiativeId, address supporter)
        external
        view
        returns (uint256)
    {
        return supporterRewards[board][initiativeId][supporter];
    }

    /// @inheritdoc IIncentivesPool
    function getSupporterRewards(address board, uint256 initiativeId, address supporter)
        external
        view
        returns (uint256)
    {
        return supporterRewards[board][initiativeId][supporter];
    }

    /// @inheritdoc IIncentivesPool
    function getPoolConfig() external view returns (PoolConfig memory) {
        return poolConfig;
    }

    /// @inheritdoc IIncentivesPool
    function getAvailablePoolBalance() external view returns (uint256) {
        return poolConfig.totalAmount - poolConfig.allocated;
    }

    /// @inheritdoc IIncentivesPool
    function isDistributionCalculated(address board, uint256 initiativeId) external view returns (bool) {
        return distributionsCalculated[board][initiativeId];
    }

    /// @inheritdoc IIncentivesPool
    function getInitiativeTotalWeight(address board, uint256 initiativeId) external view returns (uint256) {
        return initiativeTotalWeight[board][initiativeId];
    }

    /// @inheritdoc IIncentivesPool
    function getInitiativeRewardPool(address board, uint256 initiativeId) external view returns (uint256) {
        return initiativeRewardPool[board][initiativeId];
    }

    /// @inheritdoc IIncentivesPool
    function getApprovedBoards() external view returns (address[] memory) {
        return boardList;
    }

    /// @inheritdoc IIncentivesPool
    function isBoardApproved(address board) external view returns (bool) {
        return approvedBoards[board];
    }
}
