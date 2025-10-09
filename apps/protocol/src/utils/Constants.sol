// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

/**
 * @title SignalsConstants
 * @notice Centralized constants used across the Signals protocol
 * @dev Provides type limits, decay curve constants, time constants, and common values
 * @author Lighthouse Labs <https://lighthouse.cx>
 */
library SignalsConstants {
    /*//////////////////////////////////////////////////////////////
                            TYPE LIMITS
    //////////////////////////////////////////////////////////////*/

    /// @notice Maximum value for uint256
    uint256 internal constant MAX_UINT256 = type(uint256).max;

    /// @notice Maximum value for uint128
    uint128 internal constant MAX_UINT128 = type(uint128).max;

    /// @notice Zero address constant
    address internal constant ADDRESS_ZERO = address(0);

    /*//////////////////////////////////////////////////////////////
                        DECAY CURVE TYPES
    //////////////////////////////////////////////////////////////*/

    /// @notice Linear decay curve type identifier
    uint256 internal constant DECAY_LINEAR = 0;

    /// @notice Exponential decay curve type identifier
    uint256 internal constant DECAY_EXPONENTIAL = 1;

    /// @notice Maximum number of decay curve types supported
    uint256 internal constant MAX_DECAY_CURVE_TYPES = 2;

    /// @notice Expected number of parameters for decay curves
    uint256 internal constant DECAY_CURVE_PARAM_LENGTH = 1;

    /*//////////////////////////////////////////////////////////////
                          TIME CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Number of seconds in one day
    uint256 internal constant SECONDS_PER_DAY = 86400;

    /// @notice Default inactivity timeout (60 days in seconds)
    uint256 internal constant DEFAULT_ACTIVITY_TIMEOUT = 60 days;

    /*//////////////////////////////////////////////////////////////
                        PRECISION CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Precision for calculations (1e18 = 1.0 in fixed-point)
    uint256 internal constant PRECISION = 1e18;

    /// @notice Basis points (100 = 100%)
    uint256 internal constant BASIS_POINTS = 100;

    /*//////////////////////////////////////////////////////////////
                        INCENTIVE CURVE TYPES
    //////////////////////////////////////////////////////////////*/

    /// @notice Linear incentive curve type identifier
    uint256 internal constant INCENTIVE_CURVE_LINEAR = 0;

    /// @notice Exponential incentive curve type identifier (future use)
    uint256 internal constant INCENTIVE_CURVE_EXPONENTIAL = 1;

    /*//////////////////////////////////////////////////////////////
                        INITIALIZATION VALUES
    //////////////////////////////////////////////////////////////*/

    /// @notice Starting token ID for NFT locks
    uint256 internal constant INITIAL_TOKEN_ID = 1;

    /// @notice Starting initiative count
    uint256 internal constant INITIAL_INITIATIVE_COUNT = 0;

    /// @notice Starting bounty count
    uint256 internal constant INITIAL_BOUNTY_COUNT = 0;

    /// @notice Starting version number
    uint256 internal constant INITIAL_VERSION = 0;
}
