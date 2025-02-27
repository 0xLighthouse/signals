// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "forge-std/console.sol";

// TODO: Use OpenZeppelin Clones library to create a new clone of the Signals contract
// import '@openzeppelin/contracts/proxy/Clones.sol';
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./Signals.sol";

/// @title SignalsFactory
/// @notice Factory contract to create instances of the Signals contract
contract SignalsFactory {
    using SafeERC20 for IERC20;

    error FactoryDeploymentFailed();
    error InvalidOwnerAddress();

    /// @notice Event emitted when a new Signals contract is created
    event SignalsCreated(address indexed newSignals, address indexed owner);

    /// @notice Creates a new Signals contract
    ///
    /// @return Address of the newly created Signals contract
    /// --------------------------------------------------------
    function create(Signals.SignalsConfig calldata config) public payable returns (address) {
        if (config.owner == address(0)) revert InvalidOwnerAddress();

        // TODO: Also init the Incentives contract from the factory
        // TODO: Perform additional config checks here; So the board does not get bricked;

        // Initialize the new Signals contract
        Signals instance = new Signals();
        instance.initialize(config);

        // Emit an event for the creation of the new contract
        emit SignalsCreated(address(instance), config.owner);

        return address(instance);
    }
}
