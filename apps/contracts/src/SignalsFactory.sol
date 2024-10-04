// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'lib/openzeppelin-contracts/contracts/access/Ownable.sol';
import 'lib/openzeppelin-contracts/contracts/proxy/Clones.sol';

import './Signals.sol';

/// @title SignalsFactory
/// @notice Factory contract to create instances of the Signals contract
/// @dev Uses OpenZeppelin's Clones library to create minimal proxy contracts
contract SignalsFactory is Ownable {
  /// @notice Address of the Signals implementation contract
  address public implementation;
  /// @notice Address of the underlying token (ERC20 or ERC721)
  address public underlyingToken;
  /// @notice Flag indicating if the underlying token is ERC20
  bool public isERC20;
  /// @notice Event emitted when a new Signals contract is created
  /// @param newSignals Address of the newly created Signals contract
  /// @param owner Owner of the newly created Signals contract
  event SignalsCreated(address indexed newSignals, address indexed owner);

  /// @notice Custom error for invalid implementation address
  error InvalidImplementationAddress();
  /// @notice Custom error for invalid token address
  error InvalidTokenAddress();
  /// @notice Custom error for invalid owner address
  error InvalidOwnerAddress();
  /// @notice Custom error for clone creation failure
  error CloneCreationFailed();

  /// @notice Constructor to initialize the factory
  /// @param _implementation Address of the Signals implementation contract
  /// @param _underlyingToken Address of the underlying token (ERC20 or ERC721)
  /// @param _isERC20 Boolean indicating if the underlying token is ERC20
  constructor(address _implementation, address _underlyingToken, bool _isERC20) {
    if (_implementation == address(0)) revert InvalidImplementationAddress();
    if (_underlyingToken == address(0)) revert InvalidTokenAddress();
    implementation = _implementation;
    underlyingToken = _underlyingToken;
    isERC20 = _isERC20;
  }

  /// @notice Creates a new Signals contract
  /// @param owner_ Address of the owner of the new Signals contract
  /// @param threshold Minimum tokens required to propose an initiative
  /// @param lockDurationCap Maximum lock duration allowed
  /// @param proposalCap Maximum number of proposals allowed
  /// @param decayCurveType Type of decay curve to be used
  /// @return Address of the newly created Signals contract
  function createSignals(
    address owner_,
    uint256 threshold,
    uint256 lockDurationCap,
    uint256 proposalCap,
    uint256 decayCurveType
  ) external onlyOwner returns (address) {
    if (owner_ == address(0)) revert InvalidOwnerAddress();

    address clone = Clones.clone(implementation);
    if (clone == address(0)) revert CloneCreationFailed();
    Signals(clone).initialize(
      owner_,
      threshold,
      lockDurationCap,
      proposalCap,
      decayCurveType,
      underlyingToken,
      isERC20
    );
    Ownable(clone).transferOwnership(owner_);

    emit SignalsCreated(clone, owner_);

    return clone;
  }

  /// @notice Sets a new implementation address
  /// @param newImplementation Address of the new implementation contract
  function setImplementation(address newImplementation) external onlyOwner {
    if (newImplementation == address(0)) revert InvalidImplementationAddress();
    implementation = newImplementation;
  }
}
