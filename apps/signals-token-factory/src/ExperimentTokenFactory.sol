// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ExperimentToken} from "./ExperimentToken.sol";

/**
 * @title ExperimentTokenFactory
 * @notice Deploys ExperimentToken contracts configured with allowlisted Edge City participants.
 */
contract ExperimentTokenFactory {
    event TokenDeployed(
        address indexed owner,
        address indexed token,
        string name,
        string symbol,
        uint256 initialSupply,
        address allowanceSigner
    );

    /**
     * @notice Deploy a new ExperimentToken with the provided configuration.
     * @param name The token name.
     * @param symbol The token symbol.
     * @param initialSupply Optional initial token supply (18 decimals) minted to the owner.
     * @param owner The owner who receives the initial supply and manages allowlist parameters.
     * @param allowanceSigner Address authorized to issue claim allowances (defaults to owner when zero).
     */
    function deployToken(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address owner,
        address allowanceSigner
    ) external returns (address tokenAddress) {
        address resolvedOwner = owner == address(0) ? msg.sender : owner;

        ExperimentToken token = new ExperimentToken(
            name,
            symbol,
            resolvedOwner,
            initialSupply,
            allowanceSigner
        );

        emit TokenDeployed(
            resolvedOwner,
            address(token),
            name,
            symbol,
            initialSupply,
            allowanceSigner == address(0) ? resolvedOwner : allowanceSigner
        );

        return address(token);
    }
}
