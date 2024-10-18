// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import 'forge-std/console.sol';

// TODO: Use OpenZeppelin Clones library to create a new clone of the Signals contract
// import '@openzeppelin/contracts/proxy/Clones.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import './Signals.sol';

/// @title SignalsFactory
/// @notice Factory contract to create instances of the Signals contract
contract SignalsFactory  {
  using SafeERC20 for IERC20;

  error FactoryDeploymentFailed();
  error InvalidOwnerAddress();

  /// @notice Event emitted when a new Signals contract is created
  event SignalsCreated(address indexed newSignals, address indexed owner);

  
  /// @notice Creates a new Signals contract
  ///
  ///   @param _owner Address of the owner of the new Signals contract
  ///   @param _underlyingToken Address of the underlying token
  ///   @param _proposalThreshold Minimum tokens required to propose an initiative
  ///   @param _acceptanceThreshold Minimum tokens required to accept an initiative
  ///   @param lockDurationCap Maximum lock duration allowed
  ///   @param proposalCap Maximum number of proposals allowed
  ///   @param decayCurveType Type of decay curve to be used
  ///
  /// @return Address of the newly created Signals contract
  /// --------------------------------------------------------
  function create(
    address _owner,
    address _underlyingToken,
    uint256 _proposalThreshold,
    uint256 _acceptanceThreshold,
    uint256 lockDurationCap,
    uint256 proposalCap,
    uint256 decayInterval,
    uint256 decayCurveType
  ) public payable returns  (address) {
    if (_owner == address(0)) revert InvalidOwnerAddress();

    // Initialize the new Signals contract
    Signals instance = new Signals();
    instance.initialize(
      _owner,
      _underlyingToken,
      _proposalThreshold,
      _acceptanceThreshold,
      lockDurationCap,
      proposalCap,
      decayInterval,
      decayCurveType
    );

    // Emit an event for the creation of the new contract
    emit SignalsCreated(address(instance), _owner);

    return address(instance);
  }
}
