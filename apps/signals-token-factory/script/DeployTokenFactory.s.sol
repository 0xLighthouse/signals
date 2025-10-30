// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/console.sol";

import {ExperimentTokenFactory} from "../src/ExperimentTokenFactory.sol";
import {ExperimentDeployerBase} from "./utils/ExperimentDeployerBase.sol";

/**
 * @notice Deploys the ExperimentTokenFactory contract.
 */
contract DeployTokenFactory is ExperimentDeployerBase {
    function run(string memory network) external {
        if (!isSupportedNetwork(network)) {
            revert(string.concat("Unsupported network [", network, "] provided"));
        }

        (uint256 deployerPrivateKey, address deployerAddress) = _loadPrivateKey(network, "deployer");
        // Load signer private key, and find the address
        (, address allowanceSigner) = _loadPrivateKey(network, "signer");
        console.log("=== Deploy ExperimentTokenFactory ===");
        console.log("Deployer:", deployerAddress);
        console.log("Allowance signer:", allowanceSigner);

        vm.startBroadcast(deployerPrivateKey);
        // vm.startBroadcast(deployerPrivateKey);
        ExperimentTokenFactory factory = new ExperimentTokenFactory(allowanceSigner);
        vm.stopBroadcast();

        console.log("ScriptOutput:", address(factory));
    }
}
