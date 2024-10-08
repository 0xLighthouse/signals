// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/proxy/Clones.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import './Signals.sol';

/// @title SignalsFactory
/// @notice Factory contract to create instances of the Signals contract
contract SignalsFactory is Ownable {
  using Clones for address;
  using SafeERC20 for IERC20;

  error FactoryDeploymentFailed();
  error InvalidOwnerAddress();

  /// @notice Event emitted when a new Signals contract is created
  event SignalsCreated(address indexed newSignals, address indexed owner);

  /// @notice The implementation contract for Signals
  Signals public immutable signalsImplementation;

  /// @notice Constructor to initialize the factory
  constructor() {
    signalsImplementation = new Signals();
  }

  /// @notice Creates a new Signals contract
  ///
  ///   @param owner_ Address of the owner of the new Signals contract
  ///   @param underlyingToken Address of the underlying token
  ///   @param threshold Minimum tokens required to propose an initiative
  ///   @param lockDurationCap Maximum lock duration allowed
  ///   @param proposalCap Maximum number of proposals allowed
  ///   @param decayCurveType Type of decay curve to be used
  ///
  /// @return Address of the newly created Signals contract
  /// --------------------------------------------------------
  function create(
    address owner_,
    address underlyingToken,
    uint256 threshold,
    uint256 lockDurationCap,
    uint256 proposalCap,
    uint256 decayCurveType
  ) external onlyOwner returns (address) {
    if (owner_ == address(0)) revert InvalidOwnerAddress();

    // Create a new clone of the Signals contract
    address newSignals = address(signalsImplementation).clone();

    // Initialize the new Signals contract
    Signals(newSignals).initialize(
      owner_,
      underlyingToken,
      threshold,
      lockDurationCap,
      proposalCap,
      decayCurveType
    );

    // Emit an event for the creation of the new contract
    emit SignalsCreated(newSignals, owner_);

    return newSignals;
  }
}
