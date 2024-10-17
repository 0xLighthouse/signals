// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

/// @title Signals
contract Signals is Ownable, ReentrancyGuard {
  // @notice Possible initiative states
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

  /// @notice Minimum tokens required to propose an initiative
  uint256 public proposalThreshold;

  /// @notice Minimum tokens required to accept an initiative
  uint256 public acceptanceThreshold;

  /// @notice Maximum time we can lock tokens for denominated in intervals
  uint256 public maxLockIntervals;

  /// @notice Maximum number of proposals allowed
  uint256 public proposalCap;

  /// @notice Interval used for the decay curve
  /// eg. A decay interval of [1 month] would mean the weight of the lock reduces each month
  /// eg. A decay interval of [1 day] would mean the weight of the lock reduces each day
  uint256 public decayInterval;

  /// @notice Address of the underlying token (ERC20)
  address public underlyingToken;

  /// @notice Inactivity threshold after which an initiative can be expired (in seconds)
  uint256 public activityTimeout = 60 days;

  /// @notice Represents an initiative in the Signals contract
  /// @dev Stores all relevant information about a single initiative
  struct Initiative {
    /// @notice The title of the initiative
    string title;
    /// @notice The detailed body of the initiative in markdown format
    string body;
    InitiativeState state;
    /// @notice The address of the account that proposed this initiative
    address proposer;
    /// @notice The timestamp when the initiative was created
    uint256 timestamp;
    /// @notice The timestamp of the last activity on the initiative
    /// @dev Used to determine if an initiative has become inactive and can be expired
    uint256 lastActivity;
  }

  /// @notice Struct to store lock information for each supporter
  struct LockInfo {
    /// @dev Total amount of tokens locked by the supporter for this initiative
    uint256 totalAmount;
    /// @dev Weighted average duration of the lock in months
    uint256 weightedDuration;
    /// @dev Timestamp of the last update to this lock
    uint256 timestamp;
    /// @dev Flag indicating whether the locked tokens have been withdrawn
    bool withdrawn;
  }

  /// @notice (initiativeId => Initiative)
  mapping(uint256 => Initiative) public initiatives;

  /// @notice (initiativeId => weight)
  mapping(uint256 => uint256) public weights;

  /// @notice (initiativeId => (supporter => LockInfo))
  mapping(uint256 => mapping(address => LockInfo)) public locks;

  /// @notice (initiativeId => supporter[])
  mapping(uint256 => address[]) public supporters;

  /// @notice (initiativeId => (supporter => bool))
  mapping(uint256 => mapping(address => bool)) public isSupporter;

  /// @dev (supporter => id[])
  mapping(address => uint256[]) public pendingWithdrawals;

  /// @dev (supporter => (id => index))
  mapping(address => mapping(uint256 => uint256)) private pendingWithdrawalIndex;

  /// @dev {n} total initiatives
  uint256 public count;

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

  function initialize(
    address owner_,
    address _underlyingToken,
    uint256 _proposalThreshold,
    uint256 _acceptanceThreshold,
    uint256 _maxLockIntervals,
    uint256 _proposalCap,
    uint256 _decayInterval
  ) external isNotInitialized {
    underlyingToken = _underlyingToken;
    proposalThreshold = _proposalThreshold;
    acceptanceThreshold = _acceptanceThreshold;
    maxLockIntervals = _maxLockIntervals;
    proposalCap = _proposalCap;
    decayInterval = _decayInterval;

    transferOwnership(owner_);
  }

  modifier isNotInitialized() {
    require(acceptanceThreshold == 0, 'Already initialized');
    _;
  }

  modifier hasSufficientTokens() {
    if (balanceOf(msg.sender) < proposalThreshold) revert InsufficientTokens();
    _;
  }

  modifier hasValidInput(string memory title, string memory body) {
    if (bytes(title).length == 0 || bytes(body).length == 0)
      revert InvalidInput('Title or body cannot be empty');
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
  function proposeInitiative(
    string memory title,
    string memory body
  ) external hasSufficientTokens hasValidInput(title, body) {
    Initiative memory newInitiative = Initiative({
      state: InitiativeState.Proposed,
      title: title,
      body: body,
      proposer: msg.sender,
      timestamp: block.timestamp,
      lastActivity: block.timestamp
    });

    uint256 initiativeId = count;
    initiatives[initiativeId] = newInitiative;
    count++;

    emit InitiativeProposed(initiativeId, msg.sender, title, body);
  }

  /// @notice Proposes a new initiative with locked tokens
  /// @param title Title of the initiative
  /// @param body Body of the initiative
  /// @param amount Amount of tokens to lock
  /// @param intervals Duration for which tokens are locked (in months)
  function proposeInitiativeWithLock(
    string memory title,
    string memory body,
    uint256 amount,
    uint256 intervals
  ) external hasSufficientTokens hasValidInput(title, body) {
    if (intervals == 0 || intervals > maxLockIntervals)
      revert InvalidInput('Invalid lock interval');

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

    uint256 initiativeId = count;
    initiatives[initiativeId] = newInitiative;
    count++;

    _updateLockInfo(initiativeId, msg.sender, amount, intervals);

    uint256 weight = _calculateLockWeight(amount, intervals);

    weights[initiativeId] += weight;

    if (!isSupporter[initiativeId][msg.sender]) {
      supporters[initiativeId].push(msg.sender);
      isSupporter[initiativeId][msg.sender] = true;
    }

    _addPendingWithdrawal(msg.sender, initiativeId);

    emit InitiativeProposed(initiativeId, msg.sender, title, body);
    emit WeightUpdated(
      initiativeId,
      msg.sender,
      locks[initiativeId][msg.sender].totalAmount,
      locks[initiativeId][msg.sender].weightedDuration,
      block.timestamp
    );
  }

  /// @notice Allows a user to support an existing initiative with locked tokens
  /// @param initiativeId ID of the initiative to support
  /// @param amount Amount of tokens to lock
  /// @param intervals Duration for which tokens are locked (in months)
  // TODO: Rename this to increaseLock
  function supportInitiative(uint256 initiativeId, uint256 amount, uint256 intervals) external {
    if (intervals == 0 || intervals > maxLockIntervals)
      revert InvalidInput('Invalid lock interval');
    if (initiativeId >= count) revert InitiativeNotFound();
    if (balanceOf(msg.sender) < amount) revert InsufficientTokens();
    Initiative storage initiative = initiatives[initiativeId];
    if (initiative.state != InitiativeState.Proposed)
      revert InvalidInitiativeState('Initiative is not in Proposed state');

    if (!IERC20(underlyingToken).transferFrom(msg.sender, address(this), amount))
      revert TokenTransferFailed();

    _updateLockInfo(initiativeId, msg.sender, amount, intervals);

    uint256 weight = _calculateLockWeight(amount, intervals);
    weights[initiativeId] += weight;

    if (!isSupporter[initiativeId][msg.sender]) {
      supporters[initiativeId].push(msg.sender);
      isSupporter[initiativeId][msg.sender] = true;
    }

    _addPendingWithdrawal(msg.sender, initiativeId);

    initiative.lastActivity = block.timestamp;

    emit WeightUpdated(
      initiativeId,
      msg.sender,
      locks[initiativeId][msg.sender].totalAmount,
      locks[initiativeId][msg.sender].weightedDuration,
      block.timestamp
    );
  }

  function _updateLockInfo(
    uint256 initiativeId,
    address supporter,
    uint256 amount,
    uint256 intervals
  ) internal {
    LockInfo storage lockInfo = locks[initiativeId][supporter];

    console.log('totalAmount:', lockInfo.totalAmount);
    console.log('weightedDuration:', lockInfo.weightedDuration);
    console.log('amount:', amount);

    uint256 totalAmount = lockInfo.totalAmount + amount;

    console.log('totalAmount:', totalAmount);
    uint256 newWeightedDuration = ((lockInfo.totalAmount * lockInfo.weightedDuration) +
      (amount * intervals)) / totalAmount;
    console.log('newWeightedDuration:', newWeightedDuration);

    lockInfo.totalAmount = totalAmount;
    lockInfo.weightedDuration = newWeightedDuration;
    lockInfo.timestamp = block.timestamp;
  }

  function acceptInitiative(uint256 initiativeId) external onlyOwner {
    if (initiativeId >= count) revert InitiativeNotFound();
    Initiative storage initiative = initiatives[initiativeId];
    if (initiative.state != InitiativeState.Proposed)
      revert InvalidInitiativeState('Initiative is not in Proposed state');

    initiative.state = InitiativeState.Accepted;

    emit InitiativeAccepted(initiativeId);
  }

  function expireInitiative(uint256 initiativeId) external {
    if (initiativeId >= count) revert InitiativeNotFound();
    Initiative storage initiative = initiatives[initiativeId];
    if (initiative.state != InitiativeState.Proposed)
      revert InvalidInitiativeState('Initiative is not in Proposed state');
    if (block.timestamp <= initiative.lastActivity + activityTimeout)
      revert InvalidInitiativeState('Initiative not yet eligible for expiration');

    initiative.state = InitiativeState.Expired;

    emit InitiativeExpired(initiativeId);
  }

  function withdrawTokens(uint256 initiativeId) public nonReentrant {
    if (initiativeId >= count) revert InitiativeNotFound();
    Initiative storage initiative = initiatives[initiativeId];
    if (initiative.state != InitiativeState.Accepted && initiative.state != InitiativeState.Expired)
      revert InvalidInitiativeState('Initiative not in a withdrawable state');

    LockInfo storage lockInfo = locks[initiativeId][msg.sender];
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
      LockInfo storage lockInfo = locks[initiativeId][msg.sender];

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
    if (initiativeId >= count) revert InitiativeNotFound();
    return initiatives[initiativeId];
  }

  function balanceOf(address account) public view returns (uint256) {
    return IERC20(underlyingToken).balanceOf(account);
  }

  function getWeight(uint256 initiativeId) external view returns (uint256) {
    if (initiativeId >= count) revert InitiativeNotFound();
    uint256 totalCurrentWeight = 0;
    address[] storage supporters = supporters[initiativeId];
    for (uint256 i = 0; i < supporters.length; i++) {
      address supporter = supporters[i];
      LockInfo storage lockInfo = locks[initiativeId][supporter];
      uint256 currentWeight = _calculateWeight(lockInfo, block.timestamp);
      totalCurrentWeight += currentWeight;
    }
    return totalCurrentWeight;
  }

  function getWeightAt(
    uint256 initiativeId,
    address supporter,
    uint256 timestamp
  ) external view returns (uint256) {
    if (initiativeId >= count) revert InitiativeNotFound();
    LockInfo storage lockInfo = locks[initiativeId][supporter];
    return _calculateWeight(lockInfo, timestamp);
  }

  function getTotalWeight(uint256 initiativeId) external view returns (uint256) {
    if (initiativeId >= count) revert InitiativeNotFound();
    return weights[initiativeId];
  }

  function _calculateLockWeight(uint256 amount, uint256 duration) private pure returns (uint256) {
    return amount * duration;
  }

  function _calculateWeight(
    LockInfo storage lockInfo,
    uint256 timestamp
  ) private view returns (uint256) {
    if (lockInfo.withdrawn) {
      return 0;
    }
    uint256 elapsedTime = (timestamp - lockInfo.timestamp) / decayInterval;
    if (elapsedTime >= lockInfo.weightedDuration) {
      return 0;
    }
    uint256 remainingDuration = lockInfo.weightedDuration - elapsedTime;

    // Using a differential decay model instead of linear decay
    // dW/dt = -k * W where k is a constant and W is the current weight
    // W(t) = W0 * exp(-k * t)
    // For simplicity, k is set to 1 / weightedDuration for an exponential decay over the duration
    uint256 decayFactor = exp((elapsedTime * 1e18) / lockInfo.weightedDuration);
    uint256 currentWeight = (lockInfo.totalAmount * remainingDuration * decayFactor);

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

  /// @notice Returns the address of the underlying token
  function token() external view returns (address) {
    return underlyingToken;
  }
}
