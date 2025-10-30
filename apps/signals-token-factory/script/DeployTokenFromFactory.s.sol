// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/console.sol";

import {ExperimentTokenFactory} from "../src/ExperimentTokenFactory.sol";
import {ExperimentToken} from "../src/ExperimentToken.sol";
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
contract DeployTokenFromFactory is ExperimentDeployerBase {
    function run(string memory network, address factoryAddress, string memory name, string memory symbol) external {
        require(factoryAddress != address(0), "Factory address required");
        require(bytes(name).length > 0, "Token name required");
        require(bytes(symbol).length > 0, "Token symbol required");

        (uint256 deployerPrivateKey,) = _loadPrivateKey(network, "deployer");

        vm.startBroadcast(deployerPrivateKey);
        address tokenAddress = ExperimentTokenFactory(factoryAddress).deployToken(name, symbol);
        vm.stopBroadcast();

        ExperimentToken token = ExperimentToken(tokenAddress);

        console.log("=== Deploy ExperimentToken from Factory===");
        console.log("Owner:", token.owner());
        console.log("Signer:", token.allowanceSigner());
        console.log("Token Address:", tokenAddress);
        console.log("Name:", token.name());
        console.log("Symbol:", token.symbol());

        console.log("ScriptOutput:", tokenAddress);
    }
}
