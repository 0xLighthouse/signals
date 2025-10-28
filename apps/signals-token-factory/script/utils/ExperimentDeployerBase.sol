// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";

abstract contract ExperimentDeployerBase is Script {

    string[] public supportedNetworks = ["base-sepolia", "anvil"];

    function isSupportedNetwork(string memory network) internal returns (bool) {
        for (uint256 i = 0; i < supportedNetworks.length; i++) {
            if (keccak256(abi.encodePacked(supportedNetworks[i])) == keccak256(abi.encodePacked(network))) {
                return true;
            }
        }
        return false;
    }

    function _loadDeployer() internal returns (uint256 privateKey, address deployer) {
        privateKey = vm.envUint("TESTNET_DEPLOYER_PRIVATE_KEY");
        deployer = vm.addr(privateKey);
    }

    function _optionalEnvAddress(string memory key, address fallbackValue) internal returns (address value) {
        try vm.envAddress(key) returns (address candidate) {
            return candidate;
        } catch {
            return fallbackValue;
        }
    }

    function _optionalEnvUint(string memory key, uint256 fallbackValue) internal returns (uint256 value) {
        try vm.envUint(key) returns (uint256 candidate) {
            return candidate;
        } catch {
            return fallbackValue;
        }
    }
}
