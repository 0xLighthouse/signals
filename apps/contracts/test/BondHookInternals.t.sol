// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {Signals} from "../src/Signals.sol";
import {BondHook} from "../src/BondHook.sol";
import {BondHookHarness} from "./utils/BondHookHarness.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {SignalsHarness} from "./utils/SignalsHarness.sol";

import {SortTokens} from "@uniswap/v4-core/test/utils/SortTokens.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PipsLib} from "../src/PipsLib.sol";
import {ExampleSimplePricing} from "../src/pricing/ExampleSimplePricing.sol";
import {IBondPricing} from "../src/interfaces/IBondPricing.sol";

contract BondHookTest is Test, Deployers, SignalsHarness {
    using PipsLib for uint256;

    MockERC20 bondToken;
    Signals signals;
    IBondPricing bondPricing;
    BondHookHarness hook;

    function setUp() public {
        // Deploy PoolManager and Router contracts
        deployFreshManagerAndRouters();

        signals = deploySignals(true);

        bondPricing = new ExampleSimplePricing(uint256(100).percentToPips(), uint256(100).percentToPips());

        uint160 flags = uint160(
            Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG // | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG
        );
        deployCodeTo("utils/BondHookHarness.sol", abi.encode(manager, signals, bondPricing), address(flags));

        hook = BondHookHarness(address(flags));
    }

    function test_parseHookDataAndSignature() public {
       // ID of the NFT being bought/sold
       uint256 inputTokenId = 42;
       // Desired price of the NFT (unrelated to slippage settings for swaps)
       uint256 inputDesiredPrice = 12 ether;
       // Signature -- for now, it is just the user's address
       address user = makeAddr("user");
       bytes memory inputSignature = abi.encode(user);

       // Encode the hookData
       bytes memory inputHookData = abi.encode(inputTokenId, inputDesiredPrice, inputSignature);

       // Parse the hookData
       (bool isBuy, uint256 tokenId, uint256 desiredPrice, bytes memory signature) = hook.internalParseHookData(inputHookData);

       assertEq(isBuy, true, "isBuy should be true");
       assertEq(tokenId, inputTokenId, "tokenId should be equal to inputTokenId");
       assertEq(desiredPrice, inputDesiredPrice, "desiredPrice should be equal to inputDesiredPrice");

       // Decode the signature
       address decodedSignature = hook.internalVerifySignature(signature);
       assertEq(decodedSignature, user, "decodedUser should be equal to user");
    }
}
