// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/console.sol";

import {ExperimentTokenFactory} from "../src/ExperimentTokenFactory.sol";
import {ExperimentDeployerBase} from "./utils/ExperimentDeployerBase.sol";

/**
 * @notice Deploys a new ExperimentToken via an existing factory.
 *
 * Parameters passed as script arguments (in order):
 *  - network: Network name (e.g. "anvil", "base-sepolia")
 *  - factoryAddress: Address of the ExperimentTokenFactory
 *  - name: Token name
 *  - symbol: Token symbol
 *  - initialSupply: Initial token supply (use 0 for none)
 *  - owner: Token owner address (use address(0) for deployer)
 *  - allowanceSigner: Optional allowance signer (use address(0) to default to owner)
 *
 * Usage:
 *  forge script script/DeployFactoryToken.s.sol:DeployFactoryToken \
 *      --rpc-url $BASE_SEPOLIA_RPC \
 *      --broadcast \
 *      -s "run(string,address,string,string,uint256,address,address)" \
 *      "base-sepolia" \
 *      "0xYourFactoryAddress" \
 *      "MyToken" \
 *      "MTK" \
 *      "0" \
 *      "0x0000000000000000000000000000000000000000" \
 *      "0x0000000000000000000000000000000000000000"
 */
contract DeployFactoryToken is ExperimentDeployerBase {
    function run(
        string memory network,
        address factoryAddress,
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address owner,
        address allowanceSigner
    ) external {
        require(factoryAddress != address(0), "Factory address required");
        require(bytes(name).length > 0, "Token name required");
        require(bytes(symbol).length > 0, "Token symbol required");

        (uint256 deployerPrivateKey, address deployerAddress) = _loadDeployer(network);

        // Use deployer as owner if address(0) is passed
        if (owner == address(0)) {
            owner = deployerAddress;
        }

        if (allowanceSigner == address(0)) {
            allowanceSigner = owner;
        }

        console.log("=== Deploy ExperimentToken ===");
        console.log("Factory:", factoryAddress);
        console.log("Deployer:", deployerAddress);
        console.log("Owner:", owner);
        console.log("Allowance signer:", allowanceSigner);
        console.log("Name:", name);
        console.log("Symbol:", symbol);
        console.log("Initial Supply:", initialSupply);

        vm.startBroadcast(deployerPrivateKey);
        address tokenAddress = ExperimentTokenFactory(factoryAddress).deployToken(
            name,
            symbol,
            initialSupply,
            owner,
            allowanceSigner
        );
        vm.stopBroadcast();

        console.log("ExperimentToken deployed at:", tokenAddress);
    }
}
