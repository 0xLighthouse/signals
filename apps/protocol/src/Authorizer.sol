// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import {IAuthorizer} from "./interfaces/IAuthorizer.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISignals} from "./interfaces/ISignals.sol";
import {IVotes} from "./interfaces/IVotes.sol";

abstract contract SignalsAuthorizer is IAuthorizer {
    address public authorizationToken;

    /// @notice Configuration for proposer requirements (immutable after initialization)
    ParticipantRequirements public proposerRequirements;

    /// @notice Configuration for participant requirements (immutable after initialization)
    ParticipantRequirements public supporterRequirements;

    /// @notice Modifier to check if caller is eligible to propose
    modifier senderCanPropose(uint256 lockAmount) {
        _senderCanPropose(lockAmount);
        _;
    }

    function _senderCanPropose(uint256 lockAmount) internal view {
        EligibilityResult result =
            _accountCanParticipate(msg.sender, lockAmount, proposerRequirements);
        if (result == EligibilityResult.InsufficientLockAmount) {
            revert ISignals.Signals_InsufficientLockAmount();
        }
        if (result == EligibilityResult.InsufficientCurrentBalance) {
            revert ISignals.Signals_InsufficientTokens();
        }
        if (result == EligibilityResult.InsufficientHistoricalBalance) {
            revert ISignals.Signals_InsufficientTokenDuration();
        }
        if (result == EligibilityResult.TokenNotSupported) {
            revert ISignals.Signals_TokenHasNoCheckpointSupport();
        }
    }

    /// @notice Modifier to check participant requirements
    modifier senderCanSupport(uint256 lockAmount) {
        _senderCanSupport(lockAmount);
        _;
    }

    function _senderCanSupport(uint256 lockAmount) internal view {
        EligibilityResult result =
            _accountCanParticipate(msg.sender, lockAmount, supporterRequirements);
        if (result == EligibilityResult.InsufficientLockAmount) {
            revert ISignals.Signals_InsufficientLockAmount();
        }
        if (result == EligibilityResult.InsufficientCurrentBalance) {
            revert ISignals.Signals_InsufficientTokens();
        }
        if (result == EligibilityResult.InsufficientHistoricalBalance) {
            revert ISignals.Signals_InsufficientTokenDuration();
        }
        if (result == EligibilityResult.TokenNotSupported) {
            revert ISignals.Signals_TokenHasNoCheckpointSupport();
        }
    }

    function _accountCanParticipate(
        address account,
        uint256 lockAmount,
        ParticipantRequirements memory reqs
    ) internal view returns (EligibilityResult result) {
        if (lockAmount < reqs.minLockAmount) {
            return EligibilityResult.InsufficientLockAmount;
        }

        // TODO: This needs to be rechecked
        if (reqs.minHoldingDuration > 0) {
            // Check historical balance using ERC20Votes checkpoints
            try IVotes(authorizationToken).getPastVotes(
                account, block.number - reqs.minHoldingDuration
            ) returns (uint256 pastBalance) {
                // Verify they held the minimum balance for the required duration
                if (pastBalance < reqs.minBalance) {
                    return EligibilityResult.InsufficientHistoricalBalance;
                }
            } catch {
                // Token doesn't support checkpoints - cannot verify holding duration
                return EligibilityResult.TokenNotSupported;
            }
        }

        // Check current balance
        uint256 balance = IERC20(authorizationToken).balanceOf(account);
        if (balance < reqs.minBalance) {
            return EligibilityResult.InsufficientCurrentBalance;
        }
        return EligibilityResult.Eligible;
    }

    function accountCanPropose(address account, uint256 lockAmount)
        external
        view
        returns (bool result)
    {
        return _accountCanParticipate(account, lockAmount, proposerRequirements)
            == EligibilityResult.Eligible;
    }

    function accountCanSupport(address account, uint256 lockAmount)
        external
        view
        returns (bool result)
    {
        return _accountCanParticipate(account, lockAmount, supporterRequirements)
            == EligibilityResult.Eligible;
    }

    /// @notice Internal function to validate participant requirements
    /// @dev Validates that requirements are logically consistent:
    ///      - If minHoldingDuration is set, minBalance must also be set
    ///        (cannot check holding duration without a balance threshold)
    function _validateParticipantRequirements(ParticipantRequirements memory reqs) internal pure {
        // If holding duration is required, balance must also be required
        if (reqs.minHoldingDuration > 0 && reqs.minBalance == 0) {
            revert ISignals.Signals_InvalidArguments();
        }

        if (reqs.minLockAmount > reqs.minBalance) {
            revert ISignals.Signals_InvalidArguments();
        }
    }

    /// @inheritdoc IAuthorizer
    function getProposerRequirements() external view returns (ParticipantRequirements memory) {
        return proposerRequirements;
    }

    /// @inheritdoc IAuthorizer
    function getParticipantRequirements() external view returns (ParticipantRequirements memory) {
        return supporterRequirements;
    }
}
