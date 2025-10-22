// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {PausableTokenFactory, PausableToken} from "../src/PausableTokenFactory.sol";

contract DeployTokenFactoryScript is Script {
    function run() public {
        vm.startBroadcast();

        PausableTokenFactory factory = new PausableTokenFactory();
        // Example deployment of a pausable token owned by the broadcaster.
        PausableToken token = PausableToken(
            factory.deployToken({
                name: "Signal Token",
                symbol: "SIG",
                initialSupply: 1_000_000 ether,
                owner: address(0)
            })
        );

        vm.stopBroadcast();

        console2.log("Factory deployed at", address(factory));
        console2.log("Token deployed at", address(token));
    }
}
