// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'lib/openzeppelin-contracts/contracts/access/Ownable.sol';
import 'lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';

/// @title Signals
contract Signals is Ownable {
  /// @notice Enum representing the status of an initiative
  enum InitiativeState {
    Proposed,
    Accepted,
    Cancelled,
    Expired
  }

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
    InitiativeState state;
    address proposer;
    uint256 timestamp;
  }

  /// @notice Struct to store lock information for each supporter
  struct LockInfo {
    uint256 amount;
    uint256 duration; // in months
    uint256 timestamp; // when the lock started
  }

  /// @notice Mapping from initiative ID to Initiative
  mapping(uint256 => Initiative) public initiatives;

  /// @notice Mapping from initiative ID to total initial weight
  mapping(uint256 => uint256) public initiativeTotalInitialWeight;

  /// @notice Mapping from initiative ID to mapping of supporter address to their LockInfo
  mapping(uint256 => mapping(address => LockInfo)) public initiativeLocks;

  /// @notice Mapping from initiative ID to array of supporter addresses
  mapping(uint256 => address[]) public initiativeSupporters;

  /// @notice Mapping to check if an address is already a supporter of an initiative
  mapping(uint256 => mapping(address => bool)) public isSupporter;

  /// @notice Counter for initiative IDs
  uint256 public initiativeCount;

  event WeightUpdated(
    uint256 indexed initiativeId,
    address indexed supporter,
    uint256 amount,
    uint256 duration,
    uint256 timestamp
  );

  /// @notice Event emitted when a new initiative is proposed
  event InitiativeProposed(
    uint256 indexed initiativeId,
    address indexed proposer,
    string title,
    string body
  );

  /// @notice Initializes the Signals contract
  /// @param owner_ Address of the owner of the contract
  /// @param _underlyingToken Address of the underlying token (ERC20)
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
      state: InitiativeState.Proposed,
      title: title,
      body: body,
      proposer: msg.sender,
      timestamp: block.timestamp
    });

    uint256 initiativeId = initiativeCount;
    initiatives[initiativeId] = newInitiative;
    initiativeCount++;

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
    if (bytes(title).length == 0) revert EmptyTitle();
    if (bytes(body).length == 0) revert EmptyBody();
    require(duration > 0, 'Duration must be greater than zero');
    require(duration <= lockDurationCap, 'Duration exceeds lock duration cap');
    require(balanceOf(msg.sender) >= amount, 'Insufficient tokens to lock');

    require(
      IERC20(underlyingToken).transferFrom(msg.sender, address(this), amount),
      'Token transfer failed'
    );

    uint256 weight = _calculateLockWeight(amount, duration);

    Initiative memory newInitiative = Initiative({
      state: InitiativeState.Proposed,
      title: title,
      body: body,
      proposer: msg.sender,
      timestamp: block.timestamp
    });

    uint256 initiativeId = initiativeCount;
    initiatives[initiativeId] = newInitiative;
    initiativeCount++;

    // Store the lock info for the proposer
    initiativeLocks[initiativeId][msg.sender] = LockInfo({
      amount: amount,
      duration: duration,
      timestamp: block.timestamp
    });

    // Update total initial weight
    initiativeTotalInitialWeight[initiativeId] = weight;

    // Add proposer to the supporters list if not already added
    if (!isSupporter[initiativeId][msg.sender]) {
      initiativeSupporters[initiativeId].push(msg.sender);
      isSupporter[initiativeId][msg.sender] = true;
    }

    emit InitiativeProposed(initiativeId, msg.sender, title, body);
    emit WeightUpdated(initiativeId, msg.sender, amount, duration, block.timestamp);
  }

  /// @notice Allows a user to support an existing initiative with locked tokens
  /// @param initiativeId ID of the initiative to support
  /// @param amount Amount of tokens to lock
  /// @param duration Duration for which tokens are locked (in months)
  function supportInitiative(uint256 initiativeId, uint256 amount, uint256 duration) external {
    require(duration > 0, 'Duration must be greater than zero');
    require(duration <= lockDurationCap, 'Duration exceeds lock duration cap');
    require(initiativeId < initiativeCount, 'Invalid initiative ID');
    require(balanceOf(msg.sender) >= amount, 'Insufficient tokens to lock');
    Initiative storage initiative = initiatives[initiativeId];
    require(initiative.state == InitiativeState.Proposed, 'Initiative is not in Proposed state');

    require(
      IERC20(underlyingToken).transferFrom(msg.sender, address(this), amount),
      'Token transfer failed'
    );

    uint256 weight = _calculateLockWeight(amount, duration);

    // Store the lock info for the supporter
    initiativeLocks[initiativeId][msg.sender] = LockInfo({
      amount: amount,
      duration: duration,
      timestamp: block.timestamp
    });

    // Update total initial weight
    initiativeTotalInitialWeight[initiativeId] += weight;

    // Add supporter to the supporters list if not already added
    if (!isSupporter[initiativeId][msg.sender]) {
      initiativeSupporters[initiativeId].push(msg.sender);
      isSupporter[initiativeId][msg.sender] = true;
    }

    emit WeightUpdated(initiativeId, msg.sender, amount, duration, block.timestamp);
  }

  /// @notice Get an initiative by its ID
  /// @param initiativeId The ID of the initiative
  /// @return The initiative struct
  function getInitiative(uint256 initiativeId) external view returns (Initiative memory) {
    require(initiativeId < initiativeCount, 'Invalid initiative ID');
    return initiatives[initiativeId];
  }

  /// @notice Returns the token balance of an account
  /// @param account Address of the account
  /// @return Balance of the account
  function balanceOf(address account) public view returns (uint256) {
    return IERC20(underlyingToken).balanceOf(account);
  }

  /// @notice Returns the current total weight of an initiative
  /// @param initiativeId ID of the initiative
  /// @return Current total weight of the initiative
  function getWeight(uint256 initiativeId) external view returns (uint256) {
    require(initiativeId < initiativeCount, 'Invalid initiative ID');
    uint256 totalCurrentWeight = 0;
    address[] storage supporters = initiativeSupporters[initiativeId];
    for (uint256 i = 0; i < supporters.length; i++) {
      address supporter = supporters[i];
      uint256 currentWeight = _calculateCurrentWeight(initiativeId, supporter);
      totalCurrentWeight += currentWeight;
    }
    return totalCurrentWeight;
  }

  /// @notice Returns the total initial weight of an initiative at the time of proposal
  /// @param initiativeId ID of the initiative
  /// @return Total initial weight of the initiative
  function getTotalWeight(uint256 initiativeId) external view returns (uint256) {
    require(initiativeId < initiativeCount, 'Invalid initiative ID');
    return initiativeTotalInitialWeight[initiativeId];
  }

  /// @notice Calculates the lock weight based on amount and duration
  /// @param amount Amount of tokens locked
  /// @param duration Duration for which tokens are locked
  /// @return Calculated weight
  function _calculateLockWeight(uint256 amount, uint256 duration) private pure returns (uint256) {
    return amount * duration;
  }

  /// @notice Calculates the current weight of a supporter's lock based on elapsed time
  /// @param initiativeId ID of the initiative
  /// @param supporter Address of the supporter
  /// @return Current weight of the supporter's lock
  function _calculateCurrentWeight(
    uint256 initiativeId,
    address supporter
  ) private view returns (uint256) {
    LockInfo storage lockInfo = initiativeLocks[initiativeId][supporter];
    uint256 elapsedTime = (block.timestamp - lockInfo.timestamp) / 30 days; // Assuming 1 month = 30 days
    if (elapsedTime >= lockInfo.duration) {
      return 0;
    }
    uint256 remainingDuration = lockInfo.duration - elapsedTime;
    uint256 currentWeight = lockInfo.amount * remainingDuration;
    return currentWeight;
  }
}
