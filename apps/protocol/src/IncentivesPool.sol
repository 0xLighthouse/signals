// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "solady/src/utils/ReentrancyGuard.sol";

import {IIncentivesPool} from "./interfaces/IIncentivesPool.sol";
import {IIncentivizer} from "./interfaces/IIncentivizer.sol";
import {IncentivesMath} from "./IncentivesMath.sol";

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

    /// @notice Number of time buckets used for incentive calculations
    uint256 constant INCENTIVE_RESOLUTION = 24;

    /// @notice Starting time interval for the first bucket (1 hour)
    uint256 constant INCENTIVE_STARTING_INTERVAL = 1 hours;

    /// @notice Represents a time bucket for incentive tracking
    struct IncentiveBucket {
        uint128 bucketTotalIncentiveCredits;
        uint128 endTime;
    }

    /// @notice Tracks a lock's incentive credit and timestamp
    struct LockIncentiveCredit {
        uint128 amount;
        uint128 timestamp;
    }

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
    mapping(address => uint256) public totalRewardPerInitiative;

    /// @notice Mapping of board addresses to the remaining budget for the board
    mapping(address => uint256) public boardRemainingBudget;

    /// @notice Mapping from board address to initiative ID to lock ID to its incentive credits
    mapping(address => mapping(uint256 => mapping(uint256 => LockIncentiveCredit))) public
        lockIncentiveCreditsByInitiative;

    /// @notice Mapping from board address to initiative ID to the last used bucket
    mapping(address => mapping(uint256 => uint256)) internal _lastUsedBucketByInitiative;

    /// @notice Mapping from board address to initiative ID to total incentive credit
    mapping(address => mapping(uint256 => uint256)) internal _totalIncentiveCreditByInitiative;

    /// @notice Mapping from board address to initiative ID to incentive buckets array
    mapping(address => mapping(uint256 => IncentiveBucket[INCENTIVE_RESOLUTION])) internal
        _incentiveBucketsByInitiative;

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
    function approveBoard(address board, uint256 boardBudget_, uint256 totalRewardPerInitiative_)
        external
        onlyOwner
    {
        if (board == address(0)) {
            revert IIncentivesPool.IncentivesPool_InvalidConfiguration();
        }
        if (totalRewardPerInitiative_ == 0) {
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
        totalRewardPerInitiative[board] = totalRewardPerInitiative_;
        boardRemainingBudget[board] = boardBudget_;
        totalBoardBudgets += boardBudget_;

        emit BoardApproved(board);
    }

    /// @inheritdoc IIncentivesPool
    function revokeBoard(address board) external onlyOwner {
        if (!approvedBoards[board]) revert IIncentivesPool.IncentivesPool_BoardNotApproved();

        approvedBoards[board] = false;
        totalRewardPerInitiative[board] = 0;
        totalBoardBudgets -= boardRemainingBudget[board];
        boardRemainingBudget[board] = 0;

        emit BoardRevoked(board);
    }

    /// @inheritdoc IIncentivesPool
    function claimRewards(uint256 initiativeId, address payee, uint256 percentOfInitiativeRewards)
        external
        nonReentrant
    {
        if (!approvedBoards[msg.sender]) revert IIncentivesPool.IncentivesPool_NotApprovedBoard();
        // If the rewards are bigger than 100%, reject. Shouldn't happen.
        if (percentOfInitiativeRewards > 1e18) {
            revert IIncentivesPool.IncentivesPool_InvalidConfiguration();
        }

        // Calculate the amount of rewards to claim
        uint256 amount = (totalRewardPerInitiative[msg.sender] * percentOfInitiativeRewards) / 1e18;

        // If the amount is bigger than the board's remaining budget, reduce to the budget
        if (amount > boardRemainingBudget[msg.sender]) {
            amount = boardRemainingBudget[msg.sender];
        }

        emit RewardsPaidOut(
            msg.sender,
            initiativeId,
            payee,
            percentOfInitiativeRewards,
            boardRemainingBudget[msg.sender],
            amount
        );

        if (amount > 0) {
            boardRemainingBudget[msg.sender] -= amount;
            totalBoardBudgets -= amount;
            availableRewards -= amount;
            distributedRewards += amount;

            // Transfer rewards
            IERC20(REWARD_TOKEN).safeTransfer(payee, amount);
        }
    }

    /// @inheritdoc IIncentivesPool
    function isBoardApproved(address board) external view returns (bool) {
        return approvedBoards[board];
    }

    /// @notice Record how much a user participated so we can calculate incentives later
    /// @param initiativeId The ID of the initiative
    /// @param lockId The ID of the lock
    /// @param credit The amount of contributions added to the initiative
    function addIncentivesCreditForLock(uint256 initiativeId, uint256 lockId, uint128 credit)
        external
    {
        if (!approvedBoards[msg.sender]) revert IIncentivesPool.IncentivesPool_NotApprovedBoard();

        // Add the lock to the list of supporters
        lockIncentiveCreditsByInitiative[msg.sender][initiativeId][lockId] =
            LockIncentiveCredit({amount: credit, timestamp: uint128(block.timestamp)});
        // Add the amount to the incentive bucket
        _addToIncentiveBucket(msg.sender, initiativeId, credit);
        _totalIncentiveCreditByInitiative[msg.sender][initiativeId] += credit;
    }

    /// @notice Claim incentives for a set of locks
    /// @param initiativeId The ID of the initiative
    /// @param lockIds The IDs of the locks
    /// @param payee The address to pay the incentives to
    /// @param config The incentives configuration for the board
    /// @dev The calling board must keep track of whether these locks have already been claimed
    function claimIncentivesForLocks(
        uint256 initiativeId,
        uint256[] memory lockIds,
        address payee,
        IIncentivizer.IncentivesConfig calldata config
    ) external nonReentrant {
        if (!approvedBoards[msg.sender]) revert IIncentivesPool.IncentivesPool_NotApprovedBoard();

        address board = msg.sender;
        IncentiveBucket[INCENTIVE_RESOLUTION] memory buckets =
            _incentiveBucketsByInitiative[board][initiativeId];

        uint256[] memory multipliers =
            _getBucketMultipliers(config, _lastUsedBucketByInitiative[board][initiativeId] + 1);

        // Total number of credits recorded for this initiative
        uint256 totalCredits = 0;
        for (uint256 i = 0; i < multipliers.length; i++) {
            totalCredits += uint256(buckets[i].bucketTotalIncentiveCredits) * multipliers[i] / 1e18;
        }

        // Payee's percentage of the total rewards
        uint256 totalPercentOfInitiativeRewards = 0;
        for (uint256 i = 0; i < lockIds.length; i++) {
            // Get each lock
            LockIncentiveCredit memory credit =
                lockIncentiveCreditsByInitiative[board][initiativeId][lockIds[i]];

            // Find which bucket it fits in
            uint256 bucketIndex = 0;
            for (uint256 j = 0; j < buckets.length; j++) {
                if (credit.timestamp < buckets[j].endTime) {
                    bucketIndex = j;
                    break;
                }
            }

            uint256 lockPercentOfInitiativeRewards =
                uint256(credit.amount) * multipliers[bucketIndex] / totalCredits;

            totalPercentOfInitiativeRewards += lockPercentOfInitiativeRewards;

            emit IIncentivizer.RewardsClaimed(
                initiativeId, lockIds[i], payee, lockPercentOfInitiativeRewards
            );
        }

        // Payout that percentage of the initiative rewards to the payee
        // (inline the claimRewards logic)
        if (totalPercentOfInitiativeRewards > 1e18) {
            revert IIncentivesPool.IncentivesPool_InvalidConfiguration();
        }

        // Calculate the amount of rewards to claim
        uint256 amount = (totalRewardPerInitiative[board] * totalPercentOfInitiativeRewards) / 1e18;

        // If the amount is bigger than the board's remaining budget, reduce to the budget
        if (amount > boardRemainingBudget[board]) {
            amount = boardRemainingBudget[board];
        }

        emit RewardsPaidOut(
            board,
            initiativeId,
            payee,
            totalPercentOfInitiativeRewards,
            boardRemainingBudget[board],
            amount
        );

        if (amount > 0) {
            boardRemainingBudget[board] -= amount;
            totalBoardBudgets -= amount;
            availableRewards -= amount;
            distributedRewards += amount;

            // Transfer rewards
            IERC20(REWARD_TOKEN).safeTransfer(payee, amount);
        }
    }

    /// @notice Add credit to the appropriate time bucket
    /// @param board The board address
    /// @param initiativeId The initiative ID
    /// @param amount The amount of credit to add
    function _addToIncentiveBucket(address board, uint256 initiativeId, uint256 amount) private {
        IncentiveBucket[INCENTIVE_RESOLUTION] storage buckets =
            _incentiveBucketsByInitiative[board][initiativeId];
        uint256 lastUsedBucket = _lastUsedBucketByInitiative[board][initiativeId];
        if (lastUsedBucket == 0 && buckets[0].endTime == 0) {
            // This is the first addition, so set the end times based on this
            for (uint256 i = 0; i < INCENTIVE_RESOLUTION; i++) {
                buckets[i].endTime =
                    uint128(block.timestamp + (i + 1) * INCENTIVE_STARTING_INTERVAL);
            }
        }

        // Find correct bucket, starting where we left off
        // If we exhause all buckets, we will need to reduce and continue searching
        for (uint256 i = lastUsedBucket; i <= INCENTIVE_RESOLUTION; i++) {
            if (i == INCENTIVE_RESOLUTION) {
                // We are now at n + 1 buckets, so we need to reduce
                _reduceIncentiveBuckets(buckets);
                // The old bucket n is now n/2, so we need to start with the next bucket after that
                i = INCENTIVE_RESOLUTION / 2 - 1;
            }

            if (buckets[i].endTime > block.timestamp) {
                buckets[i].bucketTotalIncentiveCredits += uint128(amount);
                _lastUsedBucketByInitiative[board][initiativeId] = i;
                return;
            }
        }
    }

    /// @notice Reduce the incentive buckets by half
    /// @dev [ 0 ][ 1 ][ 2 ][ 3 ][ 4 ][ 5 ] => [ 0+1 ][ 2+3 ][ 4+5 ]
    /// @param buckets The array of buckets to reduce
    function _reduceIncentiveBuckets(IncentiveBucket[INCENTIVE_RESOLUTION] storage buckets)
        internal
    {
        for (uint256 i = 0; i < INCENTIVE_RESOLUTION / 2; i++) {
            buckets[i].bucketTotalIncentiveCredits = buckets[i * 2].bucketTotalIncentiveCredits
                + buckets[i * 2 + 1].bucketTotalIncentiveCredits;
            buckets[i].endTime = buckets[i * 2 + 1].endTime;
        }
        uint256 newTimeInterval = buckets[1].endTime - buckets[0].endTime;
        // Populate correct time and reset newly emptied buckets
        for (uint256 i = INCENTIVE_RESOLUTION / 2; i < INCENTIVE_RESOLUTION; i++) {
            buckets[i].endTime = uint128(buckets[i - 1].endTime + newTimeInterval);
            buckets[i].bucketTotalIncentiveCredits = 0;
        }
    }

    /// @notice Get the bucket multipliers from the config
    /// @param config The incentives configuration
    /// @param numberOfBuckets The number of buckets to get multipliers for
    /// @return Array of multipliers in WAD format
    function _getBucketMultipliers(
        IIncentivizer.IncentivesConfig calldata config,
        uint256 numberOfBuckets
    ) internal pure returns (uint256[] memory) {
        uint256[] memory configParams = config.incentiveParametersWAD;
        uint256[] memory multipliers =
            IncentivesMath.bucketMultipliers(configParams, numberOfBuckets);
        return multipliers;
    }

    /// @notice Scale incentive config parameters to match bucket count
    /// @param config The config parameters to scale
    /// @param numberOfBuckets The target number of buckets
    /// @return Scaled parameters array
    function _scaleIncentiveConfigParameters(uint256[] memory config, uint256 numberOfBuckets)
        internal
        pure
        returns (uint256[] memory)
    {
        return IncentivesMath.scaleParameters(config, numberOfBuckets);
    }
}
