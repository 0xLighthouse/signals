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
