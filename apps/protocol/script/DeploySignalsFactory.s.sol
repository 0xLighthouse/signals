// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/console.sol";
import {SharedScriptBase} from "@shared/SharedScriptBase.sol";
import {SignalsFactory} from "../src/SignalsFactory.sol";

/**
 * This script deploys the SignalsFactory contract
 */
contract DeploySignalsFactory is SharedScriptBase {
    /**
     * @param network The network to deploy the contracts to
     */
    function run(string memory network) external {
        if (!isSupportedNetwork(network)) {
            revert(string.concat("Unsupported network [", network, "] provided"));
        }

        (uint256 deployerPrivateKey, address deployerAddress) = _loadPrivateKey(network, "deployer");

        // Deploy factory
        vm.startBroadcast(deployerPrivateKey);
        SignalsFactory factory = new SignalsFactory();
        vm.stopBroadcast();

        console.log("=== Signals Factory Deployment ===");
        console.log("Deployer:", deployerAddress);
        console.log("FactoryVersion: ", factory.version());
        console.log("Factory Contract Address: ", address(factory));

        console.log("ScriptOutput:", address(factory));
    }
}
