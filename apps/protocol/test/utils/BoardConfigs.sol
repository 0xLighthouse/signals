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
            owner: _owner,
            underlyingToken: _underlyingToken,
            opensAt: boardOpenAt_,
            closesAt: 0,
            boardMetadata: ISignals.Metadata({
                title: "Test Board",
                body: "Board using default config",
                attachments: new ISignals.Attachment[](0)
            }),
            acceptanceCriteria: ISignals.AcceptanceCriteria({
                permissions: ISignals.AcceptancePermissions.OnlyOwner,
                thresholdOverride: ISignals.ThresholdOverride.OnlyOwner,
                thresholdPercentTotalSupplyWAD: 0,
                minThreshold: 100_000 ether // 100k
            }),
            proposerRequirements: IAuthorizer.ParticipantRequirements({
                token: _underlyingToken,
                minBalance: 50_000 ether, // 50k tokens to propose,
                minHoldingDuration: 0, // Balance-only requirement
                minLockAmount: 0
            }),
            supporterRequirements: IAuthorizer.ParticipantRequirements({
                token: _underlyingToken,
                minBalance: 0, // No balance requirement
                minHoldingDuration: 0,
                minLockAmount: 0
            }),
            lockingConfig: ISignals.LockingConfig({
                lockInterval: 1 days, // 1 day
                maxLockIntervals: 365 days, // 1 year
                releaseLockDuration: 0,
                inactivityTimeout: 60 days // 60 days
            }),
            decayConfig: ISignals.DecayConfig({
                curveType: ISignals.DecayCurveType.Linear,
                params: new uint256[](1)
            })
        });
    }

    function defaultEdgeCityConfig(address _owner, address _underlyingToken, uint256 boardOpenAt_)
        internal
        pure
        returns (ISignals.BoardConfig memory)
    {
        return ISignals.BoardConfig({
            version: "0.0.2",
            owner: _owner,
            underlyingToken: _underlyingToken,
            opensAt: boardOpenAt_,
            closesAt: 0,
            boardMetadata: ISignals.Metadata({
                title: "Edge City Board",
                body: "Board using default edge city config",
                attachments: new ISignals.Attachment[](0)
            }),
            acceptanceCriteria: ISignals.AcceptanceCriteria({
                permissions: ISignals.AcceptancePermissions.Permissionless,
                thresholdOverride: ISignals.ThresholdOverride.OnlyOwner,
                thresholdPercentTotalSupplyWAD: 3e17, // 30%
                minThreshold: 5_000_000 ether // 5M tokens
            }),
            proposerRequirements: IAuthorizer.ParticipantRequirements({
                token: _underlyingToken,
                minBalance: 10_000 ether,
                minHoldingDuration: 0, // Balance-only requirement
                minLockAmount: 10_000 ether
            }),
            supporterRequirements: IAuthorizer.ParticipantRequirements({
                token: _underlyingToken,
                minBalance: 0, // No balance requirement
                minHoldingDuration: 0,
                minLockAmount: 0
            }),
            lockingConfig: ISignals.LockingConfig({
                lockInterval: 1 days, // 1 day
                maxLockIntervals: 14 days,
                releaseLockDuration: 0,
                inactivityTimeout: 3 days // 3 days
            }),
            decayConfig: ISignals.DecayConfig({
                curveType: ISignals.DecayCurveType.Linear,
                params: new uint256[](7e17) // 70% decay rate
            })
        });
    }
}
