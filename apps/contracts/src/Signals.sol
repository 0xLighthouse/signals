// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'lib/openzeppelin-contracts/contracts/access/Ownable.sol';
import 'lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import 'lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol';

/// @title Signals
contract Signals is Ownable, ReentrancyGuard {
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
  error NotProposedState();
  error AlreadyAccepted();
  error NoSupporters();
  error AlreadyWithdrawn();
  error NotAcceptableState();
  error NothingToWithdraw();
  error InitiativeNotExpired();

  /// @notice Threshold required to accept a proposal
  uint256 public acceptanceThreshold;

  uint256 public lockDurationCap;
  uint256 public proposalCap;
  uint256 public decayCurveType;
  address public underlyingToken;

  /// @notice Inactivity threshold after which an initiative can be expired (in seconds)
  uint256 public inactivityThreshold = 60 days;

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
    uint256 amount;
    uint256 duration; // in months
    uint256 timestamp; // when the lock started
    bool withdrawn; // indicates if tokens have been withdrawn
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
    inactivityThreshold = _newThreshold;
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
      timestamp: block.timestamp,
      lastActivity: block.timestamp
    });

    uint256 initiativeId = initiativeCount;
    initiatives[initiativeId] = newInitiative;
    initiativeCount++;

    // Store the lock info for the proposer
    initiativeLocks[initiativeId][msg.sender] = LockInfo({
      amount: amount,
      duration: duration,
      timestamp: block.timestamp,
      withdrawn: false
    });

    // Update total initial weight
    initiativeTotalInitialWeight[initiativeId] = weight;

    // Add proposer to the supporters list if not already added
    if (!isSupporter[initiativeId][msg.sender]) {
      initiativeSupporters[initiativeId].push(msg.sender);
      isSupporter[initiativeId][msg.sender] = true;
    }

    // Add initiative ID to pending withdrawals
    _addPendingWithdrawal(msg.sender, initiativeId);

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
      timestamp: block.timestamp,
      withdrawn: false
    });

    // Update total initial weight
    initiativeTotalInitialWeight[initiativeId] += weight;

    // Add supporter to the supporters list if not already added
    if (!isSupporter[initiativeId][msg.sender]) {
      initiativeSupporters[initiativeId].push(msg.sender);
      isSupporter[initiativeId][msg.sender] = true;
    }

    // Add initiative ID to pending withdrawals
    _addPendingWithdrawal(msg.sender, initiativeId);

    // Update last activity timestamp
    initiative.lastActivity = block.timestamp;

    emit WeightUpdated(initiativeId, msg.sender, amount, duration, block.timestamp);
  }

  /// @notice Accepts an initiative
  /// @param initiativeId ID of the initiative to accept
  function acceptInitiative(uint256 initiativeId) external onlyOwner {
    require(initiativeId < initiativeCount, 'Invalid initiative ID');
    Initiative storage initiative = initiatives[initiativeId];
    require(initiative.state == InitiativeState.Proposed, 'Initiative is not in Proposed state');

    // Update the initiative state to Accepted
    initiative.state = InitiativeState.Accepted;

    // Emit an event for acceptance
    emit InitiativeAccepted(initiativeId);
  }

  /// @notice Expires an initiative if it has been inactive for longer than inactivityThreshold
  /// @param initiativeId ID of the initiative to expire
  function expireInitiative(uint256 initiativeId) external {
    require(initiativeId < initiativeCount, 'Invalid initiative ID');
    Initiative storage initiative = initiatives[initiativeId];
    require(initiative.state == InitiativeState.Proposed, 'Initiative is not in Proposed state');
    require(
      block.timestamp > initiative.lastActivity + inactivityThreshold,
      'Initiative not yet eligible for expiration'
    );

    // Update the initiative state to Expired
    initiative.state = InitiativeState.Expired;

    // Emit an event for expiration
    emit InitiativeExpired(initiativeId);
  }

  /// @notice Allows supporters to withdraw their tokens after initiative is accepted or expired
  /// @param initiativeId ID of the initiative
  function withdrawTokens(uint256 initiativeId) public nonReentrant {
    require(initiativeId < initiativeCount, 'Invalid initiative ID');
    Initiative storage initiative = initiatives[initiativeId];
    require(
      initiative.state == InitiativeState.Accepted || initiative.state == InitiativeState.Expired,
      'Initiative not in a withdrawable state'
    );

    LockInfo storage lockInfo = initiativeLocks[initiativeId][msg.sender];
    require(lockInfo.amount > 0, 'No tokens to withdraw');
    require(!lockInfo.withdrawn, 'Tokens already withdrawn');

    uint256 amountToWithdraw = lockInfo.amount;

    // Mark as withdrawn
    lockInfo.withdrawn = true;

    // Remove initiative from pending withdrawals
    _removePendingWithdrawal(msg.sender, initiativeId);

    // Transfer tokens back to the supporter
    require(
      IERC20(underlyingToken).transfer(msg.sender, amountToWithdraw),
      'Token transfer failed'
    );

    emit TokensWithdrawn(initiativeId, msg.sender, amountToWithdraw);
  }

  /// @notice Allows supporters to withdraw tokens from all initiatives they have pending withdrawals from
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
        lockInfo.amount > 0 &&
        !lockInfo.withdrawn
      ) {
        uint256 amountToWithdraw = lockInfo.amount;
        lockInfo.withdrawn = true;

        // Remove initiative from pending withdrawals
        _removePendingWithdrawal(msg.sender, initiativeId);
        totalInitiatives--;

        // Transfer tokens back to the supporter
        require(
          IERC20(underlyingToken).transfer(msg.sender, amountToWithdraw),
          'Token transfer failed'
        );

        emit TokensWithdrawn(initiativeId, msg.sender, amountToWithdraw);
        hasWithdrawn = true;
      } else {
        i++;
      }
    }

    if (!hasWithdrawn) {
      revert('No tokens to withdraw');
    }
  }

  /// @notice Internal function to add an initiative ID to a user's pending withdrawals
  /// @param supporter Address of the supporter
  /// @param initiativeId ID of the initiative
  function _addPendingWithdrawal(address supporter, uint256 initiativeId) internal {
    uint256 index = pendingWithdrawals[supporter].length;
    pendingWithdrawals[supporter].push(initiativeId);
    pendingWithdrawalIndex[supporter][initiativeId] = index;
  }

  /// @notice Internal function to remove an initiative ID from a user's pending withdrawals
  /// @param supporter Address of the supporter
  /// @param initiativeId ID of the initiative
  function _removePendingWithdrawal(address supporter, uint256 initiativeId) internal {
    uint256 index = pendingWithdrawalIndex[supporter][initiativeId];
    uint256 lastIndex = pendingWithdrawals[supporter].length - 1;
    if (index != lastIndex) {
      uint256 lastInitiativeId = pendingWithdrawals[supporter][lastIndex];
      pendingWithdrawals[supporter][index] = lastInitiativeId;
      pendingWithdrawalIndex[supporter][lastInitiativeId] = index;
    }
    pendingWithdrawals[supporter].pop();
    delete pendingWithdrawalIndex[supporter][initiativeId];
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
    if (lockInfo.withdrawn) {
      return 0;
    }
    uint256 elapsedTime = (block.timestamp - lockInfo.timestamp) / 30 days; // Assuming 1 month = 30 days
    if (elapsedTime >= lockInfo.duration) {
      return 0;
    }
    uint256 remainingDuration = lockInfo.duration - elapsedTime;
    uint256 currentWeight = lockInfo.amount * remainingDuration;
    return currentWeight;
  }
}
