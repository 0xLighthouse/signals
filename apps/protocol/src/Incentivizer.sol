// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import {IIncentivizer} from "./interfaces/IIncentivizer.sol";
import {IIncentivesPool} from "./interfaces/IIncentivesPool.sol";
import {ISignals} from "./interfaces/ISignals.sol";
import {IncentivesMath} from "./IncentivesMath.sol";

abstract contract SignalsIncentivizer is IIncentivizer {
    uint256 constant INCENTIVE_RESOLUTION = 24;
    uint256 constant INCENTIVE_STARTING_INTERVAL = 1 hours;

    struct IncentiveBucket {
        uint128 bucketTotalIncentiveCredits;
        uint128 endTime;
    }

    struct LockIncentiveCredit {
        uint128 amount;
        uint128 timestamp;
    }

    /// @notice (Optional) Reference to the IncentivesPool contract (can be set before board opens)
    IIncentivesPool public incentivesPool;

    /// @notice Configuration for board-wide incentive rewards (internal storage)
    IncentivesConfig internal _incentivesConfig;

    /// @notice Mapping from initiative ID to mapping from lock id to its incentive credits
    mapping(uint256 => mapping(uint256 => LockIncentiveCredit)) public
        lockIncentiveCreditsByInitiative;

    /// @notice Mapping from initiative ID to the last used bucket
    mapping(uint256 => uint256) internal _lastUsedBucketByInitiative;

    mapping(uint256 => uint256) internal _totalIncentiveCreditByInitiative;
    mapping(uint256 => IncentiveBucket[INCENTIVE_RESOLUTION]) internal _incentiveBucketsByInitiative;

    /// @notice Set the incentives pool and configuration
    /// @param incentivesPool_ The address of the incentives pool
    /// @param incentivesConfig_ The configuration for the incentives
    /// @dev Reverts if the incentives pool is already set or if this board is not authorized by the incentives pool
    function _setIncentivesPool(
        address incentivesPool_,
        IncentivesConfig calldata incentivesConfig_
    ) internal {
        if (address(incentivesPool_) == address(0)) {
            revert ISignals.Signals_InvalidArguments();
        }
        if (address(incentivesPool) != address(0)) {
            revert ISignals.Signals_IncentivesPoolAlreadySet();
        }

        if (!IIncentivesPool(incentivesPool_).isBoardApproved(address(this))) {
            revert ISignals.Signals_IncentivesPoolNotApproved();
        }
        incentivesPool = IIncentivesPool(incentivesPool_);

        if (incentivesConfig_.incentiveType == IncentiveType.Linear) {
            if (
                incentivesConfig_.incentiveParametersWAD.length < 2
                    || incentivesConfig_.incentiveParametersWAD.length > INCENTIVE_RESOLUTION
            ) {
                revert ISignals.Signals_InvalidArguments();
            }
        }
        _incentivesConfig = incentivesConfig_;
    }

    /// @notice Record how much a user participated so we can calculate incentives later
    /// @param initiativeId The ID of the initiative
    /// @param lockId The ID of the lock
    /// @param amount The amount of contributions added to the initiative
    function _addIncentivesCreditForLock(uint256 initiativeId, uint256 lockId, uint128 amount)
        internal
    {
        // Silently skip if we aren't using incentives
        if (address(incentivesPool) == address(0)) {
            return;
        }

        // Add the lock to the list of supporters
        lockIncentiveCreditsByInitiative[initiativeId][lockId] =
            LockIncentiveCredit({amount: amount, timestamp: uint128(block.timestamp)});
        // Add the amount to the incentive bucket
        _addToIncentiveBucket(initiativeId, amount);
        _totalIncentiveCreditByInitiative[initiativeId] += amount;
    }

    function _addToIncentiveBucket(uint256 initiativeId, uint256 amount) private {
        IncentiveBucket[INCENTIVE_RESOLUTION] storage buckets =
            _incentiveBucketsByInitiative[initiativeId];
        uint256 lastUsedBucket = _lastUsedBucketByInitiative[initiativeId];
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
                _lastUsedBucketByInitiative[initiativeId] = i;
                return;
            }
        }
    }

    /// @notice Reduce the incentive buckets by half
    /// [ 0 ][ 1 ][ 2 ][ 3 ][ 4 ][ 5 ] => [ 0+1 ][ 2+3 ][ 4+5 ]
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

    /// @notice Claim incentives for a set of locks. Can only be called by the Signals board, and we trust what it tells us.
    /// @param initiativeId The ID of the initiative
    /// @param lockIds The IDs of the locks
    /// @param payee The address to pay the incentives to
    /// @dev Note, the Signals board needs to keep track of whether or not these locks have already been claimed, and if they belong to the user.
    function _claimIncentivesForLocks(uint256 initiativeId, uint256[] memory lockIds, address payee)
        internal
    {
        // Silently skip if we aren't using incentives
        if (address(incentivesPool) == address(0)) {
            return;
        }

        IncentiveBucket[INCENTIVE_RESOLUTION] memory buckets =
            _incentiveBucketsByInitiative[initiativeId];

        uint256[] memory multipliers =
            _getBucketMultipliers(_lastUsedBucketByInitiative[initiativeId] + 1);

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
                lockIncentiveCreditsByInitiative[initiativeId][lockIds[i]];

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

            emit RewardsClaimed(initiativeId, lockIds[i], payee, lockPercentOfInitiativeRewards);
        }
        // Tell the incentives pool to payout that percentage of the initiative rewards to the payee
        incentivesPool.claimRewards(initiativeId, payee, totalPercentOfInitiativeRewards);
    }

    function _getBucketMultipliers(uint256 numberOfBuckets)
        internal
        view
        returns (uint256[] memory)
    {
        uint256[] memory config = _incentivesConfig.incentiveParametersWAD;
        uint256[] memory multipliers = IncentivesMath.bucketMultipliers(config, numberOfBuckets);
        return multipliers;
    }

    function _scaleIncentiveConfigParameters(uint256[] memory config, uint256 numberOfBuckets)
        internal
        pure
        returns (uint256[] memory)
    {
        uint256[] memory interpolated = new uint256[](numberOfBuckets);
        return IncentivesMath.scaleParameters(config, numberOfBuckets);
    }

    // NOTE: The original _geometricLinearInterpolation() is intentionally removed via indirection.
    // It is no longer required internally, as the math now lives in IncentivesMath.
    // Keeping it absent lets the compiler/optimizer reduce bytecode size when unused.
    // (Tests call _scaleIncentiveConfigParameters and _getBucketMultipliers only.)
}
