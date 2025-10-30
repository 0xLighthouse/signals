// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SharedScriptBase} from "@shared/SharedScriptBase.sol";
import "forge-std/console.sol";

import {ExperimentToken} from "../src/ExperimentTokenFactory.sol";

abstract contract ExperimentOwnerBase is SharedScriptBase {
    function _readBatchMintConfig(string memory path)
        internal
        view
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
        (uint256 deployerPrivateKey,) = _loadPrivateKey(network, "deployer");
        ExperimentToken token = ExperimentToken(tokenAddress);
        (ExperimentToken.BatchMintRequest[] memory mints, string memory reason) = _readBatchMintConfig(configPath);

        uint256 length = mints.length;
        uint256 totalAmount = 0;
        console.log("=== Batch Mint ===");
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
        (uint256 deployerPrivateKey,) = _loadPrivateKey(network, "deployer");
        ExperimentToken token = ExperimentToken(tokenAddress);

        console.log("=== Update Allowance Signer ===");
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
        (uint256 deployerPrivateKey,) = _loadPrivateKey(network, "deployer");
        ExperimentToken token = ExperimentToken(tokenAddress);

        console.log("=== Pause Token ===");
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
        (uint256 deployerPrivateKey,) = _loadPrivateKey(network, "deployer");
        ExperimentToken token = ExperimentToken(tokenAddress);

        console.log("=== Unpause Token ===");
        console.log("Token:", tokenAddress);

        vm.startBroadcast(deployerPrivateKey);
        token.unpause();
        vm.stopBroadcast();

        console.log("Token unpaused");
    }
}
