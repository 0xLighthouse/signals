// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/console.sol';
import 'lib/openzeppelin-contracts/contracts/access/Ownable.sol';
import './Signals.sol';

/// @title SignalsFactory
/// @notice Factory contract to create instances of the Signals contract
contract SignalsFactory is Ownable {
  error FactoryDeploymentFailed();
  error InvalidOwnerAddress();

  /// @notice Event emitted when a new Signals contract is created
  event SignalsCreated(address indexed newSignals, address indexed owner);

  /// @notice Constructor to initialize the factory
  constructor() {}

  /// @notice Creates a new Signals contract
  ///
  /// @param owner_ Address of the owner of the new Signals contract
  /// @param underlyingToken Address of the underlying token
  /// @param threshold Minimum tokens required to propose an initiative
  /// @param lockDurationCap Maximum lock duration allowed
  /// @param proposalCap Maximum number of proposals allowed
  /// @param decayCurveType Type of decay curve to be used
  /// @return Address of the newly created Signals contract
  function create(
    address owner_,
    address underlyingToken,
    uint256 threshold,
    uint256 lockDurationCap,
    uint256 proposalCap,
    uint256 decayCurveType
  ) external onlyOwner returns (address) {
    if (owner_ == address(0)) revert InvalidOwnerAddress();

    // Create a new instance of the Signals contract
    Signals newSignals = new Signals();

    // TODO: Guard against underlying tokens that are not ERC20
    // TODO: Guard against underlying tokens that are currently incompatable ie. Not 1e18

    // Initialize the new Signals contract
    newSignals.initialize(
      owner_,
      underlyingToken,
      threshold,
      lockDurationCap,
      proposalCap,
      decayCurveType
    );

    // revert if a new Signals contract is not created
    if (address(newSignals) == address(0)) revert FactoryDeploymentFailed();

    // Emit an event for the creation of the new contract
    emit SignalsCreated(address(newSignals), owner_);

    return address(newSignals);
  }
}
