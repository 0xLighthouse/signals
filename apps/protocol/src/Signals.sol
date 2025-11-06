// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {SignalsAuthorizer} from "./Authorizer.sol";
import "solady/src/utils/ReentrancyGuard.sol";

import {ISignalsLock} from "./interfaces/ISignalsLock.sol";
import {ISignals} from "./interfaces/ISignals.sol";
import {IIncentivizer} from "./interfaces/IIncentivizer.sol";
import {IIncentivesPool} from "./interfaces/IIncentivesPool.sol";
import "./DecayCurves.sol";
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
    ERC721Enumerable,
    Ownable,
    ReentrancyGuard,
    Initializable
{
    using SafeERC20 for IERC20;

    /// @notice Maximum number of metadata attachments allowed per initiative
    uint256 internal constant MAX_ATTACHMENTS = 5;

    /// @notice The version of the Signals contract
    string public version;

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

    /// @notice Criteria for accepting an initiative
    AcceptanceCriteria internal _acceptanceCriteria;

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

    /// @notice If board was cancelled
    bool public boardCancelled;

    /// @notice (Optional) Reference to the IncentivesPool contract (can be set before board opens)
    IIncentivesPool public incentivesPool;

    /// @notice Configuration for board-wide incentive rewards (internal storage)
    IIncentivizer.IncentivesConfig internal _incentivesConfig;

    /// @notice (initiativeId => Initiative)
    mapping(uint256 => Initiative) internal _initiatives;

    /// @notice Mapping from token ID to lock details
    mapping(uint256 => ISignals.TokenLock) internal _locks;

    /// @notice Mapping from initiative ID to array of token IDs
    mapping(uint256 => uint256[]) internal _locksForInitiative;

    /// @notice Number of initiatives
    uint256 public initiativeCount;

    /// @notice Number of token lock NFTs
    uint256 public lockCount;

    /// @notice Check to make sure the initiative exists
    modifier initiativeMustExist(uint256 initiativeId) {
        if (initiativeId > initiativeCount) revert ISignals.Signals_InvalidID();
        _;
    }

    modifier boardMustBeOpen() {
        if (!isBoardOpen()) revert ISignals.Signals_IncorrectBoardState();
        _;
    }

    constructor() ERC721("", "") Ownable(msg.sender) {}

    /// @inheritdoc ISignals
    function initialize(ISignals.BoardConfig calldata config) external initializer {
        // Immutable parameters - TODO: Break out functions for things that can be updated
        if (config.underlyingToken == address(0)) revert ISignals.Signals_InvalidArguments();
        if (config.owner == address(0)) revert ISignals.Signals_InvalidArguments();
        if (config.maxLockIntervals == 0) revert ISignals.Signals_InvalidArguments();
        if (config.lockInterval == 0) revert ISignals.Signals_InvalidArguments();
        if (config.decayCurveType >= SignalsConstants.MAX_DECAY_CURVE_TYPES) {
            revert ISignals.Signals_InvalidArguments();
        }

        _setAcceptanceCriteria(config.acceptanceCriteria);

        if (config.boardOpenAt == 0) {
            boardOpenAt = type(uint256).max;
        } else if (config.boardOpenAt < block.timestamp) {
            boardOpenAt = block.timestamp;
        } else {
            boardOpenAt = config.boardOpenAt;
        }

        if (config.boardClosedAt == 0) {
            boardClosedAt = type(uint256).max;
        } else if (config.boardClosedAt < config.boardOpenAt) {
            revert ISignals.Signals_InvalidArguments();
        } else {
            boardClosedAt = config.boardClosedAt;
        }
        _validateParticipantRequirements(config.proposerRequirements);
        _validateParticipantRequirements(config.supporterRequirements);

        version = config.version;
        underlyingToken = config.underlyingToken;

        lockInterval = config.lockInterval;
        maxLockIntervals = config.maxLockIntervals;

        decayCurveType = config.decayCurveType;
        decayCurveParameters = config.decayCurveParameters;

        proposerRequirements = config.proposerRequirements;
        supporterRequirements = config.supporterRequirements;
        releaseLockDuration = config.releaseLockDuration;

        // Set which token the authorizer uses to check eligibility
        authorizationToken = config.underlyingToken;

        _transferOwnership(config.owner);
    }

    /// @inheritdoc ISignals
    function proposeInitiative(Metadata calldata _metadata)
        external
        boardMustBeOpen
        senderCanPropose(0)
        returns (uint256 initiativeId)
    {
        initiativeId = _addInitiative(_metadata);
    }

    /// @inheritdoc ISignals
    function proposeInitiativeWithLock(
        Metadata calldata _metadata,
        uint256 _amount,
        uint256 _lockDuration
    )
        external
        boardMustBeOpen
        senderCanPropose(_amount)
        returns (uint256 initiativeId, uint256 tokenId)
    {
        initiativeId = _addInitiative(_metadata);
        tokenId = _addLock(initiativeId, msg.sender, _amount, _lockDuration);
    }

    /**
     * @notice Internal function to create a new initiative
     * @dev Validates proposer has sufficient tokens based on threshold
     * @param _metadata Metadata for the initiative
     * @return id The ID of the newly created initiative
     */
    function _addInitiative(Metadata calldata _metadata) internal returns (uint256 id) {
        // Validate metadata
        _validateMetadata(_metadata);

        // Increment first, so there is no initiative with an id of 0 (Following the pattern of ERC20 and 721)
        initiativeCount++;
        Initiative storage initiative = _initiatives[initiativeCount];

        initiative.state = ISignals.InitiativeState.Proposed;
        initiative.proposer = msg.sender;
        initiative.timestamp = block.timestamp;
        initiative.lastActivity = block.timestamp;
        initiative.acceptanceTimestamp = 0;

        emit InitiativeProposed(initiativeCount, msg.sender, _metadata);
        return initiativeCount;
    }

    function _validateMetadata(Metadata calldata _metadata) internal pure {
        if (bytes(_metadata.title).length == 0) {
            // Empty body is okay for now
            revert ISignals.Signals_EmptyTitleOrBody();
        }

        if (_metadata.attachments.length > MAX_ATTACHMENTS) {
            revert ISignals.Signals_AttachmentLimitExceeded();
        }
        for (uint256 i = 0; i < _metadata.attachments.length; i++) {
            if (bytes(_metadata.attachments[i].uri).length == 0) {
                revert ISignals.Signals_InvalidArguments();
            }
        }
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
        if (lockDuration > maxLockIntervals) {
            revert ISignals.Signals_InvalidArguments();
        }

        Initiative storage initiative = _initiatives[initiativeId];

        if (initiative.state != InitiativeState.Proposed) {
            revert ISignals.Signals_IncorrectInitiativeState();
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
            supporter: supporter,
            tokenAmount: amount,
            lockDuration: lockDuration,
            created: block.timestamp,
            withdrawn: false
        });

        _locksForInitiative[initiativeId].push(lockCount);

        // Update the initiative's last activity timestamp
        initiative.lastActivity = block.timestamp;

        // Record this lock's contribution for incentives
        // (Function will silently skip if we aren't using incentives)
        // NOTE: For now we are basing credit on weight at lock time. If we want to do something else,
        // this is where to change it.
        if (address(incentivesPool) != address(0)) {
            uint256 weight = _calculateLockWeightAt(_locks[lockCount], block.timestamp);
            incentivesPool.addIncentivesCreditForLock(initiativeId, lockCount, uint128(weight));
        }

        emit InitiativeSupported(initiativeId, supporter, amount, lockDuration, lockCount);

        return lockCount;
    }

    /// @inheritdoc ISignals
    function supportInitiative(uint256 initiativeId, uint256 amount, uint256 lockDuration)
        external
        boardMustBeOpen
        senderCanSupport(amount)
        initiativeMustExist(initiativeId)
        returns (uint256 tokenId)
    {
        tokenId = _addLock(initiativeId, msg.sender, amount, lockDuration);
    }

    /**
     * @notice Mark an initiative as accepted
     * @param initiativeId ID of the initiative to accept
     */
    function acceptInitiative(uint256 initiativeId)
        external
        payable
        initiativeMustExist(initiativeId)
    {
        if (!_acceptanceCriteria.anyoneCanAccept) {
            // Inherited from Ownable
            _checkOwner();
        }

        if (_acceptanceCriteria.ownerMustFollowThreshold || msg.sender != owner()) {
            uint256 acceptanceThreshold = getAcceptanceThreshold();
            uint256 weight = _calculateWeightAt(initiativeId, block.timestamp);
            if (weight < acceptanceThreshold) {
                revert ISignals.Signals_InsufficientSupport();
            }
        }

        Initiative storage initiative = _initiatives[initiativeId];

        // State transition: Proposed → Accepted
        // Can only accept initiatives in Proposed state (not already Accepted, Cancelled, or Expired)
        if (initiative.state != InitiativeState.Proposed) {
            revert ISignals.Signals_IncorrectInitiativeState();
        }

        // Update state and record acceptance timestamp for release timelock calculation
        initiative.state = InitiativeState.Accepted;
        initiative.acceptanceTimestamp = block.timestamp;

        emit InitiativeAccepted(initiativeId, msg.sender);
    }

    /**
     * @notice Mark an inactive initiative as expired
     * @dev Only callable by owner after activityTimeout has passed.
     * @param initiativeId ID of the initiative to expire
     */
    function expireInitiative(uint256 initiativeId)
        external
        payable
        initiativeMustExist(initiativeId)
        onlyOwner
    {
        Initiative storage initiative = _initiatives[initiativeId];

        // State transition: Proposed → Expired
        // Can only expire initiatives that are still in Proposed state
        if (initiative.state != InitiativeState.Proposed) {
            revert ISignals.Signals_IncorrectInitiativeState();
        }

        // Verify initiative has been inactive for longer than inactivityTimeout
        // This prevents expiring initiatives that still have recent activity
        if (block.timestamp <= initiative.lastActivity + inactivityTimeout) {
            revert ISignals.Signals_IncorrectInitiativeState();
        }

        // Update state to Expired - allows supporters to redeem their locked tokens
        initiative.state = InitiativeState.Expired;

        emit InitiativeExpired(initiativeId, msg.sender);
    }

    function redeemLock(uint256 lockId) external nonReentrant {
        ISignals.TokenLock memory lock = _locks[lockId];
        uint256[] memory lockIds = new uint256[](1);
        lockIds[0] = lockId;
        redeemLocksForInitiative(lock.initiativeId, lockIds);
    }

    /**
     * @notice Redeem multiple locks for an initiative
     * @param initiativeId ID of the initiative to redeem locks for
     * @param lockIds Array of lock IDs to redeem
     * @dev Rules: If initiative is accepted, tokens can be redeemed after the release timelock.
     *       If initiative is expired or board is cancelled, tokens can be redeemed immediately.
     *       Otherwise, tokens can be redeemed after the timelock expires.
     *
     */
    function redeemLocksForInitiative(uint256 initiativeId, uint256[] memory lockIds)
        public
        nonReentrant
    {
        InitiativeState state = _initiatives[initiativeId].state;
        uint256 acceptanceTimestamp = _initiatives[initiativeId].acceptanceTimestamp;

        uint256 redeemAmount = 0;

        for (uint256 i = 0; i < lockIds.length; i++) {
            uint256 lockId = lockIds[i];
            TokenLock storage lock = _locks[lockId];

            // Check if owner
            if (ownerOf(lockId) != msg.sender) revert ISignals.Signals_NotOwner();

            // Check if lock belongs to the initiative
            if (lock.initiativeId != initiativeId) {
                revert ISignals.Signals_InvalidID();
            }

            // Check if lock has already been redeemed
            if (lock.withdrawn) {
                revert ISignals.Signals_TokenAlreadyRedeemed(lockId);
            }

            // We can redeem now if one of these is true:
            // 1. The board is cancelled
            // 2. The initiative is expired
            // 3. The lock has expired
            // 4. The initiative has been accepted and the release timelock has passed
            if (
                boardCancelled || state == InitiativeState.Expired
                    || lock.created + lock.lockDuration * lockInterval <= block.timestamp
                    || state == InitiativeState.Accepted
                        && acceptanceTimestamp + releaseLockDuration <= block.timestamp
            ) {
                redeemAmount += lock.tokenAmount;
                lock.withdrawn = true;
                _burn(lockId);

                emit Redeemed(initiativeId, lockId, msg.sender, lock.tokenAmount);
            }
        }

        // Transfer underlying tokens back to the supporter
        if (!IERC20(underlyingToken).transfer(msg.sender, redeemAmount)) {
            revert ISignals.Signals_TokenTransferFailed();
        }

        // Claim incentives if pool is configured
        if (address(incentivesPool) != address(0)) {
            incentivesPool.claimIncentivesForLocks(
                initiativeId, lockIds, msg.sender, _incentivesConfig
            );
        }
    }

    /// @inheritdoc ISignals
    function setDecayCurve(uint256 _decayCurveType, uint256[] calldata _decayCurveParameters)
        external
        onlyOwner
    {
        if (_decayCurveType >= SignalsConstants.MAX_DECAY_CURVE_TYPES) {
            revert ISignals.Signals_InvalidArguments();
        }
        if (_decayCurveParameters.length != SignalsConstants.DECAY_CURVE_PARAM_LENGTH) {
            revert ISignals.Signals_InvalidArguments();
        }

        decayCurveType = _decayCurveType;
        decayCurveParameters = _decayCurveParameters;
        emit DecayCurveUpdated(_decayCurveType, _decayCurveParameters);
    }

    /// @inheritdoc ISignals
    function setIncentivesPool(
        address incentivesPool_,
        IIncentivizer.IncentivesConfig calldata incentivesConfig_
    ) external onlyOwner {
        if (isBoardOpen()) revert ISignals.Signals_IncorrectBoardState();

        if (address(incentivesPool_) == address(0)) {
            revert ISignals.Signals_InvalidArguments();
        }
        if (address(incentivesPool) != address(0)) {
            revert ISignals.Signals_IncentivesPoolAlreadySet();
        }

        if (!IIncentivesPool(incentivesPool_).isBoardApproved(address(this))) {
            revert ISignals.Signals_IncentivesPoolNotApproved();
        }
        incentivesPool = IIncentivesPool(incentivesPool_);

        if (incentivesConfig_.incentiveType == IIncentivizer.IncentiveType.Linear) {
            if (
                incentivesConfig_.incentiveParametersWAD.length < 2
                    || incentivesConfig_.incentiveParametersWAD.length > 24
            ) {
                revert ISignals.Signals_InvalidArguments();
            }
        }
        _incentivesConfig = incentivesConfig_;
    }

    function setAcceptanceCriteria(AcceptanceCriteria calldata acceptanceCriteria)
        external
        onlyOwner
    {
        _setAcceptanceCriteria(acceptanceCriteria);
    }

    function _setAcceptanceCriteria(AcceptanceCriteria calldata acceptanceCriteria) internal {
        if (
            acceptanceCriteria.percentageThresholdWAD == 0 && acceptanceCriteria.fixedThreshold == 0
        ) {
            revert ISignals.Signals_InvalidArguments();
        }
        if (acceptanceCriteria.percentageThresholdWAD >= 1 ether) {
            revert ISignals.Signals_InvalidArguments();
        }
        _acceptanceCriteria = acceptanceCriteria;
    }

    /// @inheritdoc ISignals
    function setBoardOpenAt(uint256 _boardOpenAt) external onlyOwner {
        if (isBoardClosed()) revert ISignals.Signals_IncorrectBoardState();
        _boardOpenAt < block.timestamp ? boardOpenAt = block.timestamp : boardOpenAt = _boardOpenAt;
    }

    /// @inheritdoc ISignals
    function setBoardClosedAt(uint256 _boardClosedAt) external boardMustBeOpen onlyOwner {
        if (_boardClosedAt < block.timestamp || _boardClosedAt < boardOpenAt) {
            revert ISignals.Signals_InvalidArguments();
        }
        boardClosedAt = _boardClosedAt;
    }

    function closeBoard() external boardMustBeOpen onlyOwner {
        boardClosedAt = block.timestamp;
        emit BoardClosed(msg.sender);
    }

    function cancelBoard() external boardMustBeOpen onlyOwner {
        boardClosedAt = block.timestamp;
        boardCancelled = true;
        emit BoardCancelled(msg.sender);
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
        uint256[] memory tokenIds = _locksForInitiative[initiativeId];
        uint256 weight = 0;

        // Sum weights from all active (non-withdrawn) locks
        for (uint256 i = 0; i < tokenIds.length;) {
            TokenLock memory lock = _locks[tokenIds[i]];

            // Only count locks that haven't been redeemed yet
            if (!lock.withdrawn) {
                weight += _calculateLockWeightAt(lock, timestamp);
            }

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
        // Get all locks for this initiative
        uint256[] memory tokenIds = _locksForInitiative[initiativeId];
        uint256 weight = 0;

        // Filter for locks supporting the specific initiative and sum their weights
        for (uint256 i = 0; i < tokenIds.length;) {
            ISignals.TokenLock memory lock = _locks[tokenIds[i]];

            // Only count locks for this specific initiative that haven't been redeemed
            if (lock.initiativeId == initiativeId && lock.supporter == supporter && !lock.withdrawn)
            {
                weight += _calculateLockWeightAt(lock, timestamp);
            }

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
    function _calculateLockWeightAt(TokenLock memory lock, uint256 timestamp)
        internal
        view
        returns (uint256)
    {
        // Calculate how many complete intervals have elapsed since lock creation
        // Example: If lockInterval = 1 day, and 2.5 days passed, elapsedIntervals = 2
        uint256 elapsedIntervals = (timestamp - lock.created) / lockInterval;

        // Lock has expired (duration passed) or already withdrawn - no weight
        if (lock.withdrawn) {
            return 0;
        }

        // At minimum, we provide support equal to the tokens locked
        if (elapsedIntervals >= lock.lockDuration) {
            return lock.tokenAmount;
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

    function locksForInitiative(uint256 initiativeId) public view returns (uint256[] memory) {
        return _locksForInitiative[initiativeId];
    }

    /// @inheritdoc ISignalsLock
    function getLockData(uint256 tokenId) external view returns (ISignalsLock.LockData memory) {
        if (_locks[tokenId].initiativeId == 0) {
            revert ISignals.Signals_InvalidID();
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

    function getAcceptanceCriteria() external view returns (AcceptanceCriteria memory) {
        return _acceptanceCriteria;
    }

    function getAcceptanceThreshold() public view returns (uint256) {
        if (_acceptanceCriteria.percentageThresholdWAD == 0) {
            return _acceptanceCriteria.fixedThreshold;
        }

        uint256 percentThreshold = IERC20(underlyingToken).totalSupply()
            * _acceptanceCriteria.percentageThresholdWAD / 1 ether;
        return percentThreshold > _acceptanceCriteria.fixedThreshold
            ? percentThreshold
            : _acceptanceCriteria.fixedThreshold;
    }

    /// @inheritdoc ISignals
    function getInitiative(uint256 initiativeId)
        external
        view
        initiativeMustExist(initiativeId)
        returns (Initiative memory)
    {
        return _initiatives[initiativeId];
    }

    /// @inheritdoc ISignals
    function getWeight(uint256 initiativeId)
        external
        view
        initiativeMustExist(initiativeId)
        returns (uint256)
    {
        return _calculateWeightAt(initiativeId, block.timestamp);
    }

    /// @inheritdoc ISignals
    function getWeightAt(uint256 initiativeId, uint256 timestamp)
        external
        view
        initiativeMustExist(initiativeId)
        returns (uint256)
    {
        return _calculateWeightAt(initiativeId, timestamp);
    }

    /// @inheritdoc ISignals
    function getWeightForSupporterAt(uint256 initiativeId, address supporter, uint256 timestamp)
        external
        view
        initiativeMustExist(initiativeId)
        returns (uint256)
    {
        return _calculateWeightForSupporterAt(initiativeId, supporter, timestamp);
    }

    function isBoardOpen() public view returns (bool) {
        return block.timestamp >= boardOpenAt && block.timestamp < boardClosedAt;
    }

    function isBoardClosed() public view returns (bool) {
        return block.timestamp >= boardClosedAt;
    }
}
