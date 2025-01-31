// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.28;

import 'forge-std/console.sol';

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@solady/tokens/ERC721.sol';

import './DecayCurves.sol';
import './Incentives.sol';

/**
 * @title Signals by Lighthouse <https://lighthouse.cx>
 *
 * @notice Manage community initiatives with governance tokens
 * @notice Locked positions are represented by transferrable ERC6909 tokens
 *         that can be traded and used to redeem the underlying tokens
 *         when the lock expires
 *
 * @author 1a35e1.eth <arnold@lighthouse.cx>
 * @author jkm.eth <james@lighthouse.cx>
 */
contract Signals is ERC721, Ownable, ReentrancyGuard {
  /**
   * @notice Represents an initiative in the Signals contract
   * @dev Stores all relevant information about a single initiative
   *
   * @param title The title of the initiative
   * @param body The detailed body of the initiative in markdown format
   * @param state The current state of the initiative
   * @param proposer The address of the account that proposed this initiative
   * @param timestamp The timestamp when the initiative was created
   * @param lastActivity Used to determine if an initiative has become inactive and can be expired
   */
  struct Initiative {
    string title;
    string body;
    InitiativeState state;
    address proposer;
    uint256 timestamp;
    uint256 lastActivity;
  }

  /// @notice ID of the token that represents locked tokens
  uint256 public constant LOCK_TOKEN_ID = 1;

  /// @notice Possible initiative states
  enum InitiativeState {
    Proposed,
    Accepted,
    Cancelled,
    Expired
  }

  /**
   * @notice Struct to store lock information for each lockup
   *
   * @param initiativeId ID of the initiative
   * @param tokenAmount Amount of tokens locked
   * @param lockDuration Total duration of the lock in intervals
   * @param created Timestamp of when the lock was created
   * @param withdrawn Flag indicating whether the locked tokens have been withdrawn
   */
  struct LockInfo {
    uint256 initiativeId;
    uint256 tokenAmount;
    uint256 lockDuration;
    uint256 created;
    bool withdrawn;
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

  /**
   * @notice Interval used for lockup duration and calculating the decay curve
   *
   * Lockup durations are specified in the number of intervals, and the decay curve is also applied
   * per interval (e.g. interval of [1 day] means the weight of the lock would only be updated once per day
   */
  uint256 public lockInterval;

  /// @notice Specifies which decay function to use. 0 = linear, 1 = exponential, more to come
  uint256 public decayCurveType;

  /// @notice Parameters for the decay curve (the requirements of which depend on which curve is chosen)
  uint256[] public decayCurveParameters;

  /// @notice Address of the underlying token (ERC20)
  address public underlyingToken;

  /// @notice Inactivity threshold after which an initiative can be expired (in seconds)
  uint256 public activityTimeout = 60 days;

  /// @notice (initiativeId => Initiative)
  mapping(uint256 => Initiative) public initiatives;

  /// @notice Mapping from token ID to lock details
  mapping(uint256 => LockInfo) public locks;

  /// @notice Mapping from initiative ID to array of token IDs
  mapping(uint256 => uint256[]) public initiativeLocks;

  /// @notice Mapping from supporter to their token IDs
  mapping(address => uint256[]) public supporterLocks;

  /// @notice (initiativeId => supporter[])
  mapping(uint256 => address[]) public supporters;

  /// @dev (initiativeId => (supporter => bool))
  // Shows which initiatives a supporter has pending withdrawals for
  mapping(uint256 => mapping(address => bool)) public isSupporter;

  /// @notice Track locked tokens with NFTs
  uint256 public nextTokenId = 1;

  /// @notice Add back the initiative counter
  uint256 public initiativeCount = 0;

  /**
   * @notice Event emitted when a supporter supports an initiative
   *
   * @param initiativeId ID of the initiative
   * @param supporter Address of the supporter
   * @param tokenAmount Amount of tokens locked
   * @param lockDuration Duration for which tokens are locked (in intervals)
   * @param timestamp Timestamp of when the support was made
   */
  event InitiativeSupported(
    uint256 indexed initiativeId,
    address indexed supporter,
    uint256 tokenAmount,
    uint256 lockDuration,
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
  event InitiativeAccepted(uint256 indexed initiativeId, address indexed actor);

  /// @notice Event emitted when an initiative is expired
  event InitiativeExpired(uint256 indexed initiativeId, address indexed actor);

  /// @notice Event emitted when a supporter withdraws their tokens
  event TokensWithdrawn(uint256 indexed initiativeId, address indexed supporter, uint256 amount);

  /// @notice Event emitted when the decay curve is updated
  event DecayCurveUpdated(uint256 decayCurveType, uint256[] decayCurveParameters);

  /// @notice Do we event need this? It would revert if the initiativeId is out of bounds
  modifier exists(uint256 initiativeId) {
    if (initiativeId >= initiativeCount) revert InitiativeNotFound();
    _;
  }

  modifier isNotInitialized() {
    require(acceptanceThreshold == 0, 'Already initialized');
    _;
  }

  modifier hasSufficientTokens(uint256 amount) {
    if (IERC20(underlyingToken).balanceOf(msg.sender) < amount) revert InsufficientTokens();
    _;
  }

  modifier hasValidInput(string memory title, string memory body) {
    if (bytes(title).length == 0 || bytes(body).length == 0)
      revert InvalidInput('Title or body cannot be empty');
    _;
  }

  /// @notice (Optional) Reference to the Incentives contract (can only be set once)
  // TODO: Reconsider tradeoffs of this design pattern properly
  Incentives public incentives;

  constructor() ERC721() Ownable() {}

  function name() public pure override returns (string memory) {
    return 'Signal Lock Position';
  }

  function symbol() public pure override returns (string memory) {
    return 'SLP';
  }

  function tokenURI(uint256) public pure override returns (string memory) {
    return ''; // Return empty string for now
  }

  function _addInitiative(
    string memory title,
    string memory body
  ) internal hasSufficientTokens(proposalThreshold) returns (uint256 id) {
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
    return initiativeId;
  }

  function _addLock(
    uint256 initiativeId,
    address supporter,
    uint256 amount,
    uint256 lockDuration
  ) internal hasSufficientTokens(amount) {
    if (lockDuration == 0 || lockDuration > maxLockIntervals) {
      revert InvalidInput('Invalid lock interval');
    }

    Initiative storage initiative = initiatives[initiativeId];

    if (initiative.state != InitiativeState.Proposed) {
      revert InvalidInitiativeState('Initiative is not in Proposed state');
    }

    if (!IERC20(underlyingToken).transferFrom(msg.sender, address(this), amount))
      revert TokenTransferFailed();

    uint256 tokenId = nextTokenId++;
    _mint(supporter, tokenId);
    locks[tokenId] = LockInfo({
      initiativeId: initiativeId,
      tokenAmount: amount,
      lockDuration: lockDuration,
      created: block.timestamp,
      withdrawn: false
    });
    initiativeLocks[initiativeId].push(tokenId);
    supporterLocks[supporter].push(tokenId);

    initiative.lastActivity = block.timestamp;

    if (!isSupporter[initiativeId][supporter]) {
      supporters[initiativeId].push(supporter);
      isSupporter[initiativeId][supporter] = true;
    }

    emit InitiativeSupported(initiativeId, supporter, amount, lockDuration, block.timestamp);
  }

  function _calculateWeightAt(
    uint256 initiativeId,
    uint256 timestamp
  ) internal view returns (uint256) {
    uint256[] memory tokenIds = initiativeLocks[initiativeId];
    uint256 weight = 0;

    for (uint256 i = 0; i < tokenIds.length; i++) {
      uint256 tokenId = tokenIds[i];
      LockInfo memory lock = locks[tokenId];
      if (!lock.withdrawn) {
        weight += _calculateLockWeightAt(lock, timestamp);
      }
    }

    return weight;
  }

  function _calculateWeightForSupporterAt(
    uint256 initiativeId,
    address supporter,
    uint256 timestamp
  ) internal view returns (uint256) {
    uint256[] memory tokenIds = supporterLocks[supporter];
    uint256 weight = 0;

    for (uint256 i = 0; i < tokenIds.length; i++) {
      uint256 tokenId = tokenIds[i];
      LockInfo memory lock = locks[tokenId];
      if (lock.initiativeId == initiativeId && !lock.withdrawn) {
        weight += _calculateLockWeightAt(lock, timestamp);
      }
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
      return
        DecayCurves.linear(
          lock.lockDuration,
          lock.tokenAmount,
          elapsedIntervals,
          decayCurveParameters
        );
    } else {
      return
        DecayCurves.exponential(
          lock.lockDuration,
          lock.tokenAmount,
          elapsedIntervals,
          decayCurveParameters
        );
    }
  }

  /**
   * @notice Permit initializing the contract exactly once
   */
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

  /**
   * @notice Proposes a new initiative
   *
   * @param title Title of the initiative
   * @param body Body of the initiative
   */
  function proposeInitiative(
    string memory title,
    string memory body
  ) external hasSufficientTokens(proposalThreshold) hasValidInput(title, body) {
    _addInitiative(title, body);
  }

  /**
   * @notice Proposes a new initiative with locked tokens
   *
   * @param title Title of the initiative
   * @param body Body of the initiative
   * @param amount Amount of tokens to lock
   * @param lockDuration Duration for which tokens are locked (in intervals)
   */
  function proposeInitiativeWithLock(
    string memory title,
    string memory body,
    uint256 amount,
    uint256 lockDuration
  )
    external
    hasSufficientTokens(proposalThreshold)
    hasSufficientTokens(amount)
    hasValidInput(title, body)
  {
    uint256 id = _addInitiative(title, body);
    _addLock(id, msg.sender, amount, lockDuration);
  }

  /**
   * @notice Allows a user to support an existing initiative with locked tokens
   *
   * @param initiativeId ID of the initiative to support
   * @param amount Amount of tokens to lock
   * @param lockDuration Duration for which tokens are locked (in intervals)
   */
  function supportInitiative(
    uint256 initiativeId,
    uint256 amount,
    uint256 lockDuration
  ) external exists(initiativeId) {
    _addLock(initiativeId, msg.sender, amount, lockDuration);
  }

  function acceptInitiative(uint256 initiativeId) external payable exists(initiativeId) onlyOwner {
    Initiative storage initiative = initiatives[initiativeId];
    if (initiative.state != InitiativeState.Proposed)
      revert InvalidInitiativeState('Initiative is not in Proposed state');

    initiative.state = InitiativeState.Accepted;

    // Notify the Incentives contract
    // TODO: Reconsider tradeoffs of this design pattern properly
    if (address(incentives) != address(0)) {
      incentives.handleInitiativeAccepted(initiativeId);
    }

    emit InitiativeAccepted(initiativeId, msg.sender);
  }

  function expireInitiative(uint256 initiativeId) external payable exists(initiativeId) onlyOwner {
    Initiative storage initiative = initiatives[initiativeId];
    if (initiative.state != InitiativeState.Proposed)
      revert InvalidInitiativeState('Initiative is not in Proposed state');
    if (block.timestamp <= initiative.lastActivity + activityTimeout)
      revert InvalidInitiativeState('Initiative not yet eligible for expiration');

    initiative.state = InitiativeState.Expired;

    // Notify the Incentives contract
    // TODO: Reconsider tradeoffs of this design pattern properly
    if (address(incentives) != address(0)) {
      incentives.handleInitiativeExpired(initiativeId);
    }

    emit InitiativeExpired(initiativeId, msg.sender);
  }

  function withdrawTokens(uint256 tokenId) public nonReentrant {
    require(ownerOf(tokenId) == msg.sender, 'Not token owner');
    LockInfo storage lock = locks[tokenId];
    require(!lock.withdrawn, 'Already withdrawn');

    Initiative storage initiative = initiatives[lock.initiativeId];
    require(
      initiative.state == InitiativeState.Accepted || initiative.state == InitiativeState.Expired,
      'Initiative not withdrawable'
    );

    lock.withdrawn = true;
    _burn(tokenId);

    if (!IERC20(underlyingToken).transfer(msg.sender, lock.tokenAmount))
      revert TokenTransferFailed();

    emit TokensWithdrawn(lock.initiativeId, msg.sender, lock.tokenAmount);
  }

  function withdrawAllTokens() external nonReentrant {
    uint256[] memory tokenIds = supporterLocks[msg.sender];
    uint256 totalToWithdraw = 0;

    for (uint256 i = 0; i < tokenIds.length; i++) {
      uint256 tokenId = tokenIds[i];
      if (ownerOf(tokenId) == msg.sender && !locks[tokenId].withdrawn) {
        LockInfo storage lock = locks[tokenId];
        if (
          initiatives[lock.initiativeId].state == InitiativeState.Accepted ||
          initiatives[lock.initiativeId].state == InitiativeState.Expired
        ) {
          totalToWithdraw += lock.tokenAmount;
          lock.withdrawn = true;
          _burn(tokenId);
        }
      }
    }

    if (totalToWithdraw == 0) revert NothingToWithdraw();
    if (!IERC20(underlyingToken).transfer(msg.sender, totalToWithdraw))
      revert TokenTransferFailed();
  }

  /**
   * @notice Returns details about the specified initiative
   *
   * @param initiativeId The initiative to return
   */
  function getInitiative(
    uint256 initiativeId
  ) external view exists(initiativeId) returns (Initiative memory) {
    return initiatives[initiativeId];
  }

  /**
   * @notice Returns a list of addresses which have supported this initiative
   *
   * @param initiativeId The initiative to return supporters for
   */
  function getSupporters(
    uint256 initiativeId
  ) external view exists(initiativeId) returns (address[] memory) {
    return supporters[initiativeId];
  }

  /**
   * @notice Returns the current, real-time weight of the specified initiative
   *
   * @param initiativeId The initiative to return the weight for
   */
  function getWeight(uint256 initiativeId) external view exists(initiativeId) returns (uint256) {
    uint256 totalCurrentWeight = 0;
    address[] memory _supporters = supporters[initiativeId];

    for (uint256 i = 0; i < _supporters.length; i++) {
      address supporter = _supporters[i];
      uint256 lockCount = supporterLocks[supporter].length;
      for (uint256 j = 0; j < lockCount; j++) {
        uint256 currentWeight = _calculateLockWeightAt(
          locks[supporterLocks[supporter][j]],
          block.timestamp
        );
        totalCurrentWeight += currentWeight;
      }
    }

    return totalCurrentWeight;
  }

  /**
   * @notice Returns the weight the initiative did/will have at a specific timestamp
   *
   * @param initiativeId The initiative to return
   * @param timestamp The timestamp to calculate the weight for
   */
  function getWeightAt(
    uint256 initiativeId,
    uint256 timestamp
  ) external view exists(initiativeId) returns (uint256) {
    return _calculateWeightAt(initiativeId, timestamp);
  }

  /**
   * @notice Returns the weight a supporter has provided/is providing for the specified initiative at a specific timestamp
   *
   * @param initiativeId The initiative to return the weight for
   * @param supporter The supporter to return the weight for
   */
  function getWeightForSupporterAt(
    uint256 initiativeId,
    address supporter,
    uint256 timestamp
  ) external view exists(initiativeId) returns (uint256) {
    return _calculateWeightForSupporterAt(initiativeId, supporter, timestamp);
  }

  /**
   * @notice Returns the address of the token being used for lockups
   */
  function token() external view returns (address) {
    return underlyingToken;
  }

  /**
   * @notice Returns the total number of initiatives
   */
  function totalInitiatives() external view returns (uint256) {
    return initiativeCount;
  }

  /**
   * @notice Returns the total number of supporters for the specified initiative
   *
   * @param initiativeId The initiative to return the number of supporters for
   */
  function totalSupporters(uint256 initiativeId) external view returns (uint256) {
    return supporters[initiativeId].length;
  }

  /**
   * @notice Allows the owner to update the inactivity threshold
   *
   * @param _newThreshold New inactivity threshold in seconds
   */
  function setInactivityThreshold(uint256 _newThreshold) external onlyOwner {
    activityTimeout = _newThreshold;
  }

  /**
   * @notice Allows the owner to update the decay curve type and parameters
   *
   * @param _decayCurveType New curve type (0 = linear, 1 = exponential)
   * @param _decayCurveParameters New curve parameters
   */
  function setDecayCurve(
    uint256 _decayCurveType,
    uint256[] calldata _decayCurveParameters
  ) external onlyOwner {
    require(_decayCurveType < 2, 'Invalid decayCurveType');
    if (_decayCurveType == 0) {
      require(_decayCurveParameters.length == 1, 'Invalid decayCurveParameters');
    } else if (_decayCurveType == 1) {
      require(_decayCurveParameters.length == 1, 'Invalid decayCurveParameters');
    }

    decayCurveType = _decayCurveType;
    decayCurveParameters = _decayCurveParameters;
    emit DecayCurveUpdated(_decayCurveType, _decayCurveParameters);
  }

  /// @notice (Optional) Allows the owner to set the Incentives contract
  function setIncentives(address _incentives) external onlyOwner {
    incentives = Incentives(_incentives);
  }

  // TODO: EIP-1153: Transient Storage
  function getPositionsForInitiative(
    uint256 initiativeId
  ) external view returns (uint256[] memory) {
    return initiativeLocks[initiativeId];
  }

  function getLockCountForSupporter(address supporter) public view returns (uint256) {
    return supporterLocks[supporter].length;
  }

  function getLocksForSupporter(address supporter) public view returns (uint256[] memory) {
    return supporterLocks[supporter];
  }
}
