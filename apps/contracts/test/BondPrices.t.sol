// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/console.sol';

import {BondPrices} from '../src/BondPrices.sol';
import '../src/PipsLib.sol';

contract BondHookTest is Test {
  using PipsLib for uint256;

  function setUp() public {}

  function testBondValues() public {

    BondPrices prices = new BondPrices();

    // Sanity check our pips library
    assertEq(uint256(10).percentToPips(), 10_0000);
    
    uint256 buyAfterMature = prices.currentBuyValue({
      tokenAmount: 1000, 
      lockCreated: 1739290000, 
      totalDuration: 600, 
      currentTime: 1739290700, 
      discount: uint256(10).percentToPips()
      });

    // After maturity, the bond is worth the original value minus the discount
    assertEq(buyAfterMature, 900);

    uint256 buyAtFiftyPercentMature = prices.currentBuyValue({
      tokenAmount: 1000, 
      lockCreated: 1739290000, 
      totalDuration: 600, 
      currentTime: 1739290300, 
      discount: uint256(10).percentToPips()
      });

    // At 50% of the way to maturity, the bond is worth 50% * 90%
    assertEq(buyAtFiftyPercentMature, 450);
  }
}
