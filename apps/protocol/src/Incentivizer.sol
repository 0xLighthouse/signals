// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import "forge-std/console.sol";

import {IIncentivizer} from "./interfaces/IIncentivizer.sol";
import {IIncentivesPool} from "./interfaces/IIncentivesPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISignals} from "./interfaces/ISignals.sol";
import {IVotes} from "./interfaces/IVotes.sol";
import {console} from "forge-std/console.sol";

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
            revert ISignals.Signals_ZeroAddressIncentivesPool();
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
                revert ISignals.Signals_InvalidIncentiveParameters();
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

        uint256 timeInterval = buckets[1].endTime - buckets[0].endTime;

        uint256[] memory multipliers =
            _getBucketMultipliers(_lastUsedBucketByInitiative[initiativeId] + 1);

        // The percent of all rewards for this initiative that this payee is entitled to
        uint256 totalPercentOfInitiativeRewards = 0;

        for (uint256 i = 0; i < lockIds.length; i++) {
            // Get each lock
            LockIncentiveCredit memory credit =
                lockIncentiveCreditsByInitiative[initiativeId][lockIds[i]];

            // Find which bucket it fits in
            uint256 bucketIndex = credit.timestamp < buckets[0].endTime
                ? 0
                : (credit.timestamp - buckets[0].endTime) / timeInterval;

            // Find what percentage of the bucket we account for
            // (cast to uint256 to avoid overflow)
            uint256 percentOfBucket = uint256(credit.amount) * 1e18
                / uint256(buckets[bucketIndex].bucketTotalIncentiveCredits);
            // Multiply by what percent of all awards the bucket represents
            uint256 percentOfInitiativeRewards = percentOfBucket * multipliers[bucketIndex] / 1e18;
            totalPercentOfInitiativeRewards += percentOfInitiativeRewards;

            emit RewardsClaimed(initiativeId, lockIds[i], payee, percentOfInitiativeRewards);
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

        uint256[] memory interpolated = _scaleIncentiveConfigParameters(config, numberOfBuckets);

        uint256 totalInterpolatedValues = 0;

        //Sum all interpolated values
        for (uint256 i = 0; i < interpolated.length; i++) {
            totalInterpolatedValues += interpolated[i];
        }

        // Replace each value with its percentage of the whole
        for (uint256 i = 0; i < interpolated.length; i++) {
            interpolated[i] = (interpolated[i] * 1e18) / totalInterpolatedValues;
        }

        // Return the percentage of the entire rewards each bucket is entitled to
        return interpolated;
    }

    function _scaleIncentiveConfigParameters(uint256[] memory config, uint256 numberOfBuckets)
        internal
        pure
        returns (uint256[] memory)
    {
        uint256[] memory interpolated = new uint256[](numberOfBuckets);
        // If there is only one bucket, we just use a value of 1e18
        if (numberOfBuckets == 1) {
            interpolated[0] = 1e18;
            return interpolated;
        }

        if (numberOfBuckets == config.length) {
            interpolated = config;
        } else {
            // The first and the last buckets don't change, so we can just set them to the first and last config values.
            interpolated[0] = config[0];
            interpolated[interpolated.length - 1] = config[config.length - 1];
        }

        if (numberOfBuckets > 2) {
            // We will think of index/value as an X/Y coordinate. We can then convert the X coordinates to match the scale of the
            // number of buckets, and use geometric interpolation to find Y values for each bucket..

            // Convert indexes into WAD
            uint256[] memory indexes = new uint256[](config.length);
            for (uint256 i = 0; i < config.length; i++) {
                indexes[i] = i * 1e18;
            }

            // Find the multiplier, based on the scale difference between the two (0-index). Multiplying the index of the last config by this number should give the index of the last bucket.
            uint256 multiplier = ((numberOfBuckets - 1) * 1e18) / (config.length - 1);

            // Scale the config indexes to match the number of buckets.
            for (uint256 i = 0; i < indexes.length; i++) {
                indexes[i] = indexes[i] * multiplier / 1e18;
            }

            // Thinking of it like XY cooridnates, use linear interpolation to find the Y coordinate (value) for the X coordinate (index) of each bucket.
            // We can make the lookup efficient by keeping track of the last config index and using it to find the next config index (since we know the bucket index is always increasing).
            uint256 lastConfigIndex = 0;

            for (uint256 i = 1; i < numberOfBuckets - 1; i++) {
                uint256 desiredX = i * 1e18;
                while (indexes[lastConfigIndex + 1] < desiredX) lastConfigIndex++;

                interpolated[i] = _geometricLinearInterpolation(
                    desiredX,
                    indexes[lastConfigIndex],
                    config[lastConfigIndex],
                    indexes[lastConfigIndex + 1],
                    config[lastConfigIndex + 1]
                );
            }
        }
        return interpolated;
    }

    function _geometricLinearInterpolation(
        uint256 x,
        uint256 x1,
        uint256 y1,
        uint256 x2,
        uint256 y2
    ) private pure returns (uint256) {
        return uint256(
            int256(y1)
                + ((int256(x) - int256(x1)) * (int256(y2) - int256(y1))) / (int256(x2) - int256(x1))
        );
    }
}
