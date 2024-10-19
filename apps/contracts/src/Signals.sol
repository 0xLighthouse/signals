// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.28;

import 'forge-std/console.sol';

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

import './DecayCurves.sol';

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

  /// @notice Interval used for lockup duration and calculating the decay curve
  /// Lockup durations are specified in the number of intervals, and the decay curve is also applied
  /// per interval (e.g. interval of [1 day] means the weight of the lock would only be updated once per day
  uint256 public lockInterval;

  /// @notice Specifies which decay function to use. 0 = linear, 1 = exponential, more to come
  uint256 public decayCurveType;

  /// @notice Parameters for the decay curve (the requirements of which depend on which curve is chosen)
  uint256[] public decayCurveParameters;

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
    /// @notice The current state of the initiative
    InitiativeState state;
    /// @notice The address of the account that proposed this initiative
    address proposer;
    /// @notice The timestamp when the initiative was created
    uint256 timestamp;
    /// @notice The timestamp of the last activity on the initiative
    /// @dev Used to determine if an initiative has become inactive and can be expired
    uint256 lastActivity;
  }

  /// @notice Struct to store lock information for each lockup
  struct LockInfo {
    /// @dev Amount of tokens locked
    uint256 tokenAmount;
    /// @dev Totel duration of the lock in intervals
    uint256 lockDuration;
    /// @dev Timestamp of when the lock was created
    uint256 created;
    /// @dev Flag indicating whether the locked tokens have been withdrawn
    bool withdrawn;
  }

  /// @notice (initiativeId => Initiative)
  mapping(uint256 => Initiative) public initiatives;

  /// @notice (initiativeId => weight)
  mapping(uint256 => uint256) public weights;

  /// @notice (initiativeId => (supporter => LockInfo))
  mapping(uint256 => mapping(address => LockInfo[])) public locks;

  /// @notice (initiativeId => supporter[])
  mapping(uint256 => address[]) public supporters;

  /// @notice (initiativeId => (supporter => bool))
  mapping(uint256 => mapping(address => bool)) public isSupporter;

  /// @dev (supporter => id[])
  mapping(address => uint256[]) public pendingWithdrawals;

  /// @dev (supporter => (id => index))
  mapping(address => mapping(uint256 => uint256)) private _pendingWithdrawalIndex;

  /// @dev {n} total initiatives
  uint256 public count = 0;

  event WeightUpdated(
    uint256 indexed initiativeId,
    address indexed supporter,
    uint256 tokenAmount,
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
    uint256 _lockInterval,
    uint256 _decayCurveType,
    uint256[] calldata _decayCurveParameters
  ) external isNotInitialized {
    underlyingToken = _underlyingToken;
    proposalThreshold = _proposalThreshold;
    acceptanceThreshold = _acceptanceThreshold;
    maxLockIntervals = _maxLockIntervals;
    proposalCap = _proposalCap;
    lockInterval = _lockInterval;
    decayCurveType = _decayCurveType;
    decayCurveParameters = _decayCurveParameters;

    transferOwnership(owner_);
  }

  modifier initiativeExists(uint256 initiativeId) {
    if (initiativeId >= count) revert InitiativeNotFound();
    _;
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
    _addInitiative(title, body);
  }

  function _addInitiative (
    string memory title,
    string memory body
  ) internal hasValidInput(title, body) returns (uint256 id) {
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
    return initiativeId;
  }

  /// @notice Proposes a new initiative with locked tokens
  /// @param title Title of the initiative
  /// @param body Body of the initiative
  /// @param amount Amount of tokens to lock
  /// @param duration Duration for which tokens are locked (in intervals)
  function proposeInitiativeWithLock(
    string memory title,
    string memory body,
    uint256 amount,
    uint256 duration
  ) external hasSufficientTokens hasValidInput(title, body) {
    uint256 id = _addInitiative(title, body);
    _addLock(id, msg.sender, amount, duration);
  }

  /// @notice Allows a user to support an existing initiative with locked tokens
  /// @param initiativeId ID of the initiative to support
  /// @param amount Amount of tokens to lock
  /// @param intervals Duration for which tokens are locked (in months)
  // TODO: Rename this to increaseLock
  function supportInitiative(uint256 initiativeId, uint256 amount, uint256 intervals) external {
    _addLock(initiativeId, msg.sender, amount, intervals);
  }

  function _addLock(
    uint256 initiativeId,
    address supporter,
    uint256 amount,
    uint256 duration
  ) internal {
    if (initiativeId >= count) revert InitiativeNotFound();
    if (duration == 0 || duration > maxLockIntervals) revert InvalidInput('Invalid lock interval');
    if (balanceOf(msg.sender) < amount) revert InsufficientTokens();

    Initiative storage initiative = initiatives[initiativeId];
    if (initiative.state != InitiativeState.Proposed)
      revert InvalidInitiativeState('Initiative is not in Proposed state');

    if (!IERC20(underlyingToken).transferFrom(msg.sender, address(this), amount))
      revert TokenTransferFailed();

    LockInfo memory lock = LockInfo({
      created: block.timestamp,
      tokenAmount: amount,
      lockDuration: duration,
      withdrawn: false
    });

    //TODO: Do we need to check if exists first?
    locks[initiativeId][supporter].push(lock);

    initiative.lastActivity = lock.created;

    if (!isSupporter[initiativeId][msg.sender]) {
      supporters[initiativeId].push(msg.sender);
      isSupporter[initiativeId][msg.sender] = true;
    }

    _addPendingWithdrawal(msg.sender, initiativeId);

    //TODO: Rename and redefine this event
    emit WeightUpdated(
      initiativeId,
      msg.sender,
      lock.tokenAmount,
      lock.lockDuration,
      block.timestamp
    );
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

  function withdrawTokens(uint256 initiativeId) initiativeExists(initiativeId) public nonReentrant {
    Initiative storage initiative = initiatives[initiativeId];
    if (initiative.state != InitiativeState.Accepted && initiative.state != InitiativeState.Expired)
      revert InvalidInitiativeState('Initiative not in a withdrawable state');

    LockInfo[] storage _locks = locks[initiativeId][msg.sender];
    uint256 withdrawAmount = _markWithdrawnFromLocks(_locks);

    if (withdrawAmount == 0) revert NothingToWithdraw();

    _removePendingWithdrawal(msg.sender, initiativeId);

    if (!IERC20(underlyingToken).transfer(msg.sender, withdrawAmount))
      revert TokenTransferFailed();

    emit TokensWithdrawn(initiativeId, msg.sender, withdrawAmount);
  }

  function _markWithdrawnFromLocks(
    LockInfo[] storage _locks
  ) internal returns (uint256 totalAmount) {
    uint256 total = 0;
    for (uint256 i = 0; i < _locks.length; i++) {
      if (_locks[i].tokenAmount > 0 && !_locks[i].withdrawn) {
        total += _locks[i].tokenAmount;
        _locks[i].withdrawn = true;
      }
    }
    return total;
  }

  // TODO: Redo withdrawal tracking, then simplify iterating over pending withdrawals
  function withdrawAllTokens() external nonReentrant {
    uint256[] storage initiativesToWithdraw = pendingWithdrawals[msg.sender];
    uint256 totalInitiatives = initiativesToWithdraw.length;

    uint256 totalToWithdraw = 0;
    uint256 i = 0;
    while (i < totalInitiatives) {
      uint256 initiativeId = initiativesToWithdraw[i];
      Initiative storage initiative = initiatives[initiativeId];
      LockInfo[] storage _locks = locks[initiativeId][msg.sender];

      if (
        initiative.state == InitiativeState.Accepted ||
        initiative.state == InitiativeState.Expired
      ) {
        uint256 amountToWithdraw = _markWithdrawnFromLocks(_locks);
        totalToWithdraw += amountToWithdraw;

        _removePendingWithdrawal(msg.sender, initiativeId);
        totalInitiatives--;

        if (!IERC20(underlyingToken).transfer(msg.sender, amountToWithdraw))
          revert TokenTransferFailed();

        emit TokensWithdrawn(initiativeId, msg.sender, amountToWithdraw);
      } else {
        i++;
      }
    }

    if (totalToWithdraw == 0) {
      revert NothingToWithdraw();
    }
  }

  //TODO: Redo withdrawal tracking
  function _addPendingWithdrawal(address supporter, uint256 initiativeId) internal {
    if (_pendingWithdrawalIndex[supporter][initiativeId] != 0) {
      return;
    }
    pendingWithdrawals[supporter].push(initiativeId);
    _pendingWithdrawalIndex[supporter][initiativeId] = pendingWithdrawals[supporter].length;
  }

  function _removePendingWithdrawal(address supporter, uint256 initiativeId) internal {
    uint256 index = _pendingWithdrawalIndex[supporter][initiativeId];
    if (index == 0) revert InitiativeNotFound();
    index -= 1;

    uint256 lastIndex = pendingWithdrawals[supporter].length - 1;
    if (index != lastIndex) {
      uint256 lastInitiativeId = pendingWithdrawals[supporter][lastIndex];
      pendingWithdrawals[supporter][index] = lastInitiativeId;
      _pendingWithdrawalIndex[supporter][lastInitiativeId] = index + 1;
    }
    pendingWithdrawals[supporter].pop();
    delete _pendingWithdrawalIndex[supporter][initiativeId];
  }

  function getInitiative(uint256 initiativeId) external view initiativeExists(initiativeId) returns (Initiative memory) {
    return initiatives[initiativeId];
  }

  function balanceOf(address account) public view returns (uint256) {
    return IERC20(underlyingToken).balanceOf(account);
  }

  function getSupporters(uint256 initiativeId) external view initiativeExists(initiativeId) returns (address[] memory) {
    return supporters[initiativeId];
  }

  function getWeight(uint256 initiativeId) external view initiativeExists(initiativeId) returns (uint256) {
    uint256 totalCurrentWeight = 0;
    address[] memory _supporters = supporters[initiativeId];
    
    for (uint256 i = 0; i < _supporters.length; i++) {
      address supporter = _supporters[i];
      LockInfo[] storage lockInfos = locks[initiativeId][supporter];
      uint256 lockCount = lockInfos.length;
      for (uint256 j = 0; j < lockCount; j++) {
        uint256 currentWeight = _calculateLockWeightAt(lockInfos[j], block.timestamp);
        totalCurrentWeight += currentWeight;
      }
    }

    return totalCurrentWeight;
  }

  function getWeightAt(
    uint256 initiativeId,
    uint256 timestamp
  ) external view initiativeExists(initiativeId) returns (uint256) {
    return _calculateWeightAt(initiativeId, timestamp);
  }

  function _calculateWeightAt(
    uint256 initiativeId,
    uint256 timestamp
  ) internal view returns (uint256) {
    address[] memory _supporters = supporters[initiativeId];

    uint256 weight = 0;
    for (uint256 i = 0; i < _supporters.length; i++) {
        weight += _calculateWeightForSupporterAt(initiativeId, _supporters[i], timestamp);
    }

    return weight;
  }

  function _calculateWeightForSupporterAt(
    uint256 initiativeId,
    address supporter,
    uint256 timestamp
  ) internal view returns (uint256) {
    LockInfo[] storage _locks = locks[initiativeId][supporter];

    uint256 weight = 0;
    for (uint256 i = 0; i < _locks.length; i++) {
      weight += _calculateLockWeightAt(_locks[i], timestamp);
    }
    return weight;
  }

  function _calculateLockWeightAt(
    LockInfo memory lock,
    uint256 timestamp
  ) internal view returns (uint256) {
    uint256 elapsedIntervals = (timestamp - lock.created) / lockInterval;
    if (elapsedIntervals >= lock.lockDuration || lock.withdrawn) {
      return 0;
    }

    require(decayCurveType < 2, 'Invalid decayCurveType');

    if (decayCurveType == 0) {
      return DecayCurves.linear(lock.lockDuration, lock.tokenAmount, elapsedIntervals, decayCurveParameters);
    } else {
      return DecayCurves.exponential(lock.lockDuration, lock.tokenAmount, elapsedIntervals, decayCurveParameters);
    }
  }

  function getWeightForSupporterAt(
    uint256 initiativeId,
    address supporter,
    uint256 timestamp
  ) external view initiativeExists(initiativeId) returns (uint256) {
    return _calculateWeightForSupporterAt(initiativeId, supporter, timestamp);
  }

  /// @notice Returns the address of the underlying token
  function token() external view returns (address) {
    return underlyingToken;
  }

  function totalProposals() external view returns (uint256) {
    return count;
  }

  function totalSupporters(uint256 initiativeId) external view returns (uint256) {
    return supporters[initiativeId].length;
  }
}
