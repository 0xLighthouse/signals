// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {ISignals} from "./ISignals.sol";

/**
 * @title ISignalsFactory
 * @notice Interface for the Signals factory contract that deploys new Signals boards
 * @dev Factory handles board deployment and initialization with consistent versioning
 */
interface ISignalsFactory {
    /**
     * @notice Create a new Signals board with the given configuration
     * @dev Factory automatically adds version to the configuration
     * @param config Board configuration parameters
     * @return Address of the newly deployed Signals contract
     */
    function create(ISignals.BoardConfig calldata config) external payable returns (address);
}
