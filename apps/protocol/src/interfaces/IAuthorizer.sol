// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

interface IAuthorizer {
    /**
     * @notice Requirements for who can participate (support initiatives)
     * @dev Eligibility type is inferred from field values:
     *      - minBalance == 0: No balance requirements
     *      - minBalance > 0 && minHoldingDuration == 0: Balance-only requirement
     *      - minBalance > 0 && minHoldingDuration > 0: Balance + duration requirement
     *
     * @param minBalance Minimum token balance required to be eligible
     * @param minHoldingDuration Minimum blocks tokens must be held
     * @param minLockAmount Minimum tokens that must be locked
     */
    struct ParticipantRequirements {
        uint256 minBalance;
        uint256 minHoldingDuration;
        uint256 minLockAmount;
    }

    enum EligibilityResult {
        Eligible,
        TokenNotSupported,
        InsufficientCurrentBalance,
        InsufficientHistoricalBalance,
        InsufficientLockAmount
    }

    /// @notice Get current proposer requirements (immutable)
    /// @return Current proposer requirements configuration
    function getProposerRequirements() external view returns (ParticipantRequirements memory);

    /// @notice Get current participant requirements (immutable)
    /// @return Current participant requirements configuration
    function getParticipantRequirements() external view returns (ParticipantRequirements memory);
}
