// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {BondHook, BondHookOptions} from "../src/BondHook.sol";
import {BondHookLibrary} from "../src/interfaces/IBondHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {ExampleLinearPricing} from "../src/pricing/ExampleLinearPricing.sol";
import {IBondPricing} from "../src/interfaces/IBondPricing.sol";
import {HookMiner} from "v4-periphery/utils/HookMiner.sol";

/**
 * Deploys an new instance of Bond Hook and example pricing contract.
 *
 * Notes:
 *  - https://github.com/Uniswap/v4-periphery/tree/main/broadcast
 *
 * Known deployments
 *  - Arbitrum One
 *    - V4 Pool Manager: 0xfb3e0c6f74eb1a21cc1da29aec80d2dfe6c9a317
 */
contract DeployManagerAndHook is Script {
    function run() external {
        // Load the private key from the environment
        uint256 deployerPrivateKey = vm.envUint("TESTNET_DEPLOYER_PRIVATE_KEY");
        address _deployer = vm.addr(deployerPrivateKey);

        address manager = vm.envAddress("TESTNET_POOL_MANAGER");
        address bondIssuer = vm.envAddress("TESTNET_BOND_ISSUER");

        // Log the deployer addresses
        console.log("----- Accounts -----");
        console.log("Deployer:", _deployer);

        // 1. Deploy example pricing contract
        vm.startBroadcast(_deployer);
        IBondPricing pricing = new ExampleLinearPricing(10_0000, 10_0000); // 10% fees on each side
        vm.stopBroadcast();

        console.log("Pricing contract", address(pricing));

        // Create BondHookOptions struct first to ensure consistency
        BondHookOptions memory options = BondHookOptions({
            poolManager: IPoolManager(manager),
            bondIssuer: address(bondIssuer),
            bondPricing: address(pricing),
            ownerFeeAsPips: 0,
            feeCreditRatioAsPips: 0,
            swapFeeNormal: 0,
            swapFeeDiscounted: 0
        });

        // Use the same encoding for both find and deployment
        bytes memory constructorArgs = abi.encode(options);

        address CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
        (address hookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_DEPLOYER, BondHookLibrary.flags, type(BondHook).creationCode, constructorArgs);

        console.log("Expected address:", hookAddress);

        vm.startBroadcast(_deployer);
        BondHook hook = new BondHook{salt: salt}(options);
        console.log("Deployed to:", address(hook));
        vm.stopBroadcast();
    }
}
