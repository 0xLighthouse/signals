// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Hooks} from "v4-core/libraries/Hooks.sol";
import {Currency} from "v4-core/types/Currency.sol";

library BondHookLibrary {
    uint160 constant flags = Hooks.BEFORE_INITIALIZE_FLAG | Hooks.AFTER_INITIALIZE_FLAG
        | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG;
}

interface IBondHook {}

interface IBondHookLegacy {
    function bondToken() external view returns (Currency);
}
