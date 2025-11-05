// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {ISignals} from "../../src/interfaces/ISignals.sol";
import {IAuthorizer} from "../../src/interfaces/IAuthorizer.sol";

library BoardConfigs {
    function _emptyBoardMetadata() internal pure returns (ISignals.Metadata memory) {
        return ISignals.Metadata({title: "", body: "", attachments: new ISignals.Attachment[](0)});
    }

    function defaultConfig(address _owner, address _underlyingToken, uint256 boardOpenAt_)
        internal
        pure
        returns (ISignals.BoardConfig memory)
    {
        return ISignals.BoardConfig({
            version: "0.0.1",
            boardMetadata: ISignals.Metadata({
                title: "Test Board",
                body: "Board using default config",
                attachments: new ISignals.Attachment[](0)
            }),
            owner: _owner,
            underlyingToken: _underlyingToken,
            acceptanceCriteria: ISignals.AcceptanceCriteria({
                anyoneCanAccept: false,
                ownerMustFollowThreshold: false,
                percentageThresholdWAD: 0,
                fixedThreshold: 100_000 ether // 100k
            }),
            maxLockIntervals: 365 days, // 1 year
            lockInterval: 1 days, // 1 day
            decayCurveType: 0, // Linear
            decayCurveParameters: new uint256[](1),
            inactivityTimeout: 60 days, // 60 days
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

    function defaultEdgeCityConfig(address _owner, address _underlyingToken, uint256 boardOpenAt_)
        internal
        pure
        returns (ISignals.BoardConfig memory)
    {
        return ISignals.BoardConfig({
            version: "0.0.2",
            boardMetadata: ISignals.Metadata({
                title: "Edge City Board",
                body: "Board using default edge city config",
                attachments: new ISignals.Attachment[](0)
            }),
            owner: _owner,
            underlyingToken: _underlyingToken,
            acceptanceCriteria: ISignals.AcceptanceCriteria({
                anyoneCanAccept: true,
                ownerMustFollowThreshold: true,
                percentageThresholdWAD: 3e17, // 30%
                fixedThreshold: 5_000_000 ether // 5M tokens
            }),
            lockInterval: 1 days, // 1 day
            maxLockIntervals: 14 days,
            decayCurveType: 0, // Linear
            decayCurveParameters: new uint256[](7e17), // 70% decay rate
            inactivityTimeout: 3 days, // 60 days
            proposerRequirements: IAuthorizer.ParticipantRequirements({
                eligibilityType: IAuthorizer.EligibilityType.MinBalance,
                minBalance: 10_000 ether,
                minHoldingDuration: 0,
                minLockAmount: 10_000 ether
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
