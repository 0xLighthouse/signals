// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ExperimentTokenFactory, ExperimentToken} from "../src/ExperimentTokenFactory.sol";

contract DeployTokenFactoryScript is Script {

    function run() public {
        vm.startBroadcast();

        ExperimentTokenFactory factory = new ExperimentTokenFactory();
        // Example deployment of an experiment token owned by the broadcaster.
        // Replace the Merkle root with a real allowlist root before broadcasting.
        ExperimentToken token = ExperimentToken(
            factory.deployToken({
                name: "Experiment Token",
                symbol: "EXP",
                initialSupply: 0,
                owner: address(0),
                merkleRoot: bytes32(0),
                baseClaimAmount: 1_000 ether,
                bonusPerClaim: 100 ether
            })
        );

        vm.stopBroadcast();

        console2.log("Factory deployed at", address(factory));
        console2.log("Token deployed at", address(token));
    }
}
