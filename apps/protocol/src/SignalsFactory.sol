// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

// TODO(@arnold): [LOW] Use OpenZeppelin Clones library for minimal proxy pattern
//                Consider using EIP-1167 minimal proxy clones for gas-efficient deployment
//                Benchmark gas savings vs current approach before implementing
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/ISignals.sol";
import "./interfaces/ISignalsFactory.sol";

import "./Signals.sol";
/// @title SignalsFactory
/// @notice Factory contract to create instances of the Signals contract

contract SignalsFactory is ISignalsFactory {
    using SafeERC20 for IERC20;
    using Clones for address;

    string public constant VERSION = "0.1.0";

    address public immutable implementation;

    constructor(address _implementation) {
        implementation = _implementation;
    }

    /// @notice Thrown when deployment of Signals instance fails
    error SignalsFactory_DeploymentFailed();

    /// @notice Thrown when owner address is zero
    error SignalsFactory_ZeroAddressOwner();

    /// @notice Event emitted when a new Signals contract is created
    event BoardCreated(address indexed board, address indexed owner);

    function version() external pure returns (string memory) {
        return "0.1.0";
    }

    /// @notice Creates a new Signals contract
    ///
    /// @return Address of the newly created Signals contract
    /// --------------------------------------------------------
    function create(ISignals.BoardConfig calldata config) public payable returns (address) {
        if (config.owner == address(0)) revert SignalsFactory_ZeroAddressOwner();

        // TODO(@arnold): [MEDIUM] Initialize IncentivesPool contract from factory
        //                Factory should handle IncentivesPool deployment and initialization
        //                to ensure consistent setup and reduce deployment complexity
        // TODO(@arnold): [HIGH] Add comprehensive config validation to prevent bricked boards
        //                Validate: threshold > 0, intervals > 0, valid decay curve params
        //                This prevents deploying boards with invalid configurations

        // Initialize the new Signals contract
        address instance = implementation.clone();
        Signals(instance).initialize(config);

        // Emit an event for the creation of the new contract
        emit BoardCreated(instance, config.owner);

        return instance;
    }
}
