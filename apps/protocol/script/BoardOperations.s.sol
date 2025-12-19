// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/console.sol";
import {SharedScriptBase} from "@shared/SharedScriptBase.sol";
import {Signals} from "../src/Signals.sol";

/**
 * Board operations utility script
 *
 * Usage:
 * Open Board:
 *   forge script script/BoardOperations.s.sol --sig "openBoard(string,address)" base-sepolia <boardAddress> --broadcast
 */
contract BoardOperationsScript is SharedScriptBase {
    /**
     * Opens a board by setting its opensAt timestamp to the current block timestamp
     * This is a utility function that can be called standalone or from other functions
     * @param network The network to interact with
     * @param boardAddress The board contract address to open
     */
    function openBoard(string memory network, address boardAddress) public {
        if (!isSupportedNetwork(network)) {
            revert(string.concat("Unsupported network [", network, "] provided"));
        }

        (uint256 deployerPrivateKey, address deployerAddress) = _loadPrivateKey(network, "deployer");
        Signals board = Signals(boardAddress);

        vm.startBroadcast(deployerPrivateKey);
        board.setOpensAt(block.timestamp);
        vm.stopBroadcast();

        console.log("=== Board Opened ===");
        console.log("Board Address:", boardAddress);
        console.log("Opened By:", deployerAddress);
        console.log("Opens At:", block.timestamp);

        console.log("ScriptOutput:", boardAddress);
    }
}
