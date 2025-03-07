// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";

import "../PipsLib.sol";
import "../interfaces/IBondPricing.sol";

/**
 * @title An example bond pricing contract
 *
 * @notice The pricing model for bonds is based on the time since the bond was created and the discount rate.
 */
contract ExampleLinearPricing is IBondPricing {
    using PipsLib for uint256;
    using FixedPointMathLib for uint256;
    // Discount and premium rates to generate profit for the LPs. These could instead be changeable or dynamic based on some other factor

    uint256 public immutable bidDiscount;
    uint256 public immutable askPremium;

    constructor(uint256 _bidDiscount, uint256 _askPremium) {
        bidDiscount = _bidDiscount;
        askPremium = _askPremium;
    }

    /**
     * @notice Calculates what a pool would be willing to pay for a bond
     *
     * @param principal The principal amount of the bond
     * @param startTime The timestamp when the bond was created
     * @param duration The total duration of the bond lock period
     * @param currentTime The current timestamp
     * @return price The buy price quoted by the pool
     */
    function getBuyPrice(uint256 principal, uint256 startTime, uint256 duration, uint256 currentTime, bytes calldata)
        external
        view
        returns (uint256)
    {
        uint256 currentValue = _calculateCurrentBondValue(principal, startTime, duration, currentTime);
        uint256 discount = currentValue.mulDivDown(bidDiscount, PipsLib.OneHundred);
        return currentValue - discount;
    }

    /**
     * @notice Calculates what a pool would be willing to sell a bond for
     *
     * @param principal The principal amount of the bond
     * @param startTime The timestamp when the bond was created
     * @param duration The total duration of the bond lock period
     * @param currentTime The current timestamp
     *
     * @return price The sell price quoted by the pool
     */
    function getSellPrice(uint256 principal, uint256 startTime, uint256 duration, uint256 currentTime, bytes calldata)
        external
        view
        returns (uint256)
    {
        uint256 currentValue = _calculateCurrentBondValue(principal, startTime, duration, currentTime);
        uint256 premium = currentValue.mulDivUp(askPremium, PipsLib.OneHundred);
        return currentValue + premium;
    }

    /**
     * @notice Calculates the current value of a bond based on time.
     * This could be updated to use a more complex model.
     *
     * @param principal The principal amount of the bond
     * @param startTime The timestamp when the bond was created
     * @param duration The total duration of the bond lock period
     * @param currentTime The current timestamp
     *
     * @return price The current value of the bond
     */
    function _calculateCurrentBondValue(uint256 principal, uint256 startTime, uint256 duration, uint256 currentTime)
        internal
        pure
        returns (uint256)
    {
        uint256 endTime = startTime + duration;
        // If the bond is not yet mature, return the nominal value
        if (currentTime >= endTime) {
            return principal;
        } else {
            uint256 remainingDuration = endTime - currentTime;
            return principal - principal.mulDivDown(remainingDuration, duration);
        }
    }
}