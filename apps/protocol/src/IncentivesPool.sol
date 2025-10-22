// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

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
contract IncentivesPool is IIncentivesPool, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice The which ERC20 token is used as the reward
    address public constant rewardToken;

    /// @notice The total amount of rewards in the pool
    uint256 public availableRewards;

    /// @notice The amount of rewards that have been distributed
    uint256 public distributedRewards;

    /// @notice Mapping of approved board addresses
    mapping(address => bool) public approvedBoards;

    /// @notice Mapping of board addresses to the maximum reward per initiative
    mapping(address => uint256) public maxRewardPerInitiative;

    /// @notice Mapping of board addresses to the maximum budget for the board
    mapping(address => uint256) public boardMaxBudget;

    /// @notice Array of all approved boards for enumeration //NOTE: Is this needed?
    address[] public boardList;

    /// @notice Modifier to check if caller is an approved board
    modifier onlyApprovedBoard() {
        if (!approvedBoards[msg.sender]) revert IIncentivesPool.IncentivesPool_NotApprovedBoard();
        _;
    }

    /**
     * @notice Constructor
     */
    constructor(address rewardToken_) Ownable(msg.sender) {
        // Validate reward token address
        if (rewardToken_ == address(0)) revert IIncentivesPool.IncentivesPool_InvalidConfiguration();

        // Verify token implements ERC20 interface by attempting a basic call
        try IERC20(rewardToken_).totalSupply() returns (uint256) {}
        catch {
            revert IIncentivesPool.IncentivesPool_InvalidConfiguration();
        }
        rewardToken = rewardToken_;
    }

    /// @inheritdoc IIncentivesPool
    function addFundsToPool(uint256 amount) external {
        if (amount == 0) revert IIncentivesPool.IncentivesPool_InvalidConfiguration();

        availableRewards += amount;

        // Transfer tokens from owner to this contract
        IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), amount);

        emit FundsAddedToPool(amount);
    }

    /// @inheritdoc IIncentivesPool
    function updateAvailableRewards(uint256 newBalance) external onlyOwner {
        if (newBalance <= availableRewards || newBalance > rewardToken.balanceOf(address(this))) {
            revert IIncentivesPool.IncentivesPool_InvalidConfiguration();
        }

        availableRewards = newBalance;

        emit AvailableRewardsUpdated(newBalance);
    }

    /// @inheritdoc IIncentivesPool
    function approveBoard(address board, uint256 boardMaxBudget_, uint256 maxRewardPerInitiative_) external onlyOwner {
        if (board == address(0)) {
            revert IIncentivesPool.IncentivesPool_InvalidConfiguration();
        }
        if (approvedBoards[board]) revert IIncentivesPool.IncentivesPool_BoardAlreadyApproved();
        if (maxRewardPerInitiative_ == 0) revert IIncentivesPool.IncentivesPool_InvalidConfiguration();

        maxRewardPerInitiative[board] = maxRewardPerInitiative_;
        boardMaxBudget[board] = boardMaxBudget_;
        approvedBoards[board] = true;
        boardList.push(board); // NOTE: Is this needed?

        emit BoardApproved(board);
    }

    /// @inheritdoc IIncentivesPool
    function revokeBoard(address board) external onlyOwner {
        if (!approvedBoards[board]) revert IIncentivesPool.IncentivesPool_BoardNotApproved();

        approvedBoards[board] = false;
        maxRewardPerInitiative[board] = 0;

        // Remove board from boardList
        for (uint256 i = 0; i < boardList.length; i++) {
            if (boardList[i] == board) {
                boardList[i] = boardList[boardList.length - 1];
                boardList.pop();
                break;
            }
        }

        emit BoardRevoked(board);
    }

    // /// @inheritdoc IIncentivesPool
    // function calculateIncentives(uint256 initiativeId, uint256 boardOpensAt, uint256 acceptanceTimestamp)
    //     external
    //     onlyApprovedBoard
    //     returns (uint256 rewardAmount)
    // {
    //     address board = msg.sender;

    //     // If pool not initialized or disabled, return 0 (non-blocking)
    //     if (poolConfig.token == address(0) || !poolConfig.enabled) {
    //         return 0;
    //     }

    //     // Check if already calculated
    //     if (distributionsCalculated[board][initiativeId]) revert IIncentivesPool.IncentivesPool_AlreadyCalculated();

    //     // Check if board has opened
    //     if (block.timestamp < boardOpensAt) revert IIncentivesPool.IncentivesPool_InvalidConfiguration();

    //     // Calculate reward allocation for this initiative
    //     uint256 availableBalance = poolConfig.totalAmount - poolConfig.allocated;
    //     rewardAmount =
    //         availableBalance < poolConfig.maxRewardPerInitiative ? availableBalance : poolConfig.maxRewardPerInitiative;

    //     // If no rewards available, return early (non-blocking)
    //     if (rewardAmount == 0) {
    //         distributionsCalculated[board][initiativeId] = true;
    //         return 0;
    //     }

    //     // Get board incentive configuration
    //     ISignals signals = ISignals(board);
    //     ISignals.BoardIncentives memory incentives = signals.boardIncentives();

    //     // If incentives not enabled, return early (non-blocking)
    //     if (!incentives.enabled) {
    //         distributionsCalculated[board][initiativeId] = true;
    //         return 0;
    //     }

    //     // Get all supporters for this initiative
    //     address[] memory supporters = signals.getSupporters(initiativeId);
    //     if (supporters.length == 0) {
    //         distributionsCalculated[board][initiativeId] = true;
    //         return 0;
    //     }

    //     // Calculate time-weighted rewards for each supporter
    //     uint256 totalWeight = 0;

    //     // Get incentive curve parameter k (scaled by 1e18) and cache board/initiative for storage pointer
    //     uint256 k = incentives.curveParameters.length > 0 ? incentives.curveParameters[0] : 0;
    //     mapping(address => uint256) storage rewards = supporterRewards[board][initiativeId];

    //     // Calculate weights for each supporter
    //     for (uint256 i = 0; i < supporters.length; i++) {
    //         address supporter = supporters[i];
    //         uint256 supporterWeight = _calculateSupporterWeight(
    //             signals, initiativeId, supporter, boardOpensAt, acceptanceTimestamp, k, incentives.curveType
    //         );

    //         if (supporterWeight > 0) {
    //             rewards[supporter] = supporterWeight;
    //             totalWeight += supporterWeight;
    //         }
    //     }

    //     // If no weight, return early (non-blocking)
    //     if (totalWeight == 0) {
    //         distributionsCalculated[board][initiativeId] = true;
    //         return 0;
    //     }

    //     // Allocate proportional rewards to each supporter
    //     for (uint256 i = 0; i < supporters.length; i++) {
    //         address supporter = supporters[i];
    //         uint256 supporterWeight = rewards[supporter]; // Single SLOAD

    //         if (supporterWeight > 0) {
    //             // Calculate proportional share: (supporterWeight / totalWeight) * rewardAmount
    //             uint256 supporterReward = (supporterWeight * rewardAmount) / totalWeight;
    //             rewards[supporter] = supporterReward; // Single SSTORE
    //         }
    //     }

    //     // Update state
    //     poolConfig.allocated += rewardAmount;
    //     initiativeRewardPool[board][initiativeId] = rewardAmount;
    //     initiativeTotalWeight[board][initiativeId] = totalWeight;
    //     distributionsCalculated[board][initiativeId] = true;

    //     emit IncentivesCalculated(board, initiativeId, totalWeight, rewardAmount, supporters.length);

    //     return rewardAmount;
    // }

    /// @inheritdoc IIncentivesPool
    function claimRewards(uint256 initiativeId, address payee, uint256 amount) external nonReentrant {
        if (!approvedBoards[msg.sender]) revert IIncentivesPool.IncentivesPool_NotApprovedBoard();
        if (amount == 0) revert IIncentivesPool.IncentivesPool_InvalidConfiguration();
        if (amount > maxRewardPerInitiative[msg.sender]) revert IIncentivesPool.IncentivesPool_InvalidConfiguration();
        if (amount > boardMaxBudget[msg.sender]) revert IIncentivesPool.IncentivesPool_InvalidConfiguration();

        if (availableRewards < amount) revert IIncentivesPool.IncentivesPool_InsufficientFunds();

        boardMaxBudget[msg.sender] -= amount;
        availableRewards -= amount;
        distributedRewards += amount;

        // Transfer rewards
        IERC20(rewardToken).safeTransfer(payee, amount);

        emit RewardsClaimed(msg.sender, initiativeId, payee, amount);
    }

    // /**
    //  * @notice Calculate time-weighted support for a supporter
    //  * @dev Uses the board's incentive curve to calculate weight
    //  *
    //  * @param signals The Signals board contract
    //  * @param initiativeId ID of the initiative
    //  * @param supporter Address of the supporter
    //  * @param boardOpensAt Timestamp when board opened
    //  * @param acceptanceTimestamp Timestamp when initiative was accepted
    //  * @param k Decay rate parameter (scaled by 1e18)
    //  * @param curveType Type of curve (0 = linear)
    //  * @return Total weight for this supporter
    //  */
    // function _calculateSupporterWeight(
    //     ISignals signals,
    //     uint256 initiativeId,
    //     address supporter,
    //     uint256 boardOpensAt,
    //     uint256 acceptanceTimestamp,
    //     uint256 k,
    //     uint256 curveType
    // ) internal view returns (uint256) {
    //     // Get all lock positions for this supporter on this initiative
    //     uint256[] memory lockIds = signals.getLocksForSupporter(supporter);

    //     uint256 totalWeight = 0;
    //     uint256 duration = acceptanceTimestamp - boardOpensAt;

    //     // If acceptance happened immediately at board open, everyone gets equal weight
    //     if (duration == 0) {
    //         for (uint256 i = 0; i < lockIds.length; i++) {
    //             ISignals.TokenLock memory lock = signals.getTokenLock(lockIds[i]);
    //             if (lock.initiativeId == initiativeId && !lock.withdrawn) {
    //                 totalWeight += lock.tokenAmount;
    //             }
    //         }
    //         return totalWeight;
    //     }

    //     // Calculate time-weighted support for each lock position
    //     // Early supporters get more weight, later supporters get less
    //     for (uint256 i = 0; i < lockIds.length; i++) {
    //         ISignals.TokenLock memory lock = signals.getTokenLock(lockIds[i]);

    //         // Only include locks for this initiative that haven't been withdrawn
    //         if (lock.initiativeId == initiativeId && !lock.withdrawn) {
    //             // Calculate normalized time: t = (lockTime - boardOpensAt) / (acceptTime - boardOpensAt)
    //             // This gives a value between 0 (locked at board open) and 1e18 (locked at acceptance)
    //             // Example: Board opens at T=0, initiative accepted at T=100, lock at T=25
    //             //   timeSinceBoardOpen = 25
    //             //   t = (25 * 1e18) / 100 = 0.25e18 (25% of the way through)
    //             uint256 timeSinceBoardOpen = lock.created >= boardOpensAt ? lock.created - boardOpensAt : 0;
    //             uint256 t = (timeSinceBoardOpen * SignalsConstants.PRECISION) / duration;

    //             // Calculate weight based on curve type
    //             uint256 weight;
    //             if (curveType == SignalsConstants.INCENTIVE_CURVE_LINEAR) {
    //                 // Linear decay: weight = lockAmount * (1 - k * t)
    //                 // k is the decay rate (e.g., 1e18 means full decay from 100% to 0%)
    //                 // Example: k=1e18, t=0.5e18 (locked halfway through)
    //                 //   decay = (1e18 * 0.5e18) / 1e18 = 0.5e18
    //                 //   weight = lockAmount * (1e18 - 0.5e18) / 1e18 = lockAmount * 50%
    //                 // Early supporters (t≈0) get full weight, late supporters (t≈1) get minimal weight
    //                 uint256 decay = (k * t) / SignalsConstants.PRECISION;
    //                 if (decay >= SignalsConstants.PRECISION) {
    //                     // Decay rate too high - no weight for this lock
    //                     weight = 0;
    //                 } else {
    //                     // Apply time-weighted decay
    //                     weight = (lock.tokenAmount * (SignalsConstants.PRECISION - decay)) / SignalsConstants.PRECISION;
    //                 }
    //             } else {
    //                 // Future: exponential or other curves
    //                 // For now, default to no decay (all supporters weighted equally)
    //                 weight = lock.tokenAmount;
    //             }

    //             totalWeight += weight;
    //         }
    //     }

    //     return totalWeight;
    // }

    // /// @inheritdoc IIncentivesPool
    // function previewRewards(address board, uint256 initiativeId, address supporter) external view returns (uint256) {
    //     return supporterRewards[board][initiativeId][supporter];
    // }

    // /// @inheritdoc IIncentivesPool
    // function getSupporterRewards(address board, uint256 initiativeId, address supporter)
    //     external
    //     view
    //     returns (uint256)
    // {
    //     return supporterRewards[board][initiativeId][supporter];
    // }

    /// @inheritdoc IIncentivesPool
    function getApprovedBoards() external view returns (address[] memory) {
        return boardList;
    }

    /// @inheritdoc IIncentivesPool
    function isBoardApproved(address board) external view returns (bool) {
        return approvedBoards[board];
    }
}
