// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/console.sol";

import {ExperimentTokenFactory} from "../src/ExperimentTokenFactory.sol";
import {ExperimentDeployerBase} from "./utils/ExperimentDeployerBase.sol";

/**
 * @notice Deploys the ExperimentTokenFactory contract.
 *
 * Usage:
 *  forge script script/DeployFactory.s.sol:DeployFactory \
 *      --rpc-url $BASE_SEPOLIA_RPC \
 *      --broadcast \
 *      --private-key $TESTNET_DEPLOYER_PRIVATE_KEY \
 *      -s "run(string)" \
 *      "base-sepolia"
 *
 * [local development]
 *  forge script script/DeployFactory.s.sol:DeployFactory \
 *      --rpc-url $LOCAL_RPC \
 *      --broadcast \
 *      --private-key $TESTNET_DEPLOYER_PRIVATE_KEY \
 *      -s "run(string)" \
 *      "anvil"
 */
contract DeployFactory is ExperimentDeployerBase {
    function run(string memory network) external {
        if (!isSupportedNetwork(network)) {
            revert(string.concat("Unsupported network [", network, "] provided"));
        }

        (uint256 deployerPrivateKey, address deployerAddress) = _loadDeployer();

        console.log("=== Deploy ExperimentTokenFactory ===");
        console.log("Deployer:", deployerAddress);

        vm.startBroadcast(deployerPrivateKey);
        ExperimentTokenFactory factory = new ExperimentTokenFactory();
        vm.stopBroadcast();

        console.log("Factory deployed at:", address(factory));
    }
}


