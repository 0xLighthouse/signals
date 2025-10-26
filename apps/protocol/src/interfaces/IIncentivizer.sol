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
     * @param curveType Type of incentive curve (0 = linear, 1 = exponential)
     * @param curveParameters Parameters for the curve (e.g., [k] for linear decay)
     */

    struct IncentivesConfig {
        IncentiveType incentiveType;
        uint256[] incentiveParameters;
    }
}
