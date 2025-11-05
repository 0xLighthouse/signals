// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";

/**
 * Base contract for deployment scripts with shared utilities
 */
abstract contract SharedScriptBase is Script {
    string[] public supportedNetworks = ["base-sepolia", "anvil"];

    function isSupportedNetwork(string memory network) internal view returns (bool) {
        for (uint256 i = 0; i < supportedNetworks.length; i++) {
            if (keccak256(abi.encodePacked(supportedNetworks[i])) == keccak256(abi.encodePacked(network))) {
                return true;
            }
        }
        return false;
    }

    function _loadPrivateKey(string memory network, string memory role)
        internal
        view
        returns (uint256 privateKey, address deployer)
    {
        string memory roleUpper = _toUpperWithUnderscore(role);
        string memory networkUpper = _toUpperWithUnderscore(network);
        string memory envVarName = string.concat(networkUpper, "_", roleUpper, "_PRIVATE_KEY");
        if (!vm.envExists(envVarName)) {
            revert(string.concat("Private key for ", role, " on ", network, " not found in environment variables"));
        }
        privateKey = vm.envUint(envVarName);
        deployer = vm.addr(privateKey);
    }

    function _toUpperWithUnderscore(string memory str) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(strBytes.length);
        for (uint256 i = 0; i < strBytes.length; i++) {
            bytes1 char = strBytes[i];
            if (char == 0x2d) {
                result[i] = 0x5f; // '-' -> '_'
            } else if (char == 0x2e) {
                result[i] = 0x5f; // '.' -> '_'
            } else if (char >= 0x61 && char <= 0x7a) {
                result[i] = bytes1(uint8(char) - 32); // lowercase -> uppercase
            } else {
                result[i] = char;
            }
        }
        return string(result);
    }

    /**
     * @notice Resolves a semantic name (e.g., ENS name) to an Ethereum address
     * @param network The network to resolve the address for
     * @param semanticName The semantic name to resolve (e.g., "1a35e1.eth")
     * @return resolvedAddress The resolved Ethereum address
     * @dev Reads from environment variable: {NETWORK}_ADDRESS_{SEMANTIC_NAME} where semantic name is uppercased with dots converted to underscores
     *      Example: network="base-sepolia", semanticName="1a35e1.eth" -> "BASE_SEPOLIA_ADDRESS_1A35E1_ETH"
     */
    function _resolveAddress(string memory network, string memory semanticName) internal view returns (address resolvedAddress) {
        string memory nameUpper = _toUpperWithUnderscore(semanticName);
        string memory networkUpper = _toUpperWithUnderscore(network);
        string memory envVarName = string.concat(networkUpper, "_ADDRESS_", nameUpper);
        if (!vm.envExists(envVarName)) {
            revert(string.concat("Address for ", semanticName, " on ", network, " not found in environment variables"));
        }
        resolvedAddress = vm.envAddress(envVarName);
    }

    function _optionalEnvAddress(string memory key, address fallbackValue) internal view returns (address value) {
        try vm.envAddress(key) returns (address candidate) {
            return candidate;
        } catch {
            return fallbackValue;
        }
    }

    function _optionalEnvUint(string memory key, uint256 fallbackValue) internal view returns (uint256 value) {
        try vm.envUint(key) returns (uint256 candidate) {
            return candidate;
        } catch {
            return fallbackValue;
        }
    }
}
