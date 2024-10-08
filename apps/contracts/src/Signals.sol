// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import 'lib/openzeppelin-contracts/contracts/access/Ownable.sol';
import 'lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import 'lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol';

/// @title Signals
contract Signals is Ownable, ReentrancyGuard {
  enum InitiativeState {
    Proposed,
    Accepted,
    Cancelled,
    Expired
  }

  /// @notice Custom errors
  error InvalidInput(string message);
  error InsufficientTokens();
  error InvalidInitiativeState(string message);
  error TokenTransferFailed();
  error NothingToWithdraw();
  error InitiativeNotFound();

  /// @notice Threshold required to accept a proposal
  uint256 public acceptanceThreshold;

  uint256 public lockDurationCap;
  uint256 public proposalCap;
  uint256 public decayCurveType;
  address public underlyingToken;

  /// @notice Inactivity threshold after which an initiative can be expired (in seconds)
  uint256 public activityTimeout = 60 days;

  struct Initiative {
    string title;
    string body;
    InitiativeState state;
    address proposer;
    uint256 timestamp;
    uint256 lastActivity; // Timestamp of the last activity on the initiative
  }

  /// @notice Struct to store lock information for each supporter
  struct LockInfo {
    uint256 totalAmount;
    uint256 weightedDuration; // Weighted average duration
    uint256 timestamp; // Last time the lock was updated
    bool withdrawn; // Indicates if tokens have been withdrawn
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

  /// @notice Mapping from supporter address to array of initiative IDs they have pending withdrawals from
  mapping(address => uint256[]) public pendingWithdrawals;

  /// @notice Mapping to keep track of initiative IDs indices in the pendingWithdrawals array
  mapping(address => mapping(uint256 => uint256)) private pendingWithdrawalIndex;

  /// @notice Counter for initiative IDs
  uint256 public initiativeCount;

  event WeightUpdated(
    uint256 indexed initiativeId,
    address indexed supporter,
    uint256 totalAmount,
    uint256 weightedDuration,
    uint256 timestamp
  );

  /// @notice Event emitted when a new initiative is proposed
  event InitiativeProposed(
    uint256 indexed initiativeId,
    address indexed proposer,
    string title,
    string body
  );

  /// @notice Event emitted when an initiative is accepted
  event InitiativeAccepted(uint256 indexed initiativeId);

  /// @notice Event emitted when an initiative is expired
  event InitiativeExpired(uint256 indexed initiativeId);

  /// @notice Event emitted when a supporter withdraws their tokens
  event TokensWithdrawn(uint256 indexed initiativeId, address indexed supporter, uint256 amount);

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

  /// @notice Allows the owner to update the inactivity threshold
  /// @param _newThreshold New inactivity threshold in seconds
  function setInactivityThreshold(uint256 _newThreshold) external onlyOwner {
    activityTimeout = _newThreshold;
  }

  /// @notice Proposes a new initiative
  /// @param title Title of the initiative
  /// @param body Body of the initiative
  function proposeInitiative(string memory title, string memory body) external {
    if (bytes(title).length == 0 || bytes(body).length == 0)
      revert InvalidInput('Title or body cannot be empty');
    if (balanceOf(msg.sender) < acceptanceThreshold) revert InsufficientTokens();

    Initiative memory newInitiative = Initiative({
      state: InitiativeState.Proposed,
      title: title,
      body: body,
      proposer: msg.sender,
      timestamp: block.timestamp,
      lastActivity: block.timestamp
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
    if (bytes(title).length == 0 || bytes(body).length == 0)
      revert InvalidInput('Title or body cannot be empty');
    if (duration == 0 || duration > lockDurationCap) revert InvalidInput('Invalid lock duration');
    if (balanceOf(msg.sender) < amount) revert InsufficientTokens();

    if (!IERC20(underlyingToken).transferFrom(msg.sender, address(this), amount))
      revert TokenTransferFailed();

    Initiative memory newInitiative = Initiative({
      state: InitiativeState.Proposed,
      title: title,
      body: body,
      proposer: msg.sender,
      timestamp: block.timestamp,
      lastActivity: block.timestamp
    });

    uint256 initiativeId = initiativeCount;
    initiatives[initiativeId] = newInitiative;
    initiativeCount++;

    _updateLockInfo(initiativeId, msg.sender, amount, duration);

    uint256 weight = _calculateLockWeight(amount, duration);
    initiativeTotalInitialWeight[initiativeId] += weight;

    if (!isSupporter[initiativeId][msg.sender]) {
      initiativeSupporters[initiativeId].push(msg.sender);
      isSupporter[initiativeId][msg.sender] = true;
    }

    _addPendingWithdrawal(msg.sender, initiativeId);

    emit InitiativeProposed(initiativeId, msg.sender, title, body);
    emit WeightUpdated(
      initiativeId,
      msg.sender,
      initiativeLocks[initiativeId][msg.sender].totalAmount,
      initiativeLocks[initiativeId][msg.sender].weightedDuration,
      block.timestamp
    );
  }

  /// @notice Allows a user to support an existing initiative with locked tokens
  /// @param initiativeId ID of the initiative to support
  /// @param amount Amount of tokens to lock
  /// @param duration Duration for which tokens are locked (in months)
  function supportInitiative(uint256 initiativeId, uint256 amount, uint256 duration) external {
    if (duration == 0 || duration > lockDurationCap) revert InvalidInput('Invalid lock duration');
    if (initiativeId >= initiativeCount) revert InitiativeNotFound();
    if (balanceOf(msg.sender) < amount) revert InsufficientTokens();
    Initiative storage initiative = initiatives[initiativeId];
    if (initiative.state != InitiativeState.Proposed)
      revert InvalidInitiativeState('Initiative is not in Proposed state');

    if (!IERC20(underlyingToken).transferFrom(msg.sender, address(this), amount))
      revert TokenTransferFailed();

    _updateLockInfo(initiativeId, msg.sender, amount, duration);

    uint256 weight = _calculateLockWeight(amount, duration);
    initiativeTotalInitialWeight[initiativeId] += weight;

    if (!isSupporter[initiativeId][msg.sender]) {
      initiativeSupporters[initiativeId].push(msg.sender);
      isSupporter[initiativeId][msg.sender] = true;
    }

    _addPendingWithdrawal(msg.sender, initiativeId);

    initiative.lastActivity = block.timestamp;

    emit WeightUpdated(
      initiativeId,
      msg.sender,
      initiativeLocks[initiativeId][msg.sender].totalAmount,
      initiativeLocks[initiativeId][msg.sender].weightedDuration,
      block.timestamp
    );
  }

  function _updateLockInfo(
    uint256 initiativeId,
    address supporter,
    uint256 amount,
    uint256 duration
  ) internal {
    LockInfo storage lockInfo = initiativeLocks[initiativeId][supporter];

    uint256 totalAmount = lockInfo.totalAmount + amount;
    uint256 newWeightedDuration = ((lockInfo.totalAmount * lockInfo.weightedDuration) +
      (amount * duration)) / totalAmount;

    lockInfo.totalAmount = totalAmount;
    lockInfo.weightedDuration = newWeightedDuration;
    lockInfo.timestamp = block.timestamp;
  }

  function acceptInitiative(uint256 initiativeId) external onlyOwner {
    if (initiativeId >= initiativeCount) revert InitiativeNotFound();
    Initiative storage initiative = initiatives[initiativeId];
    if (initiative.state != InitiativeState.Proposed)
      revert InvalidInitiativeState('Initiative is not in Proposed state');

    initiative.state = InitiativeState.Accepted;

    emit InitiativeAccepted(initiativeId);
  }

  function expireInitiative(uint256 initiativeId) external {
    if (initiativeId >= initiativeCount) revert InitiativeNotFound();
    Initiative storage initiative = initiatives[initiativeId];
    if (initiative.state != InitiativeState.Proposed)
      revert InvalidInitiativeState('Initiative is not in Proposed state');
    if (block.timestamp <= initiative.lastActivity + activityTimeout)
      revert InvalidInitiativeState('Initiative not yet eligible for expiration');

    initiative.state = InitiativeState.Expired;

    emit InitiativeExpired(initiativeId);
  }

  function withdrawTokens(uint256 initiativeId) public nonReentrant {
    if (initiativeId >= initiativeCount) revert InitiativeNotFound();
    Initiative storage initiative = initiatives[initiativeId];
    if (initiative.state != InitiativeState.Accepted && initiative.state != InitiativeState.Expired)
      revert InvalidInitiativeState('Initiative not in a withdrawable state');

    LockInfo storage lockInfo = initiativeLocks[initiativeId][msg.sender];
    if (lockInfo.totalAmount == 0 || lockInfo.withdrawn) revert NothingToWithdraw();

    uint256 amountToWithdraw = lockInfo.totalAmount;

    lockInfo.withdrawn = true;

    _removePendingWithdrawal(msg.sender, initiativeId);

    if (!IERC20(underlyingToken).transfer(msg.sender, amountToWithdraw))
      revert TokenTransferFailed();

    emit TokensWithdrawn(initiativeId, msg.sender, amountToWithdraw);
  }

  function withdrawAll() external nonReentrant {
    uint256[] storage initiativesToWithdraw = pendingWithdrawals[msg.sender];
    uint256 totalInitiatives = initiativesToWithdraw.length;
    bool hasWithdrawn = false;

    uint256 i = 0;
    while (i < totalInitiatives) {
      uint256 initiativeId = initiativesToWithdraw[i];
      Initiative storage initiative = initiatives[initiativeId];
      LockInfo storage lockInfo = initiativeLocks[initiativeId][msg.sender];

      if (
        (initiative.state == InitiativeState.Accepted ||
          initiative.state == InitiativeState.Expired) &&
        lockInfo.totalAmount > 0 &&
        !lockInfo.withdrawn
      ) {
        uint256 amountToWithdraw = lockInfo.totalAmount;
        lockInfo.withdrawn = true;

        _removePendingWithdrawal(msg.sender, initiativeId);
        totalInitiatives--;

        if (!IERC20(underlyingToken).transfer(msg.sender, amountToWithdraw))
          revert TokenTransferFailed();

        emit TokensWithdrawn(initiativeId, msg.sender, amountToWithdraw);
        hasWithdrawn = true;
      } else {
        i++;
      }
    }

    if (!hasWithdrawn) {
      revert NothingToWithdraw();
    }
  }

  function _addPendingWithdrawal(address supporter, uint256 initiativeId) internal {
    if (pendingWithdrawalIndex[supporter][initiativeId] != 0) {
      return;
    }
    pendingWithdrawals[supporter].push(initiativeId);
    pendingWithdrawalIndex[supporter][initiativeId] = pendingWithdrawals[supporter].length;
  }

  function _removePendingWithdrawal(address supporter, uint256 initiativeId) internal {
    uint256 index = pendingWithdrawalIndex[supporter][initiativeId];
    if (index == 0) revert InitiativeNotFound();
    index -= 1;

    uint256 lastIndex = pendingWithdrawals[supporter].length - 1;
    if (index != lastIndex) {
      uint256 lastInitiativeId = pendingWithdrawals[supporter][lastIndex];
      pendingWithdrawals[supporter][index] = lastInitiativeId;
      pendingWithdrawalIndex[supporter][lastInitiativeId] = index + 1;
    }
    pendingWithdrawals[supporter].pop();
    delete pendingWithdrawalIndex[supporter][initiativeId];
  }

  function getInitiative(uint256 initiativeId) external view returns (Initiative memory) {
    if (initiativeId >= initiativeCount) revert InitiativeNotFound();
    return initiatives[initiativeId];
  }

  function balanceOf(address account) public view returns (uint256) {
    return IERC20(underlyingToken).balanceOf(account);
  }

  function getWeight(uint256 initiativeId) external view returns (uint256) {
    if (initiativeId >= initiativeCount) revert InitiativeNotFound();
    uint256 totalCurrentWeight = 0;
    address[] storage supporters = initiativeSupporters[initiativeId];
    for (uint256 i = 0; i < supporters.length; i++) {
      address supporter = supporters[i];
      LockInfo storage lockInfo = initiativeLocks[initiativeId][supporter];
      uint256 currentWeight = _calculateCurrentWeight(lockInfo);
      totalCurrentWeight += currentWeight;
    }
    return totalCurrentWeight;
  }

  function getTotalWeight(uint256 initiativeId) external view returns (uint256) {
    if (initiativeId >= initiativeCount) revert InitiativeNotFound();
    return initiativeTotalInitialWeight[initiativeId];
  }

  function _calculateLockWeight(uint256 amount, uint256 duration) private pure returns (uint256) {
    return amount * duration;
  }

  function _calculateCurrentWeight(LockInfo storage lockInfo) private view returns (uint256) {
    if (lockInfo.withdrawn) {
      return 0;
    }
    uint256 elapsedTime = (block.timestamp - lockInfo.timestamp) / 30 days;
    if (elapsedTime >= lockInfo.weightedDuration) {
      return 0;
    }
    uint256 remainingDuration = lockInfo.weightedDuration - elapsedTime;

    // Using a differential decay model instead of linear decay
    // dW/dt = -k * W where k is a constant and W is the current weight
    // W(t) = W0 * exp(-k * t)
    // For simplicity, k is set to 1 / weightedDuration for an exponential decay over the duration
    uint256 decayFactor = exp((elapsedTime * 1e18) / lockInfo.weightedDuration);
    uint256 currentWeight = (lockInfo.totalAmount * remainingDuration * decayFactor) / 1e18;

    return currentWeight;
  }

  // TODO: Find a well tested library for this
  function exp(uint256 x) internal pure returns (uint256) {
    // Approximate exponential function using a simplified Taylor series expansion
    // e^(-x) where x is scaled by 1e18
    uint256 result = 1e18;
    uint256 term = 1e18;
    for (uint256 i = 1; i < 10; i++) {
      term = (term * x) / (i * 1e18);
      result += term;
    }
    return 1e18 / result;
  }
}
