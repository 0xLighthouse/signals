// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {BondHook} from "../../src/BondHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol"; 

// Harness to test internal functions
contract BondHookHarness is BondHook {
    constructor(IPoolManager manager, address signals, address bondPricing) BondHook(manager, signals, bondPricing) {}

    function internalParseHookData(bytes calldata data)
        public
        returns (bool isBuy, uint256 tokenId, uint256 desiredPrice, bytes memory signature)
    {
        return _parseHookData(data);
    }

    function internalVerifySignature(bytes calldata signature)
        public
        returns (address)
    {
        return _verifySignature(signature);
    }
}