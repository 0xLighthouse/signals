// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./PipsLib.sol";

contract BondPrices {
    using PipsLib for uint256;

    /**
     * @notice Calculates the current value of a bond based on time and discount
     * @param tokenAmount The nominal amount of tokens in the bond
     * @param lockCreated The timestamp when the bond was created
     * @param totalDuration The total duration of the bond lock period
     * @param currentTime The current timestamp
     * @param discount The discount rate in pips (percentage * 100)
     * @return value The current value of the bond
     */
    function currentBuyValue(
        uint256 tokenAmount,
        uint256 lockCreated,
        uint256 totalDuration,
        uint256 currentTime,
        uint256 discount
    ) external pure returns (uint256) {
        uint256 endTime = lockCreated + totalDuration;
        uint256 unlocked;
        // If the bond is not yet mature, return the nominal value
        if (currentTime >= endTime) {
            unlocked = tokenAmount;
        } else {
            uint256 remainingDuration = endTime - currentTime; 
            unlocked = tokenAmount - (tokenAmount * remainingDuration / totalDuration);
        }
        // Apply the discount
        uint256 value = unlocked - (unlocked * discount / uint256(100).percentToPips());
        return value;
    }
}
