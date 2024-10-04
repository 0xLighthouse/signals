// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'lib/openzeppelin-contracts/contracts/access/Ownable.sol';
import 'lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import 'lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol';

/// @title Signals
/// @notice Contract for proposing and tracking initiatives with token locking
/// @dev Implements governance features for initiatives
contract Signals is Ownable {
  /// @notice Custom errors
  error EmptyTitle();
  error EmptyBody();
  error InsufficientTokens();

  /// @notice Threshold required to accept a proposal
  uint256 public acceptanceThreshold;

  uint256 public lockDurationCap;
  uint256 public proposalCap;
  uint256 public decayCurveType;
  address public underlyingToken;

  struct Initiative {
    string title;
    string body;
    address proposer;
    uint256 timestamp;
    uint256 initialWeight;
    uint256 lockDuration;
  }

  Initiative[] public initiatives;
  mapping(uint256 => uint256) public initiativeWeights;

  /// @notice Event emitted when a new initiative is proposed
  /// @param initiativeId ID of the proposed initiative
  /// @param proposer Address of the proposer
  /// @param title Title of the initiative
  /// @param body Body of the initiative
  event InitiativeProposed(
    uint256 indexed initiativeId,
    address indexed proposer,
    string title,
    string body
  );

  /// @notice Event emitted when a new initiative is proposed with locked tokens
  /// @param initiativeId ID of the proposed initiative
  /// @param proposer Address of the proposer
  /// @param title Title of the initiative
  /// @param body Body of the initiative
  /// @param amount Amount of tokens locked
  /// @param duration Duration for which tokens are locked
  event InitiativeProposedWithLock(
    uint256 indexed initiativeId,
    address indexed proposer,
    string title,
    string body,
    uint256 amount,
    uint256 duration
  );

  /// @notice Initializes the Signals contract
  /// @param owner_ Address of the owner of the contract
  /// @param _underlyingToken Address of the underlying token (ERC20) TODO: ERC721
  /// @param _threshold Minimum tokens required to propose an initiative
  /// @param _lockDurationCap Maximum lock duration allowed
  /// @param _proposalCap Maximum number of proposals allowed
  /// @param _decayCurveType Type of decay curve to be used
  function initialize(
    address owner_,
    address _underlyingToken,
    uint256 _threshold,
    uint256 _lockDurationCap,
    uint256 _proposalCap,
    uint256 _decayCurveType
  ) external isNotInitialized {
    underlyingToken = _underlyingToken;
    acceptanceThreshold = _threshold;
    lockDurationCap = _lockDurationCap;
    proposalCap = _proposalCap;
    decayCurveType = _decayCurveType;
    transferOwnership(owner_);
  }

  modifier isNotInitialized() {
    require(acceptanceThreshold == 0, 'Already initialized');
    _;
  }

  /// @notice Proposes a new initiative
  /// @param title Title of the initiative
  /// @param body Body of the initiative
  function proposeInitiative(string memory title, string memory body) external {
    if (bytes(title).length == 0) revert EmptyTitle();
    if (bytes(body).length == 0) revert EmptyBody();
    if (balanceOf(msg.sender) < acceptanceThreshold) revert InsufficientTokens();

    Initiative memory newInitiative = Initiative({
      title: title,
      body: body,
      proposer: msg.sender,
      timestamp: block.timestamp,
      initialWeight: 0,
      lockDuration: 0
    });

    initiatives.push(newInitiative);

    uint256 initiativeId = initiatives.length - 1;
    emit InitiativeProposed(initiativeId, msg.sender, title, body);
  }

  /// @notice Proposes a new initiative with locked tokens
  /// @param title Title of the initiative
  /// @param body Body of the initiative
  /// @param amount Amount of tokens to lock
  /// @param duration Duration for which tokens are locked (in months)
  function proposeInitiativeWithLock(
    string memory title,
    string memory body,
    uint256 amount,
    uint256 duration
  ) external {
    require(bytes(title).length > 0, 'Title cannot be empty');
    require(bytes(body).length > 0, 'Body cannot be empty');
    require(duration > 0, 'Duration must be greater than zero');
    require(duration <= lockDurationCap, 'Duration exceeds lock duration cap');
    require(balanceOf(msg.sender) >= amount, 'Insufficient tokens to lock');

    require(
      IERC20(underlyingToken).transferFrom(msg.sender, address(this), amount),
      'Token transfer failed'
    );

    uint256 weight = _calculateLockWeight(amount, duration);
    Initiative memory newInitiative = Initiative({
      title: title,
      body: body,
      proposer: msg.sender,
      timestamp: block.timestamp,
      initialWeight: weight,
      lockDuration: duration
    });

    initiatives.push(newInitiative);

    uint256 initiativeId = initiatives.length - 1;
    initiativeWeights[initiativeId] = weight;
    emit InitiativeProposedWithLock(initiativeId, msg.sender, title, body, amount, duration);
  }

  /// @notice Returns the token balance of an account
  /// @param account Address of the account
  /// @return Balance of the account
  function balanceOf(address account) public view returns (uint256) {
    return IERC20(underlyingToken).balanceOf(account);
  }

  /// @notice Returns the current weight of an initiative
  /// @param initiativeId ID of the initiative
  /// @return Current weight of the initiative
  function getInitiativeWeight(uint256 initiativeId) external view returns (uint256) {
    require(initiativeId < initiatives.length, 'Invalid initiative ID');
    return _calculateCurrentWeight(initiativeId);
  }

  /// @notice Returns the total weight of an initiative at the time of proposal
  /// @param initiativeId ID of the initiative
  /// @return Total weight of the initiative
  function getTotalWeight(uint256 initiativeId) external view returns (uint256) {
    require(initiativeId < initiatives.length, 'Invalid initiative ID');
    return initiativeWeights[initiativeId];
  }

  /// @notice Calculates the lock weight based on amount and duration
  /// @param amount Amount of tokens locked
  /// @param duration Duration for which tokens are locked
  /// @return Calculated weight
  function _calculateLockWeight(uint256 amount, uint256 duration) private pure returns (uint256) {
    return amount * duration;
  }

  /// @notice Calculates the current weight of an initiative based on elapsed time
  /// @param initiativeId ID of the initiative
  /// @return Current weight of the initiative
  function _calculateCurrentWeight(uint256 initiativeId) private view returns (uint256) {
    Initiative storage initiative = initiatives[initiativeId];
    uint256 elapsedTime = (block.timestamp - initiative.timestamp) / 30 days; // Assuming 1 month = 30 days
    if (elapsedTime >= initiative.lockDuration) {
      return 0;
    }
    uint256 remainingWeight = (initiative.initialWeight * (initiative.lockDuration - elapsedTime)) /
      initiative.lockDuration;
    return remainingWeight;
  }
}
