// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ExperimentToken} from "./ExperimentToken.sol";

error NotOwner();

event TokenDeployed(address indexed token, string name, string symbol);

/**
 * @title ExperimentTokenFactory
 * @notice Deploys ExperimentToken contracts configured with allowlisted Edge City participants.
 */
contract ExperimentTokenFactory {
    address public owner;
    address public allowanceSigner;

    constructor(address initialAllowanceSigner) {
        owner = msg.sender;
        allowanceSigner = initialAllowanceSigner;
    }

    /**
     * @notice Deploy a new ExperimentToken with the provided configuration.
     * @param name The token name.
     * @param symbol The token symbol.
     */
    function deployToken(string memory name, string memory symbol) external returns (address tokenAddress) {
        if (msg.sender != owner) revert NotOwner();
        ExperimentToken token = new ExperimentToken(name, symbol, owner, allowanceSigner);

        emit TokenDeployed(address(token), name, symbol);

        return address(token);
    }
}
