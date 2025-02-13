// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.26;

interface ISignals {
    /**
     * @notice Struct to store lock information for each lockup
     *
     * @param initiativeId ID of the initiative
     * @param tokenAmount Amount of tokens locked
     * @param lockDuration Total duration of the lock in intervals
     * @param created Timestamp of when the lock was created
     * @param withdrawn Flag indicating whether the locked tokens have been withdrawn
     */
    struct LockInfo {
        uint256 initiativeId;
        uint256 tokenAmount;
        uint256 lockDuration;
        uint256 created;
        bool withdrawn;
    }

    /**
     * @notice Struct to store all configuration parameters for initializing the Signals contract
     *
     * @param owner The address which will own the contract
     * @param underlyingToken The address of the underlying ERC20 token
     * @param proposalThreshold Minimum tokens to propose an initiative
     * @param acceptanceThreshold Minimum tokens to accept an initiative
     * @param maxLockIntervals Maximum lock intervals allowed
     * @param proposalCap The maximum number of proposals
     * @param lockInterval Time interval for lockup duration and decay calculations
     * @param decayCurveType Which decay curve to use (e.g., 0 = linear, 1 = exponential)
     * @param decayCurveParameters Parameters to control the decay curve behavior
     */
    struct SignalsConfig {
        address owner;
        address underlyingToken;
        uint256 proposalThreshold;
        uint256 acceptanceThreshold;
        uint256 maxLockIntervals;
        uint256 proposalCap;
        uint256 lockInterval;
        uint256 decayCurveType;
        uint256[] decayCurveParameters;
    }
}
