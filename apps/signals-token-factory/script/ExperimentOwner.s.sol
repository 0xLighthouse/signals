// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import "forge-std/console.sol";

import {ExperimentToken} from "../src/ExperimentTokenFactory.sol";

abstract contract ExperimentOwnerBase is Script {
    function _loadDeployer(string memory network) internal returns (uint256 privateKey, address deployer) {
        // Convert network name to env var format: "anvil" -> "ANVIL", "base-sepolia" -> "BASE_SEPOLIA"
        string memory networkUpper = _toUpperWithUnderscore(network);
        string memory envVarName = string.concat(networkUpper, "_DEPLOYER_PRIVATE_KEY");

        privateKey = vm.envUint(envVarName);
        deployer = vm.addr(privateKey);
    }

    function _toUpperWithUnderscore(string memory str) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(strBytes.length);

        for (uint256 i = 0; i < strBytes.length; i++) {
            bytes1 char = strBytes[i];
            // Convert hyphen to underscore
            if (char == 0x2d) { // '-'
                result[i] = 0x5f; // '_'
            }
            // Convert lowercase to uppercase (a-z -> A-Z)
            else if (char >= 0x61 && char <= 0x7a) {
                result[i] = bytes1(uint8(char) - 32);
            }
            else {
                result[i] = char;
            }
        }

        return string(result);
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
 * @notice Performs a batch mint using a JSON configuration file.
 *
 * The configuration file must include `mints` (array of `{ "to": address, "amount": uint256 }`) and an
 * optional `reason` field.
 *
 * Usage:
 *  forge script script/ExperimentOwner.s.sol:BatchMint \
 *      --rpc-url $BASE_SEPOLIA_RPC \
 *      --broadcast \
 *      -s "run(string,address,string)" \
 *      "base-sepolia" \
 *      "0xYourTokenAddress" \
 *      "./batch-mint.json"
 */
contract BatchMint is ExperimentOwnerBase {
    function run(string memory network, address tokenAddress, string memory configPath) external {
        (uint256 deployerPrivateKey, address deployerAddress) = _loadDeployer(network);
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
 * @notice Updates the allowance signer authorized to issue claim allowances.
 *
 * Usage:
 *  forge script script/ExperimentOwner.s.sol:SetAllowanceSigner \
 *      --rpc-url $BASE_SEPOLIA_RPC \
 *      --broadcast \
 *      -s "run(string,address,address)" \
 *      "base-sepolia" \
 *      "0xYourTokenAddress" \
 *      "0xNewAllowanceSigner"
 */
contract SetAllowanceSigner is ExperimentOwnerBase {
    function run(string memory network, address tokenAddress, address newSigner) external {
        (uint256 deployerPrivateKey, address deployerAddress) = _loadDeployer(network);
        ExperimentToken token = ExperimentToken(tokenAddress);

        console.log("=== Update Allowance Signer ===");
        console.log("Deployer:", deployerAddress);
        console.log("Token:", tokenAddress);
        console.log("Current signer:", token.allowanceSigner());
        console.log("New signer:", newSigner);

        vm.startBroadcast(deployerPrivateKey);
        token.setAllowanceSigner(newSigner);
        vm.stopBroadcast();

        console.log("Allowance signer updated");
    }
}

/**
 * @notice Pauses token transfers and claims.
 *
 * Usage:
 *  forge script script/ExperimentOwner.s.sol:PauseToken \
 *      --rpc-url $BASE_SEPOLIA_RPC \
 *      --broadcast \
 *      -s "run(string,address)" \
 *      "base-sepolia" \
 *      "0xYourTokenAddress"
 */
contract PauseToken is ExperimentOwnerBase {
    function run(string memory network, address tokenAddress) external {
        (uint256 deployerPrivateKey, address deployerAddress) = _loadDeployer(network);
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
 *      -s "run(string,address)" \
 *      "base-sepolia" \
 *      "0xYourTokenAddress"
 */
contract UnpauseToken is ExperimentOwnerBase {
    function run(string memory network, address tokenAddress) external {
        (uint256 deployerPrivateKey, address deployerAddress) = _loadDeployer(network);
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
