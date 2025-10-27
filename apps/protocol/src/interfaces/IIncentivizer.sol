// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

interface IIncentivizer {
    enum IncentiveType {
        Linear,
        Exponential
    }
    /**
     * @notice Configuration for board-wide incentive rewards
     *
     * @param incentiveType Type of incentive curve
     * @param incentiveParameters Parameters for the curve
     * @dev If the incentive type is Linear, at least 2 values (starting and ending values) are required.
     * @dev Exponential type is not yet implemented.
     */

    struct IncentivesConfig {
        IncentiveType incentiveType;
        uint256[] incentiveParameters;
    }

    event RewardsClaimed(
        uint256 indexed initiativeId,
        uint256 indexed lockId,
        address indexed claimant,
        uint256 percentOfInitiativeRewards
    );
}
