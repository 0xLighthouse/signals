// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IBondPricing
 * @dev Interface for the BondPricing contract
 */
interface IBondPricing {
  /**
   * @notice Calculates the current value of a bond based on time and discount
   *
   * @param tokenAmount The nominal amount of tokens in the bond
   * @param lockCreated The timestamp when the bond was created
   * @param totalDuration The total duration of the bond lock period
   * @param currentTime The current timestamp
   *
   * @return value The current value of the bond
   */
  function calculateBid(
    uint256 tokenAmount,
    uint256 lockCreated,
    uint256 totalDuration,
    uint256 currentTime
  ) external view returns (uint256);

  // TODO: Add calculateAsk()
}
