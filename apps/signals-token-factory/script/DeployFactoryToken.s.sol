// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/console.sol";

import {ExperimentTokenFactory} from "../src/ExperimentTokenFactory.sol";
import {ExperimentDeployerBase} from "./utils/ExperimentDeployerBase.sol";

/**
 * @notice Deploys a new ExperimentToken via an existing factory.
 *
 * Parameters passed as script arguments (in order):
 *  - factoryAddress: Address of the ExperimentTokenFactory
 *  - name: Token name
 *  - symbol: Token symbol
 *  - merkleRoot: Allowlist merkle root
 *  - baseClaimAmount: Base claim amount per address
 *  - bonusPerClaim: Bonus amount per claim
 *  - initialSupply: Initial token supply (use 0 for none)
 *  - owner: Token owner address (use address(0) for deployer)
 *
 * Usage:
 *  forge script script/DeployToken.s.sol:DeployToken \
 *      --rpc-url $BASE_SEPOLIA_RPC \
 *      --broadcast \
 *      --private-key $TESTNET_DEPLOYER_PRIVATE_KEY \
 *      -s "run(address,string,string,bytes32,uint256,uint256,uint256,address)" \
 *      "0xYourFactoryAddress" \
 *      "MyToken" \
 *      "MTK" \
 *      "0x1234567890123456789012345678901234567890123456789012345678901234" \
 *      "1000000000000000000" \
 *      "100000000000000000" \
 *      "0" \
 *      "0x0000000000000000000000000000000000000000"
 */
contract DeployFactoryToken is ExperimentDeployerBase {
    function run(
        address factoryAddress,
        string memory name,
        string memory symbol,
        bytes32 merkleRoot,
        uint256 baseClaimAmount,
        uint256 bonusPerClaim,
        uint256 initialSupply,
        address owner
    ) external {
        require(factoryAddress != address(0), "Factory address required");
        require(bytes(name).length > 0, "Token name required");
        require(bytes(symbol).length > 0, "Token symbol required");

        (uint256 deployerPrivateKey, address deployerAddress) = _loadDeployer();

        // Use deployer as owner if address(0) is passed
        if (owner == address(0)) {
            owner = deployerAddress;
        }

        console.log("=== Deploy ExperimentToken ===");
        console.log("Factory:", factoryAddress);
        console.log("Deployer:", deployerAddress);
        console.log("Owner:", owner);
        console.log("Name:", name);
        console.log("Symbol:", symbol);
        console.log("Initial Supply:", initialSupply);
        console.log("Base Claim Amount:", baseClaimAmount);
        console.log("Bonus Per Claim:", bonusPerClaim);
        console.log("Allowlist root:");
        console.logBytes32(merkleRoot);

        vm.startBroadcast(deployerPrivateKey);
        address tokenAddress = ExperimentTokenFactory(factoryAddress).deployToken(
            name,
            symbol,
            initialSupply,
            owner,
            merkleRoot,
            baseClaimAmount,
            bonusPerClaim
        );
        vm.stopBroadcast();

        console.log("ExperimentToken deployed at:", tokenAddress);
    }
}
