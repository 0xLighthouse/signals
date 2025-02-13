// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IBondPricing
 * @dev Interface for the BondPricing contract
 */
interface IBondPricing {
    /**
     * @notice Returns the price at which the pool would buy a bond
     *
     * @param principal The principal amount of the bond
     * @param startTime The timestamp when the bond was created
     * @param duration The total duration of the bond lock period
     * @param currentTime The current timestamp
     *
     * @return price The buy price quoted by the pool
     */
    function getBuyPrice(
        uint256 principal,
        uint256 startTime,
        uint256 duration,
        uint256 currentTime,
        bytes calldata bondMetadata
    ) external view returns (uint256);

    /**
     * @notice Returns the price at which the pool would sell a bond
     *
     * @param principal The principal amount of the bond
     * @param startTime The timestamp when the bond was created
     * @param duration The total duration of the bond lock period
     * @param currentTime The current timestamp
     *
     * @return price The sell price quoted by the pool
     */
    function getSellPrice(
        uint256 principal,
        uint256 startTime,
        uint256 duration,
        uint256 currentTime,
        bytes calldata bondMetadata
    ) external view returns (uint256);
}
