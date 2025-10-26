// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import {IIncentivizer} from "./interfaces/IIncentivizer.sol";
import {IIncentivesPool} from "./interfaces/IIncentivesPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISignals} from "./interfaces/ISignals.sol";
import {IVotes} from "./interfaces/IVotes.sol";

abstract contract SignalsIncentivizer is IIncentivizer {
    uint256 constant SIGNALS_BUCKETS = 24;

    struct IncentiveBucket {
        uint128 bucketIncentiveCredits;
        uint128 endTime;
    }

    /// @notice (Optional) Reference to the IncentivesPool contract (can be set before board opens)
    IIncentivesPool public incentivesPool;

    /// @notice Configuration for board-wide incentive rewards (internal storage)
    IncentivesConfig internal _incentivesConfig;

    uint256[] internal _totalIncentiveCredit;
    uint256[SIGNALS_BUCKETS][] internal _bucketIncentiveCredits;

    /// @notice Set the incentives pool and configuration
    /// @param incentivesPool_ The address of the incentives pool
    /// @param incentivesConfig_ The configuration for the incentives
    /// @dev Reverts if the incentives pool is already set or if this board is not authorized by the incentives pool
    function _setIncentivesPool(
        address incentivesPool_,
        IncentivesConfig calldata incentivesConfig_
    ) internal {
        if (address(incentivesPool_) == address(0)) {
            revert ISignals.Signals_ZeroAddressIncentivesPool();
        }
        if (address(incentivesPool) != address(0)) {
            revert ISignals.Signals_IncentivesPoolAlreadySet();
        }

        if (!IIncentivesPool(incentivesPool_).isBoardApproved(address(this))) {
            revert ISignals.Signals_IncentivesPoolNotApproved();
        }
        incentivesPool = IIncentivesPool(incentivesPool_);
        _incentivesConfig = incentivesConfig_;
    }
}
