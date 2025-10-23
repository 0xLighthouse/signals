// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {ISignals} from "../../src/interfaces/ISignals.sol";
import {IAuthorizer} from "../../src/interfaces/IAuthorizer.sol";

library BoardConfigs {
    function defaultConfig(address _owner, address _underlyingToken, uint256 boardOpenAt_)
        internal
        pure
        returns (ISignals.BoardConfig memory)
    {
        return ISignals.BoardConfig({
            version: "TEST-1.0",
            owner: _owner,
            underlyingToken: _underlyingToken,
            acceptanceThreshold: 100_000 ether, // 100k
            maxLockIntervals: 365 days, // 1 year
            proposalCap: 100, // 100 proposals
            lockInterval: 1 days, // 1 day
            decayCurveType: 0, // Linear
            decayCurveParameters: new uint256[](1),
            proposerRequirements: IAuthorizer.ParticipantRequirements({
                eligibilityType: IAuthorizer.EligibilityType.MinBalance,
                minBalance: 50_000 ether, // 50k tokens to propose,
                minHoldingDuration: 0,
                minLockAmount: 0
            }),
            supporterRequirements: IAuthorizer.ParticipantRequirements({
                eligibilityType: IAuthorizer.EligibilityType.None,
                minBalance: 0,
                minHoldingDuration: 0,
                minLockAmount: 0
            }),
            releaseLockDuration: 0,
            boardOpenAt: boardOpenAt_,
            boardClosedAt: 0
        });
    }
}
