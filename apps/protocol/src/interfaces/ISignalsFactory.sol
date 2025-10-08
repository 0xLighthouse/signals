// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {ISignals} from "./ISignals.sol";

interface ISignalsFactory {
    struct FactoryDeployment {
        address owner;
        address underlyingToken;
        uint256 acceptanceThreshold;
        uint256 maxLockIntervals;
        uint256 proposalCap;
        uint256 lockInterval;
        uint256 decayCurveType;
        uint256[] decayCurveParameters;
        ISignals.ProposerRequirements proposerRequirements;
        ISignals.ParticipantRequirements participantRequirements;
        uint256 releaseLockDuration;
    }

    function create(ISignalsFactory.FactoryDeployment calldata config) external payable returns (address);
}
