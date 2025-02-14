// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

import {PipsLib} from "../src/PipsLib.sol";
import {ExampleSimplePricing} from "../src/pricing/ExampleSimplePricing.sol";
import {IBondPricing} from "../src/interfaces/IBondPricing.sol";

contract SimpleBondPricingTest is Test {
    using PipsLib for uint256;
    using FixedPointMathLib for uint256;

    IBondPricing pricing;
    uint256 bondCreated = 1739290000;
    uint256 totalDuration = 30 days;
    uint256 tokenAmount = 1 ether;
    uint256 discount = uint256(10).percentToPips();
    uint256 premium = uint256(10).percentToPips();

    function setUp() public {
        // Deploy example pricing contract
        pricing = IBondPricing(address(new ExampleSimplePricing(discount, premium)));
    }

    function test_BPStoPips() public pure {
        assertEq(PipsLib.percentToPips(10), 10_0000);
    }

    /// After maturity, the bond is worth the original value minus the discount
    function testBuyPriceAfterMaturity() public view {
        uint256 buyAfterMature = pricing.getBuyPrice({
            principal: tokenAmount,
            startTime: bondCreated,
            duration: totalDuration,
            currentTime: bondCreated + 40 days,
            bondMetadata: ""
        });

        // We expect full amount minus discount
        uint256 expected = tokenAmount - tokenAmount.mulDiv(discount, PipsLib.OneHundred);
        assertEq(buyAfterMature, expected);
    }

    // At 50% of the way to maturity, the bond is worth 50% * 90%
    function testBuyPriceBeforeMaturity() public view {
        uint256 buyAtFiftyPercentMature = pricing.getBuyPrice({
            principal: tokenAmount,
            startTime: bondCreated,
            duration: totalDuration,
            currentTime: bondCreated + 15 days,
            bondMetadata: ""
        });

        // We expect 50% of the amount, minus discount
        uint256 valueAtTime = (tokenAmount / 2);
        uint256 discountAtTime = valueAtTime.mulDiv(discount, PipsLib.OneHundred);
        assertEq(buyAtFiftyPercentMature, valueAtTime - discountAtTime);
    }

    function testSellPriceAfterMaturity() public view {
        uint256 sellAfterMature = pricing.getSellPrice({
            principal: tokenAmount,
            startTime: bondCreated,
            duration: totalDuration,
            currentTime: bondCreated + 40 days,
            bondMetadata: ""
        });

        // We expect full amount plus premium
        uint256 expected = tokenAmount + tokenAmount.mulDiv(premium, PipsLib.OneHundred);
        assertEq(sellAfterMature, expected);
    }

    function testSellPriceBeforeMaturity() public view {
        uint256 sellAtFiftyPercentMature = pricing.getSellPrice({
            principal: tokenAmount,
            startTime: bondCreated,
            duration: totalDuration,
            currentTime: bondCreated + 15 days,
            bondMetadata: ""
        });

        // We expect 50% of the amount, plus premium
        uint256 valueAtTime = (tokenAmount / 2);
        uint256 premiumAtTime = valueAtTime.mulDiv(premium, PipsLib.OneHundred);
        assertEq(sellAtFiftyPercentMature, valueAtTime + premiumAtTime);
    }
}
