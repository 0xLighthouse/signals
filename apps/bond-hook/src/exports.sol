// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BondHook, BondPoolState, CallbackData, Action, LiquidityData, SwapData, DesiredCurrency, LiquidityPosition} from "./BondHook.sol";
import {IBondIssuer} from "./interfaces/IBondIssuer.sol";
import {IBondPricing} from "./interfaces/IBondPricing.sol";
import {PipsLib} from "./PipsLib.sol";
import {ExampleLinearPricing} from "./pricing/ExampleLinearPricing.sol";

// Export all the key contracts and interfaces
struct Exports {
    BondHook bondHook;
    IBondIssuer issuer;
    IBondPricing pricing;
    PipsLib pipsLib;
    ExampleLinearPricing linearPricing;
}