// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {IncentivesPool} from "../../src/IncentivesPool.sol";
import {IIncentivizer} from "../../src/interfaces/IIncentivizer.sol";

/**
 * @title IncentivesPoolHarness
 * @notice Test harness that exposes internal functions for testing
 */
contract IncentivesPoolHarness is IncentivesPool {
    constructor(address rewardToken) IncentivesPool(rewardToken) {}

    /// @notice Expose internal _reduceIncentiveBuckets for testing
    function exposed_reduceIncentiveBuckets(
        address board,
        uint256 initiativeId
    ) external {
        IncentiveBucket[INCENTIVE_RESOLUTION] storage buckets =
            _incentiveBucketsByInitiative[board][initiativeId];
        _reduceIncentiveBuckets(buckets);
    }

    /// @notice Expose internal _getBucketMultipliers for testing
    function exposed_getBucketMultipliers(
        IIncentivizer.IncentivesConfig calldata config,
        uint256 numberOfBuckets
    ) external pure returns (uint256[] memory) {
        return _getBucketMultipliers(config, numberOfBuckets);
    }

    /// @notice Expose internal _scaleIncentiveConfigParameters for testing
    function exposed_scaleIncentiveConfigParameters(
        uint256[] memory config,
        uint256 numberOfBuckets
    ) external pure returns (uint256[] memory) {
        return _scaleIncentiveConfigParameters(config, numberOfBuckets);
    }

    /// @notice Get buckets for testing
    function getBuckets(
        address board,
        uint256 initiativeId
    ) external view returns (IncentiveBucket[INCENTIVE_RESOLUTION] memory) {
        return _incentiveBucketsByInitiative[board][initiativeId];
    }

    /// @notice Set buckets for testing
    function setBuckets(
        address board,
        uint256 initiativeId,
        IncentiveBucket[INCENTIVE_RESOLUTION] memory buckets
    ) external {
        for (uint256 i = 0; i < INCENTIVE_RESOLUTION; i++) {
            _incentiveBucketsByInitiative[board][initiativeId][i] = buckets[i];
        }
    }
}
