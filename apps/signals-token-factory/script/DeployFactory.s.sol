// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/console.sol";

import {ExperimentTokenFactory} from "../src/ExperimentTokenFactory.sol";
import {ExperimentDeployerBase} from "./utils/ExperimentDeployerBase.sol";

/**
 * @notice Deploys the ExperimentTokenFactory contract.
 */
contract DeployFactory is ExperimentDeployerBase {
    function run(string memory network) external {
        if (!isSupportedNetwork(network)) {
            revert(string.concat("Unsupported network [", network, "] provided"));
        }

        (uint256 deployerPrivateKey, address deployerAddress) = _loadDeployer(network);

        console.log("=== Deploy ExperimentTokenFactory ===");
        console.log("Deployer:", deployerAddress);

        vm.startBroadcast(deployerPrivateKey);
        ExperimentTokenFactory factory = new ExperimentTokenFactory();
        vm.stopBroadcast();

        console.log("Factory deployed at:", address(factory));
    }
}


