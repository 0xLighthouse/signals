// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import "forge-std/console.sol";

import {ExperimentToken} from "../src/ExperimentTokenFactory.sol";

abstract contract ExperimentOwnerBase is Script {
    function _loadDeployer() internal returns (uint256 privateKey, address deployer) {
        privateKey = vm.envUint("TESTNET_DEPLOYER_PRIVATE_KEY");
        deployer = vm.addr(privateKey);
    }

    function _readBatchMintConfig(string memory path)
        internal
        returns (ExperimentToken.BatchMintRequest[] memory mints, string memory reason)
    {
        string memory raw = vm.readFile(path);

        bytes memory mintsBytes = vm.parseJson(raw, ".mints");
        if (mintsBytes.length == 0) {
            revert("Batch mint config missing .mints entries");
        }
        mints = abi.decode(mintsBytes, (ExperimentToken.BatchMintRequest[]));

        bytes memory reasonBytes = vm.parseJson(raw, ".reason");
        if (reasonBytes.length > 0) {
            reason = abi.decode(reasonBytes, (string));
        }
        if (bytes(reason).length == 0) {
            reason = "Batch distribution via BatchMint script";
        }
    }
}

/**
 * @notice Updates the Merkle allowlist root for an ExperimentToken.
 *
 * Usage:
 *  forge script script/ExperimentOwner.s.sol:UpdateMerkleRoot \
 *      --rpc-url $BASE_SEPOLIA_RPC \
 *      --broadcast \
 *      --private-key $TESTNET_DEPLOYER_PRIVATE_KEY \
 *      -s "run(address,bytes32)" \
 *      "0xYourTokenAddress" \
 *      "0xYourNewRoot"
 */
contract UpdateMerkleRoot is ExperimentOwnerBase {
    function run(address tokenAddress, bytes32 newRoot) external {
        (uint256 deployerPrivateKey, address deployerAddress) = _loadDeployer();
        ExperimentToken token = ExperimentToken(tokenAddress);

        console.log("=== Update Merkle Root ===");
        console.log("Deployer:", deployerAddress);
        console.log("Token:", tokenAddress);
        console.log("Current root:");
        console.logBytes32(token.merkleRoot());
        console.log("New root:");
        console.logBytes32(newRoot);

        vm.startBroadcast(deployerPrivateKey);
        token.setMerkleRoot(newRoot);
        vm.stopBroadcast();

        console.log("Merkle root updated");
    }
}

/**
 * @notice Performs a batch mint using a JSON configuration file.
 *
 * The configuration file must include `mints` (array of `{ "to": address, "amount": uint256 }`) and an
 * optional `reason` field.
 *
 * Usage:
 *  forge script script/ExperimentOwner.s.sol:BatchMint \
 *      --rpc-url $BASE_SEPOLIA_RPC \
 *      --broadcast \
 *      --private-key $TESTNET_DEPLOYER_PRIVATE_KEY \
 *      -s "run(address,string)" \
 *      "0xYourTokenAddress" \
 *      "./batch-mint.json"
 */
contract BatchMint is ExperimentOwnerBase {
    function run(address tokenAddress, string memory configPath) external {
        (uint256 deployerPrivateKey, address deployerAddress) = _loadDeployer();
        ExperimentToken token = ExperimentToken(tokenAddress);
        (ExperimentToken.BatchMintRequest[] memory mints, string memory reason) = _readBatchMintConfig(configPath);

        uint256 length = mints.length;
        uint256 totalAmount = 0;
        console.log("=== Batch Mint ===");
        console.log("Deployer:", deployerAddress);
        console.log("Token:", tokenAddress);
        console.log("Entries:", length);
        console.log("Reason:", reason);

        for (uint256 i = 0; i < length; i++) {
            console.log("  -> Recipient:", mints[i].to);
            console.log("     Amount:", mints[i].amount);
            totalAmount += mints[i].amount;
        }
        console.log("Total mint amount:", totalAmount);

        vm.startBroadcast(deployerPrivateKey);
        token.batchMint(mints, reason);
        vm.stopBroadcast();

        console.log("Batch mint completed");
    }
}

/**
 * @notice Adjusts base and bonus claim parameters.
 *
 * Usage:
 *  forge script script/ExperimentOwner.s.sol:SetClaimParameters \
 *      --rpc-url $BASE_SEPOLIA_RPC \
 *      --broadcast \
 *      --private-key $TESTNET_DEPLOYER_PRIVATE_KEY \
 *      -s "run(address,uint256,uint256)" \
 *      "0xYourTokenAddress" \
 *      "1000000000000000000000" \
 *      "100000000000000000000"
 */
contract SetClaimParameters is ExperimentOwnerBase {
    function run(address tokenAddress, uint256 baseClaimAmount, uint256 bonusPerClaim) external {
        (uint256 deployerPrivateKey, address deployerAddress) = _loadDeployer();
        ExperimentToken token = ExperimentToken(tokenAddress);

        console.log("=== Update Claim Parameters ===");
        console.log("Deployer:", deployerAddress);
        console.log("Token:", tokenAddress);
        console.log("Base claim amount:", baseClaimAmount);
        console.log("Bonus per claim:", bonusPerClaim);

        vm.startBroadcast(deployerPrivateKey);
        token.setClaimParameters(baseClaimAmount, bonusPerClaim);
        vm.stopBroadcast();

        console.log("Claim parameters updated");
    }
}

/**
 * @notice Pauses token transfers and claims.
 *
 * Usage:
 *  forge script script/ExperimentOwner.s.sol:PauseToken \
 *      --rpc-url $BASE_SEPOLIA_RPC \
 *      --broadcast \
 *      --private-key $TESTNET_DEPLOYER_PRIVATE_KEY \
 *      -s "run(address)" \
 *      "0xYourTokenAddress"
 */
contract PauseToken is ExperimentOwnerBase {
    function run(address tokenAddress) external {
        (uint256 deployerPrivateKey, address deployerAddress) = _loadDeployer();
        ExperimentToken token = ExperimentToken(tokenAddress);

        console.log("=== Pause Token ===");
        console.log("Deployer:", deployerAddress);
        console.log("Token:", tokenAddress);

        vm.startBroadcast(deployerPrivateKey);
        token.pause();
        vm.stopBroadcast();

        console.log("Token paused");
    }
}

/**
 * @notice Resumes token transfers and claims.
 *
 * Usage:
 *  forge script script/ExperimentOwner.s.sol:UnpauseToken \
 *      --rpc-url $BASE_SEPOLIA_RPC \
 *      --broadcast \
 *      --private-key $TESTNET_DEPLOYER_PRIVATE_KEY \
 *      -s "run(address)" \
 *      "0xYourTokenAddress"
 */
contract UnpauseToken is ExperimentOwnerBase {
    function run(address tokenAddress) external {
        (uint256 deployerPrivateKey, address deployerAddress) = _loadDeployer();
        ExperimentToken token = ExperimentToken(tokenAddress);

        console.log("=== Unpause Token ===");
        console.log("Deployer:", deployerAddress);
        console.log("Token:", tokenAddress);

        vm.startBroadcast(deployerPrivateKey);
        token.unpause();
        vm.stopBroadcast();

        console.log("Token unpaused");
    }
}
