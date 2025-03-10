// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {BondHook} from "../src/BondHook.sol";
import { BondHookLibrary } from "../src/interfaces/IBondHook.sol";
import { IPoolManager } from "v4-core/interfaces/IPoolManager.sol";
import { Deployers } from "@uniswap/v4-core/test/utils/Deployers.sol";
import { ExampleLinearPricing } from "../src/pricing/ExampleLinearPricing.sol";
import { PipsLib } from "../src/PipsLib.sol";
import { IBondPricing } from "../src/interfaces/IBondPricing.sol";
import { HookMiner } from "v4-periphery/utils/HookMiner.sol";

/**
 * @notice forge script script/Deploy.s.sol --fork-url $ARBITRUM_SEPOLIA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY
 * @notice forge script script/Deploy.s.sol --fork-url $ARBITRUM_SEPOLIA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY --verify
 */
contract DeployManagerAndHook is Script, Deployers {
    address _deployer;

    function run() external {
        // Load the private key from the environment
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_TESTNET_PRIVATE_KEY");
        address bondIssuer = vm.envAddress("BOND_ISSUER");

        deployFreshManagerAndRouters();

        _deployer = vm.addr(deployerPrivateKey);

        // Log the deployer addresses
        console.log("----- Accounts -----");
        console.log("Deployer:", _deployer);
      
      vm.startBroadcast(deployerPrivateKey);
        console.log("Deployer address", address(this));
        // Deploy pricing contract
        IBondPricing pricing = new ExampleLinearPricing(PipsLib.percentToPips(10), PipsLib.percentToPips(10));
        
        address CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
        (address hookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER,
            BondHookLibrary.flags,
            type(BondHook).creationCode,
            abi.encode(IPoolManager(manager), address(bondIssuer), address(pricing))
        );

        console.log("Flags", address(BondHookLibrary.flags));
        console.log("Hook address", hookAddress);
        console.log("Salt", uint256(salt));

        // Deploy hook
        BondHook hook = new BondHook{salt: salt}(IPoolManager(manager), address(bondIssuer), address(pricing));
        vm.stopBroadcast();
        console.log("BondHookContract", address(hook));       
    }
}
