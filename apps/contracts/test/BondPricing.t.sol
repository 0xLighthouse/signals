// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/console.sol';

import {PipsLib} from '/PipsLib.sol';
import {BasisPointPricing} from '/BasisPointPricing.sol';
import {IBondPricing} from '/interfaces/IBondPricing.sol';

contract BondPricingTest is Test {
  using PipsLib for uint256;

  IBondPricing pricing;

  function setUp() public {
    // Deploy instance of BasisPointPricing

    pricing = IBondPricing(
      address(new BasisPointPricing(uint256(10).percentToPips(), uint256(10).percentToPips()))
    );
  }

  function test_BPStoPips() public pure {
    assertEq(PipsLib.percentToPips(10), 10_0000);
  }

  // TODO: -------------------------------------------------------------------------------------------------
  // TODO: Not sure if this is correct, we should always favour LPs.
  // TODO:  ie. If profit there is profit we should sell the bond
  // TODO: -------------------------------------------------------------------------------------------------
  /// After maturity, the bond is worth the original value minus the discount
  function test_CalculateBidAfterMaturity() public view {
    uint256 buyAfterMature = pricing.calculateBid({
      tokenAmount: 1000,
      lockCreated: 1739290000,
      totalDuration: 600,
      currentTime: 1739290700
    });
    assertEq(buyAfterMature, 900);
  }

  // At 50% of the way to maturity, the bond is worth 50% * 90%
  function test_CalculateBidBeforeMaturity() public view {
    uint256 buyAtFiftyPercentMature = pricing.calculateBid({
      tokenAmount: 1000,
      lockCreated: 1739290000,
      totalDuration: 600,
      currentTime: 1739290300
    });
    assertEq(buyAtFiftyPercentMature, 450);
  }
}
