// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {ISignals} from "./ISignals.sol";

/**
 * @title ISignalsFactory
 * @notice Interface for the Signals factory contract that deploys new Signals boards
 * @dev Factory handles board deployment and initialization with consistent versioning
 */
interface ISignalsFactory {
    /**
     * @notice Configuration for deploying a new Signals board
     * @dev Similar to BoardConfig but without version (added by factory)
     *
     * @param owner The address which will own the contract
     * @param underlyingToken The address of the underlying ERC20 token
     * @param acceptanceThreshold Weight required for an initiative to be accepted
     * @param maxLockIntervals Maximum lock intervals allowed
     * @param proposalCap Maximum number of active proposals
     * @param lockInterval Time interval for lockup duration and decay calculations
     * @param decayCurveType Which decay curve to use (0 = linear, 1 = exponential)
     * @param decayCurveParameters Parameters to control the decay curve behavior
     * @param proposerRequirements Requirements for who can propose
     * @param participantRequirements Requirements for who can support initiatives
     * @param releaseLockDuration Duration tokens remain locked after acceptance
     * @param boardOpensAt Timestamp when board opens for participation
     * @param boardIncentives Configuration for board-wide incentive rewards
     */
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
        uint256 boardOpensAt;
        ISignals.BoardIncentives boardIncentives;
    }

    /**
     * @notice Create a new Signals board with the given configuration
     * @dev Factory automatically adds version to the configuration
     * @param config Board configuration parameters
     * @return Address of the newly deployed Signals contract
     */
    function create(ISignalsFactory.FactoryDeployment calldata config) external payable returns (address);
}
