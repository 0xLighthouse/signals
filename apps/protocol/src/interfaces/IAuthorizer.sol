// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

interface IAuthorizer {
    enum EligibilityType {
        None, // No requirements
        MinBalance, // Requires minimum token balance
        MinBalanceAndDuration // Requires min balance held for min duration

    }

    /**
     * @notice Requirements for who can participate (support initiatives)
     *
     * @param eligibilityType Type of eligibility check (None, MinBalance, MinBalanceAndDuration)
     * @param minBalance Minimum token balance required to be eligible
     * @param minHoldingDuration Minimum blocks tokens must be held (for MinBalanceAndDuration)
     * @param minLockAmount Minimum tokens that must be locked
     */
    struct ParticipantRequirements {
        EligibilityType eligibilityType;
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
