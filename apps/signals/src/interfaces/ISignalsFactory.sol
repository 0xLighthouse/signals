// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;


interface ISignalsFactory {
    struct FactoryDeployment {
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

    function create(ISignalsFactory.FactoryDeployment calldata config) external payable returns (address);
}
