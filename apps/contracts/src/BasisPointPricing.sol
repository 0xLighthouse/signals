// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import './PipsLib.sol';
import './interfaces/IBondPricing.sol';

/**
 * @title Basis Point Pricing
 *
 * @notice The pricing model for bonds is based on the time since the bond was created and the discount rate.
 */
contract BasisPointPricing is IBondPricing {
  using PipsLib for uint256;

  // Immutable discount on bids
  uint256 public immutable bidDiscount;

  // Immutable premium on asks
  uint256 public immutable askPremium;

  constructor(uint256 _bidDiscount, uint256 _askPremium) {
    bidDiscount = _bidDiscount;
    askPremium = _askPremium;
  }

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
  ) external view returns (uint256) {
    uint256 endTime = lockCreated + totalDuration;
    uint256 unlocked;
    // If the bond is not yet mature, return the nominal value
    if (currentTime >= endTime) {
      unlocked = tokenAmount;
    } else {
      uint256 remainingDuration = endTime - currentTime;
      unlocked = tokenAmount - ((tokenAmount * remainingDuration) / totalDuration);
    }
    // Apply the discount
    uint256 value = unlocked - ((unlocked * bidDiscount) / uint256(100).percentToPips());
    return value;
  }
}
