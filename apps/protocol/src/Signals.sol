// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {SignalsAuthorizer} from "./Authorizer.sol";
import {SignalsIncentivizer} from "./Incentivizer.sol";
import "solady/src/utils/ReentrancyGuard.sol";

import {ISignalsLock} from "./interfaces/ISignalsLock.sol";
import {ISignals} from "./interfaces/ISignals.sol";
import {IBounties} from "./interfaces/IBounties.sol";
import {IIncentivesPool} from "./interfaces/IIncentivesPool.sol";

import "./DecayCurves.sol";
import "./Bounties.sol";
import {SignalsConstants} from "./utils/Constants.sol";

/**
 * @title Signals by Lighthouse Labs <https://lighthouse.cx>
 *
 * @notice Manage community initiatives with governance tokens
 * @notice Locked positions are represented by transferrable ERC721 tokens
 *         that can be traded and used to redeem the underlying tokens
 *         when the lock expires
 *
 * @author 1a35e1.eth <https://x.com/1a35e1>
 * @author jkm.eth <james@lighthouse.cx>
 */
contract Signals is
    ISignals,
    SignalsAuthorizer,
    SignalsIncentivizer,
    ERC721Enumerable,
    Ownable,
    ReentrancyGuard,
    Initializable
{
    using SafeERC20 for IERC20;
    /// @notice The version of the Signals contract

    string public version;

    /// @notice Vanity title for the Board. eg. "Season 1: The Great Reset"
    string public title;

    /// @notice The underlying ERC20 token used for locking
    address public underlyingToken;

    /**
     * @notice Interval used for lockup duration and calculating the decay curve
     *
     * Lockup durations are specified in the number of intervals, and the decay curve is also applied
     * per interval (e.g. interval of [1 day] means the weight of the lock would only be updated once per day
     */
    uint256 public lockInterval;

    /// @notice Maximum time we can lock tokens for denominated in intervals
    uint256 public maxLockIntervals;

    /// @notice Weight required for an initiative to be accepted
    uint256 public acceptanceThreshold;

    /// @notice Maximum number of proposals allowed
    uint256 public proposalCap;

    /// @notice Specifies which decay function to use. 0 = linear, 1 = exponential, more to come
    uint256 public decayCurveType;

    /// @notice Parameters for the decay curve (the requirements of which depend on which curve is chosen)
    uint256[] public decayCurveParameters;

    /// @notice Inactivity timeout after which an initiative can be expired (in seconds)
    uint256 public inactivityTimeout;

    /// @notice Duration tokens remain locked after acceptance (0 = immediate release)
    uint256 public releaseLockDuration;

    /// @notice Timestamp when board opens for participation
    uint256 public boardOpenAt;

    /// @notice Timestamp when board closed or will close for participation
    uint256 public boardClosedAt;

    /// @notice (initiativeId => Initiative)
    mapping(uint256 => Initiative) internal _initiatives;

    /// @notice Mapping from token ID to lock details
    mapping(uint256 => ISignals.TokenLock) internal _locks;

    /// @notice Mapping from initiative ID to array of token IDs
    mapping(uint256 => uint256[]) public initiativeLocks;

    /// @notice Mapping from supporter to their token IDs
    mapping(address => uint256[]) public supporterLocks;

    /// @notice (initiativeId => supporter[])
    mapping(uint256 => address[]) public supporters;

    /// @dev (initiativeId => (supporter => bool))
    // Shows which initiatives a supporter has pending withdrawals for
    mapping(uint256 => mapping(address => bool)) public isSupporter;

    /// @notice Number of lock positions created as NFTs
    uint256 public lockCount;

    /// @notice Initiative counter
    uint256 public initiativeCount;

    /// @notice (Optional) Reference to the Bounties contract (can only be set once)
    // TODO(@arnold): [MEDIUM] Evaluate coupling between Signals and Bounties contracts
    //                Consider event-driven pattern to reduce tight coupling
    //                See: Similar adapter pattern discussion in other modules
    IBounties public bounties;

    /// @notice Check to make sure the initiative exists
    modifier exists(uint256 initiativeId) {
        _exists(initiativeId);
        _;
    }

    function _exists(uint256 initiativeId) internal view {
        if (initiativeId > initiativeCount) revert ISignals.Signals_InitiativeNotFound();
    }

    modifier isOpen() {
        _isOpen();
        _;
    }

    function _isOpen() internal view {
        if (!isBoardOpen()) revert ISignals.Signals_BoardNotOpen();
    }

    modifier hasValidInput(string memory _title, string memory _body) {
        _hasValidInput(_title, _body);
        _;
    }

    function _hasValidInput(string memory _title, string memory _body) internal pure {
        if (bytes(_title).length == 0) revert ISignals.Signals_EmptyTitle();
        if (bytes(_body).length == 0) revert ISignals.Signals_EmptyBody();
    }

    constructor() ERC721("", "") Ownable(msg.sender) {}

    /// @inheritdoc ISignals
    function initialize(ISignals.BoardConfig calldata config) external initializer {
        // Validate configuration parameters
        if (config.underlyingToken == address(0)) revert ISignals.Signals_ZeroAddressToken();
        if (config.owner == address(0)) revert ISignals.Signals_ZeroAddressOwner();
        if (config.acceptanceThreshold == 0) revert ISignals.Signals_ZeroAcceptanceThreshold();
        if (config.maxLockIntervals == 0) revert ISignals.Signals_ZeroMaxLockIntervals();
        if (config.lockInterval == 0) revert ISignals.Signals_ZeroLockInterval();
        if (config.proposalCap == 0) revert ISignals.Signals_ZeroProposalCap();
        if (config.decayCurveType >= SignalsConstants.MAX_DECAY_CURVE_TYPES) {
            revert ISignals.Signals_InvalidDecayCurveType();
        }

        if (config.boardOpenAt == 0) {
            boardOpenAt = type(uint256).max;
        } else if (config.boardOpenAt < block.timestamp) {
            revert ISignals.Signals_InvalidBoardOpenTime();
        } else {
            boardOpenAt = config.boardOpenAt;
        }

        if (config.boardClosedAt == 0) {
            boardClosedAt = type(uint256).max;
        } else if (config.boardClosedAt < config.boardOpenAt) {
            revert ISignals.Signals_InvalidBoardClosedTime();
        } else {
            boardClosedAt = config.boardClosedAt;
        }
        _validateParticipantRequirements(config.proposerRequirements);
        _validateParticipantRequirements(config.supporterRequirements);

        version = config.version;
        underlyingToken = config.underlyingToken;
        authorizationToken = config.underlyingToken;
        acceptanceThreshold = config.acceptanceThreshold;
        maxLockIntervals = config.maxLockIntervals;
        proposalCap = config.proposalCap;
        lockInterval = config.lockInterval;
        decayCurveType = config.decayCurveType;
        decayCurveParameters = config.decayCurveParameters;
        proposerRequirements = config.proposerRequirements;
        supporterRequirements = config.supporterRequirements;
        releaseLockDuration = config.releaseLockDuration;

        transferOwnership(config.owner);
    }

    /// @inheritdoc ISignals
    function proposeInitiative(string memory _title, string memory _body)
        external
        isOpen
        senderCanPropose(0)
        hasValidInput(_title, _body)
    {
        _addInitiative(_title, _body);
    }

    /// @inheritdoc ISignals
    function proposeInitiativeWithLock(
        string memory _title,
        string memory _body,
        uint256 _amount,
        uint256 _lockDuration
    )
        external
        isOpen
        senderCanPropose(_amount)
        hasValidInput(_title, _body)
        returns (uint256 tokenId)
    {
        uint256 id = _addInitiative(_title, _body);
        tokenId = _addLock(id, msg.sender, _amount, _lockDuration);
    }

    /**
     * @notice Internal function to create a new initiative
     * @dev Validates proposer has sufficient tokens based on threshold
     * @param _title Title of the initiative
     * @param _body Body content of the initiative
     * @return id The ID of the newly created initiative
     */
    function _addInitiative(string memory _title, string memory _body)
        internal
        returns (uint256 id)
    {
        Initiative memory newInitiative = Initiative({
            state: ISignals.InitiativeState.Proposed,
            title: _title,
            body: _body,
            proposer: msg.sender,
            timestamp: block.timestamp,
            lastActivity: block.timestamp,
            underlyingLocked: 0,
            acceptanceTimestamp: 0
        });

        // Increment first, so there is no initiative with an id of 0 (Following the pattern of ERC20 and 721)
        initiativeCount++;
        _initiatives[initiativeCount] = newInitiative;

        emit InitiativeProposed(initiativeCount, msg.sender, _title, _body);
        return initiativeCount;
    }

    /**
     * @notice Internal function to add a lock position to an initiative
     * @dev Creates NFT representing the lock, transfers tokens, and updates all tracking
     * @param initiativeId ID of the initiative to support
     * @param supporter Address receiving the lock NFT
     * @param amount Amount of tokens to lock
     * @param lockDuration Duration of the lock in intervals
     * @return tokenId The NFT token ID representing this lock position
     */
    function _addLock(uint256 initiativeId, address supporter, uint256 amount, uint256 lockDuration)
        internal
        returns (uint256 tokenId)
    {
        if (lockDuration == 0 || lockDuration > maxLockIntervals) {
            revert ISignals.Signals_InvalidLockDuration();
        }

        Initiative storage initiative = _initiatives[initiativeId];

        if (initiative.state != InitiativeState.Proposed) {
            revert ISignals.Signals_NotProposedState();
        }

        uint256 beforeBalance = IERC20(underlyingToken).balanceOf(address(this));
        IERC20(underlyingToken).safeTransferFrom(msg.sender, address(this), amount);
        uint256 afterBalance = IERC20(underlyingToken).balanceOf(address(this));

        if (afterBalance - beforeBalance != amount) {
            revert ISignals.Signals_TokenTransferFailed();
        }

        lockCount++;

        _safeMint(supporter, lockCount);

        _locks[lockCount] = TokenLock({
            initiativeId: initiativeId,
            tokenAmount: amount,
            lockDuration: lockDuration,
            created: block.timestamp,
            withdrawn: false
        });

        initiativeLocks[initiativeId].push(lockCount);
        supporterLocks[supporter].push(lockCount);

        // Update the initiative's underlying locked amount
        initiative.underlyingLocked += amount;

        // Update the initiative's last activity timestamp
        initiative.lastActivity = block.timestamp;

        // Record the user's support
        if (!isSupporter[initiativeId][supporter]) {
            supporters[initiativeId].push(supporter);
            isSupporter[initiativeId][supporter] = true;
        }

        // Record this lock's contribution for incentives
        // (Function will silently skip if we aren't using incentives)
        // NOTE: For now we are basing credit on weight at lock time. If we want to do something else,
        // this is where to change it.
        uint256 weight = _calculateLockWeightAt(_locks[lockCount], block.timestamp);
        _addIncentivesCreditForLock(initiativeId, lockCount, uint128(weight));

        emit InitiativeSupported(initiativeId, supporter, amount, lockDuration, lockCount);

        return lockCount;
    }

    /// @inheritdoc ISignals
    function supportInitiative(uint256 initiativeId, uint256 amount, uint256 lockDuration)
        external
        isOpen
        senderCanSupport(amount)
        exists(initiativeId)
        returns (uint256 tokenId)
    {
        tokenId = _addLock(initiativeId, msg.sender, amount, lockDuration);
    }

    /**
     * @notice Mark an initiative as accepted
     * @dev Only callable by owner. Notifies bounties and calculates incentives if configured.
     * @param initiativeId ID of the initiative to accept
     */
    function acceptInitiative(uint256 initiativeId)
        external
        payable
        exists(initiativeId)
        onlyOwner
    {
        Initiative storage initiative = _initiatives[initiativeId];

        // State transition: Proposed → Accepted
        // Can only accept initiatives in Proposed state (not already Accepted, Cancelled, or Expired)
        if (initiative.state != InitiativeState.Proposed) {
            revert ISignals.Signals_NotProposedState();
        }

        // Update state and record acceptance timestamp for release timelock calculation
        initiative.state = InitiativeState.Accepted;
        initiative.acceptanceTimestamp = block.timestamp;

        // Notify the Bounties contract to distribute bounty rewards if configured
        // This is optional - bounties may not be set for all boards
        // TODO(@arnold): [MEDIUM] Evaluate coupling between Signals and Bounties contracts
        //                Consider event-driven pattern to reduce tight coupling
        //                See: Similar adapter pattern discussion in other modules
        if (address(bounties) != address(0)) {
            bounties.handleInitiativeAccepted(initiativeId);
        }

        emit InitiativeAccepted(initiativeId, msg.sender);
    }

    /**
     * @notice Mark an inactive initiative as expired
     * @dev Only callable by owner after activityTimeout has passed. Notifies bounties if configured.
     * @param initiativeId ID of the initiative to expire
     */
    function expireInitiative(uint256 initiativeId)
        external
        payable
        exists(initiativeId)
        onlyOwner
    {
        Initiative storage initiative = _initiatives[initiativeId];

        // State transition: Proposed → Expired
        // Can only expire initiatives that are still in Proposed state
        if (initiative.state != InitiativeState.Proposed) {
            revert ISignals.Signals_NotProposedState();
        }

        // Verify initiative has been inactive for longer than inactivityTimeout
        // This prevents expiring initiatives that still have recent activity
        if (block.timestamp <= initiative.lastActivity + inactivityTimeout) {
            revert ISignals.Signals_NotEligibleForExpiration();
        }

        // Update state to Expired - allows supporters to redeem their locked tokens
        initiative.state = InitiativeState.Expired;

        // Notify the Bounties contract to handle refunds if configured
        // TODO(@arnold): [MEDIUM] Evaluate coupling between Signals and Bounties contracts
        //                Consider event-driven pattern to reduce tight coupling
        //                See: Similar adapter pattern discussion in other modules
        if (address(bounties) != address(0)) {
            bounties.handleInitiativeExpired(initiativeId);
        }

        emit InitiativeExpired(initiativeId, msg.sender);
    }

    function redeemLock(uint256 lockId) external nonReentrant {
        ISignals.TokenLock memory lock = _locks[lockId];
        uint256[] memory lockIds = new uint256[](1);
        lockIds[0] = lockId;
        redeemLocksForInitiative(lock.initiativeId, lockIds);
    }

    function redeemLocksForInitiative(uint256 initiativeId, uint256[] memory lockIds)
        public
        nonReentrant
    {
        Initiative memory initiative = _initiatives[initiativeId];

        // Can only redeem from Accepted or Expired initiatives
        if (
            initiative.state != InitiativeState.Accepted
                && initiative.state != InitiativeState.Expired
        ) {
            revert ISignals.Signals_NotWithdrawableState();
        }

        // If board is not closed and the initiative was accepted, enforce the release timelock
        if (initiative.state == InitiativeState.Accepted && !isBoardClosed()) {
            if (block.timestamp < initiative.acceptanceTimestamp + releaseLockDuration) {
                revert ISignals.Signals_StillTimelocked();
            }
        }

        uint256 redeemAmount = 0;

        for (uint256 i = 0; i < lockIds.length; i++) {
            uint256 lockId = lockIds[i];
            TokenLock storage lock = _locks[lockId];

            if (ownerOf(lockId) != msg.sender) revert ISignals.Signals_NotTokenOwner();

            if (lock.initiativeId != initiativeId) {
                revert ISignals.Signals_InvalidTokenId();
            }

            if (lock.withdrawn) {
                revert ISignals.Signals_AlreadyRedeemed();
            }

            redeemAmount += lock.tokenAmount;
            lock.withdrawn = true;
            _burn(lockId);

            emit Redeemed(initiativeId, lockId, msg.sender, lock.tokenAmount);
        }

        // Transfer underlying tokens back to the supporter
        if (!IERC20(underlyingToken).transfer(msg.sender, redeemAmount)) {
            revert ISignals.Signals_TokenTransferFailed();
        }
    }

    /**
     * @notice Set the board title
     * @param _title New title for the board
     */
    function setTitle(string memory _title) external onlyOwner {
        title = _title;
    }

    /// @inheritdoc ISignals
    function setDecayCurve(uint256 _decayCurveType, uint256[] calldata _decayCurveParameters)
        external
        onlyOwner
    {
        if (_decayCurveType >= SignalsConstants.MAX_DECAY_CURVE_TYPES) {
            revert ISignals.Signals_InvalidDecayCurveType();
        }
        if (_decayCurveParameters.length != SignalsConstants.DECAY_CURVE_PARAM_LENGTH) {
            revert ISignals.Signals_InvalidDecayCurveType();
        }

        decayCurveType = _decayCurveType;
        decayCurveParameters = _decayCurveParameters;
        emit DecayCurveUpdated(_decayCurveType, _decayCurveParameters);
    }

    /// @inheritdoc ISignals
    function setBounties(address _bounties) external onlyOwner {
        bounties = Bounties(_bounties);
    }

    /// @inheritdoc ISignals
    function setIncentivesPool(address incentivesPool_, IncentivesConfig calldata incentivesConfig_)
        external
        onlyOwner
    {
        if (isBoardOpen()) revert ISignals.Signals_BoardAlreadyOpened();
        _setIncentivesPool(incentivesPool_, incentivesConfig_);
    }

    /// @inheritdoc ISignals
    function setBoardOpenAt(uint256 _boardOpenAt) external onlyOwner {
        if (_boardOpenAt < block.timestamp) {
            revert ISignals.Signals_InvalidBoardOpenTime();
        }
        boardOpenAt = _boardOpenAt;
    }

    /// @inheritdoc ISignals
    function closeBoard() external isOpen onlyOwner {
        boardClosedAt = block.timestamp;
        emit BoardClosed(msg.sender);
    }

    /**
     * @notice Internal function to calculate total weight of an initiative at a specific time
     * @dev Iterates through all locks and sums their individual weights
     * @dev Gas optimizations:
     *      - Uses storage pointers instead of memory copies to avoid expensive MLOAD operations
     *      - Unchecked loop increment safe as array length can never overflow uint256
     *      - Early withdrawn check reduces unnecessary weight calculations
     * @param initiativeId ID of the initiative
     * @param timestamp Timestamp to calculate weight at
     * @return Total weight at the specified timestamp
     */
    function _calculateWeightAt(uint256 initiativeId, uint256 timestamp)
        internal
        view
        returns (uint256)
    {
        // Get all lock positions supporting this initiative
        uint256[] memory tokenIds = initiativeLocks[initiativeId];
        uint256 weight = 0;

        // Sum weights from all active (non-withdrawn) locks
        // Each lock's weight decays over time according to the configured decay curve
        for (uint256 i = 0; i < tokenIds.length;) {
            uint256 tokenId = tokenIds[i];

            // Direct storage access - only check withdrawn flag first (single SLOAD)
            // Only count locks that haven't been redeemed yet
            if (!_locks[tokenId].withdrawn) {
                // Pass storage pointer to avoid copying struct to memory
                weight += _calculateLockWeightAt(_locks[tokenId], timestamp);
            }

            // Unchecked increment: loop counter cannot realistically overflow uint256
            // Saves ~30-40 gas per iteration by skipping overflow checks
            unchecked {
                ++i;
            }
        }

        return weight;
    }

    /**
     * @notice Internal function to calculate a supporter's weight for an initiative at a specific time
     * @dev Iterates through supporter's locks and sums weights for the specified initiative
     * @dev Gas optimizations:
     *      - Uses storage pointers instead of memory copies to avoid expensive MLOAD operations
     *      - Unchecked loop increment safe as array length can never overflow uint256
     *      - Combined initiative and withdrawn checks reduce redundant storage reads
     * @param initiativeId ID of the initiative
     * @param supporter Address of the supporter
     * @param timestamp Timestamp to calculate weight at
     * @return Total weight contributed by supporter at the specified timestamp
     */
    function _calculateWeightForSupporterAt(
        uint256 initiativeId,
        address supporter,
        uint256 timestamp
    ) internal view returns (uint256) {
        // Get all locks owned by this supporter (across all initiatives)
        uint256[] memory tokenIds = supporterLocks[supporter];
        uint256 weight = 0;

        // Filter for locks supporting the specific initiative and sum their weights
        for (uint256 i = 0; i < tokenIds.length;) {
            uint256 tokenId = tokenIds[i];

            // Direct storage access - check initiative ID and withdrawn status
            // Only count locks for this specific initiative that haven't been redeemed
            if (_locks[tokenId].initiativeId == initiativeId && !_locks[tokenId].withdrawn) {
                // Pass storage pointer to avoid copying struct to memory
                weight += _calculateLockWeightAt(_locks[tokenId], timestamp);
            }

            // Unchecked increment: loop counter cannot realistically overflow uint256
            // Saves ~30-40 gas per iteration by skipping overflow checks
            unchecked {
                ++i;
            }
        }

        return weight;
    }

    /**
     * @notice Internal function to calculate the weight of a single lock at a specific time
     * @dev Applies decay curve based on elapsed intervals. Returns 0 if lock expired or withdrawn
     * @dev Gas optimization: Accepts storage pointer to avoid copying struct to memory
     *      - Saves ~200-300 gas per call by avoiding MLOAD operations
     *      - Storage reads (SLOAD) are more efficient when accessed directly
     * @param lock The lock position to calculate weight for (storage pointer)
     * @param timestamp Timestamp to calculate weight at
     * @return Weight of the lock at the specified timestamp
     */
    function _calculateLockWeightAt(TokenLock storage lock, uint256 timestamp)
        internal
        view
        returns (uint256)
    {
        // Calculate how many complete intervals have elapsed since lock creation
        // Example: If lockInterval = 1 day, and 2.5 days passed, elapsedIntervals = 2
        uint256 elapsedIntervals = (timestamp - lock.created) / lockInterval;

        // Lock has expired (duration passed) or already withdrawn - no weight
        if (elapsedIntervals >= lock.lockDuration || lock.withdrawn) {
            return 0;
        }

        // Validate the decay curve type is recognized
        if (decayCurveType >= SignalsConstants.MAX_DECAY_CURVE_TYPES) {
            revert ISignals.Signals_InvalidDecayCurveType();
        }

        // Apply the configured decay curve to calculate time-weighted value
        // Linear: weight decreases steadily over time
        // Exponential: weight decreases at an accelerating rate
        if (decayCurveType == SignalsConstants.DECAY_LINEAR) {
            return DecayCurves.linear(
                lock.lockDuration, lock.tokenAmount, elapsedIntervals, decayCurveParameters
            );
        } else {
            return DecayCurves.exponential(
                lock.lockDuration, lock.tokenAmount, elapsedIntervals, decayCurveParameters
            );
        }
    }

    /**
     * @notice Returns the ERC721 token name
     * @dev Combines underlying token name with "Locked Support"
     * @return Token name string
     */
    function name() public view override returns (string memory) {
        return string(abi.encodePacked(IERC20Metadata(underlyingToken).name(), " Locked Support"));
    }

    /**
     * @notice Returns the ERC721 token symbol
     * @dev Prefixes underlying token symbol with "sx"
     * @return Token symbol string
     */
    function symbol() public view override returns (string memory) {
        return string(abi.encodePacked("sx", IERC20Metadata(underlyingToken).symbol()));
    }

    /**
     * @notice Returns the token URI for metadata
     * @dev Currently returns empty string - can be implemented for on-chain or off-chain metadata
     * @return Empty string
     */
    function tokenURI(uint256) public pure override returns (string memory) {
        return ""; // Return empty string for now
    }

    /// @inheritdoc ISignals
    function getTokenLock(uint256 tokenId) public view returns (TokenLock memory) {
        return _locks[tokenId];
    }

    /**
     * @notice Get the number of lock positions a supporter has
     * @param supporter Address of the supporter
     * @return Number of locks
     */
    function getLockCountForSupporter(address supporter) public view returns (uint256) {
        return supporterLocks[supporter].length;
    }

    /// @inheritdoc ISignals
    function getLocksForSupporter(address supporter) public view returns (uint256[] memory) {
        return supporterLocks[supporter];
    }

    /// @inheritdoc ISignals
    function listPositions(address owner) public view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(owner);
        uint256[] memory tokens = new uint256[](tokenCount);

        // Gas optimization: unchecked increment safe as tokenCount bounded by array length
        for (uint256 i = 0; i < tokenCount;) {
            tokens[i] = tokenOfOwnerByIndex(owner, i);

            // Unchecked increment: loop counter cannot overflow uint256
            // Saves ~30-40 gas per iteration
            unchecked {
                ++i;
            }
        }

        return tokens;
    }

    /// @inheritdoc ISignalsLock
    function getLockData(uint256 tokenId) external view returns (ISignalsLock.LockData memory) {
        if (_locks[tokenId].initiativeId == 0) {
            revert ISignals.Signals_InvalidTokenId();
        }

        TokenLock memory lock = _locks[tokenId];

        return ISignalsLock.LockData({
            referenceId: lock.initiativeId,
            nominalValue: lock.tokenAmount,
            expires: lock.created + lock.lockDuration * lockInterval,
            created: lock.created,
            claimed: lock.withdrawn
        });
    }

    /// @inheritdoc ISignalsLock
    function getUnderlyingToken() external view returns (address) {
        return underlyingToken;
    }

    /// @inheritdoc ISignals
    function getInitiative(uint256 initiativeId)
        external
        view
        exists(initiativeId)
        returns (Initiative memory)
    {
        return _initiatives[initiativeId];
    }

    /// @inheritdoc ISignals
    function getSupporters(uint256 initiativeId)
        external
        view
        exists(initiativeId)
        returns (address[] memory)
    {
        return supporters[initiativeId];
    }

    /// @inheritdoc ISignals
    function getWeight(uint256 initiativeId) external view exists(initiativeId) returns (uint256) {
        return _calculateWeightAt(initiativeId, block.timestamp);
    }

    /// @inheritdoc ISignals
    function getWeightAt(uint256 initiativeId, uint256 timestamp)
        external
        view
        exists(initiativeId)
        returns (uint256)
    {
        return _calculateWeightAt(initiativeId, timestamp);
    }

    /// @inheritdoc ISignals
    function getWeightForSupporterAt(uint256 initiativeId, address supporter, uint256 timestamp)
        external
        view
        exists(initiativeId)
        returns (uint256)
    {
        return _calculateWeightForSupporterAt(initiativeId, supporter, timestamp);
    }

    /**
     * @notice Get the current board title
     * @return Current board title
     */
    function getTitle() external view returns (string memory) {
        return title;
    }

    /// @inheritdoc ISignals
    function token() external view returns (address) {
        return underlyingToken;
    }

    /// @inheritdoc ISignals
    function totalInitiatives() external view returns (uint256) {
        return initiativeCount;
    }

    /// @inheritdoc ISignals
    function totalSupporters(uint256 initiativeId) external view returns (uint256) {
        return supporters[initiativeId].length;
    }

    /// @inheritdoc ISignals
    function getPositionsForInitiative(uint256 initiativeId)
        external
        view
        returns (uint256[] memory)
    {
        return initiativeLocks[initiativeId];
    }

    function isBoardOpen() public view returns (bool) {
        return block.timestamp >= boardOpenAt && block.timestamp < boardClosedAt;
    }

    function isBoardClosed() public view returns (bool) {
        return block.timestamp >= boardClosedAt;
    }
}
