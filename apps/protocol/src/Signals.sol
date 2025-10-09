// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

import "solady/src/utils/ReentrancyGuard.sol";

import {ISignalsLock} from "./interfaces/ISignalsLock.sol";
import {ISignals} from "./interfaces/ISignals.sol";
import {IBounties} from "./interfaces/IBounties.sol";
import {IIncentivesPool} from "./interfaces/IIncentivesPool.sol";

import "./DecayCurves.sol";
import "./Bounties.sol";

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
contract Signals is ISignals, ERC721Enumerable, Ownable, ReentrancyGuard {
    /// @notice Weight required for an initiative to be accepted
    uint256 public acceptanceThreshold;

    /// @notice Maximum time we can lock tokens for denominated in intervals
    uint256 public maxLockIntervals;

    /// @notice Maximum number of proposals allowed
    uint256 public proposalCap;

    /// @notice Vanity title for the Board. eg. "Season 1: The Great Reset"
    string public title;

    /// @notice The version of the Signals contract
    string public version;

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

    /// @notice Configuration for proposer requirements (immutable after initialization)
    ProposerRequirements public proposerRequirements;

    /// @notice Configuration for participant requirements (immutable after initialization)
    ParticipantRequirements public participantRequirements;

    /// @notice Duration tokens remain locked after acceptance (0 = immediate release)
    uint256 public releaseLockDuration;

    /// @notice Timestamp when board opens for participation (0 = open immediately)
    uint256 public boardOpensAt;

    /// @notice Configuration for board-wide incentive rewards (internal storage)
    BoardIncentives internal _boardIncentives;

    /// @notice Current state of the board (Open or Closed)
    BoardState public boardState;

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

    /// @notice Track locked tokens with NFTs
    uint256 public nextTokenId = 1;

    /// @notice Add back the initiative counter
    uint256 public initiativeCount = 0;

    /// @notice Do we event need this? It would revert if the initiativeId is out of bounds
    modifier exists(uint256 initiativeId) {
        if (initiativeId > initiativeCount) revert ISignals.InitiativeNotFound();
        _;
    }

    modifier isNotInitialized() {
        require(acceptanceThreshold == 0, "Already initialized");
        _;
    }

    modifier isOpen() {
        if (block.timestamp < boardOpensAt) revert ISignals.BoardNotYetOpen();
        if (boardState == BoardState.Closed) revert ISignals.BoardClosedError();
        _;
    }

    modifier hasSufficientTokens(uint256 amount) {
        if (IERC20(underlyingToken).balanceOf(msg.sender) < amount) revert ISignals.InsufficientTokens();
        _;
    }

    modifier hasValidInput(string memory _title, string memory _body) {
        if (bytes(_title).length == 0 || bytes(_body).length == 0) {
            revert ISignals.InvalidInput("Title or body cannot be empty");
        }
        _;
    }

    /// @notice Modifier to check if caller is eligible to propose
    modifier isEligibleProposer() {
        ProposerRequirements memory reqs = proposerRequirements;

        if (reqs.eligibilityType == EligibilityType.None) {
            _;
            return;
        }

        if (reqs.eligibilityType == EligibilityType.MinBalance) {
            uint256 balance = IERC20(underlyingToken).balanceOf(msg.sender);
            if (balance < reqs.minBalance) {
                revert ProposerRequirementsNotMet("Insufficient token balance for proposal");
            }
            _;
            return;
        }

        if (reqs.eligibilityType == EligibilityType.MinBalanceAndDuration) {
            uint256 balance = IERC20(underlyingToken).balanceOf(msg.sender);
            if (balance < reqs.minBalance) {
                revert ProposerRequirementsNotMet("Insufficient token balance for proposal");
            }

            // Check holding duration (requires governance token with checkpoints)
            try IVotes(underlyingToken).getPastVotes(msg.sender, block.number - reqs.minHoldingDuration)
                returns (uint256 pastBalance) {
                if (pastBalance < reqs.minBalance) {
                    revert ProposerRequirementsNotMet("Tokens not held long enough");
                }
            } catch {
                revert ProposerRequirementsNotMet("Token does not support holding duration checks");
            }
            _;
            return;
        }
    }

    /// @notice Modifier to check participant requirements
    modifier meetsParticipantRequirements() {
        ParticipantRequirements memory reqs = participantRequirements;

        if (reqs.eligibilityType == EligibilityType.None) {
            _;
            return;
        }

        if (reqs.eligibilityType == EligibilityType.MinBalance) {
            uint256 balance = IERC20(underlyingToken).balanceOf(msg.sender);
            if (balance < reqs.minBalance) {
                revert ParticipantRequirementsNotMet("Insufficient token balance to participate");
            }
            _;
            return;
        }

        if (reqs.eligibilityType == EligibilityType.MinBalanceAndDuration) {
            uint256 balance = IERC20(underlyingToken).balanceOf(msg.sender);
            if (balance < reqs.minBalance) {
                revert ParticipantRequirementsNotMet("Insufficient token balance to participate");
            }

            // Check holding duration (requires governance token with checkpoints)
            try IVotes(underlyingToken).getPastVotes(msg.sender, block.number - reqs.minHoldingDuration)
                returns (uint256 pastBalance) {
                if (pastBalance < reqs.minBalance) {
                    revert ParticipantRequirementsNotMet("Tokens not held long enough");
                }
            } catch {
                revert ParticipantRequirementsNotMet("Token does not support holding duration checks");
            }
            _;
            return;
        }
    }

    /// @notice (Optional) Reference to the Bounties contract (can only be set once)
    // TODO: Reconsider tradeoffs of this design pattern properly
    IBounties public bounties;

    /// @notice (Optional) Reference to the IncentivesPool contract (can be set before board opens)
    IIncentivesPool public incentivesPool;

    constructor() ERC721("", "") Ownable(msg.sender) {}

    function setTitle(string memory _title) external onlyOwner {
        title = _title;
    }

    function getTitle() external view returns (string memory) {
        return title;
    }

    function name() public view override returns (string memory) {
        return string(abi.encodePacked(IERC20Metadata(underlyingToken).name(), " Locked Support"));
    }

    function symbol() public view override returns (string memory) {
        return string(abi.encodePacked("sx", IERC20Metadata(underlyingToken).symbol()));
    }

    function tokenURI(uint256) public pure override returns (string memory) {
        return ""; // Return empty string for now
    }

    function _addInitiative(string memory _title, string memory _body)
        internal
        hasSufficientTokens(proposerRequirements.threshold)
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

    function _addLock(uint256 initiativeId, address supporter, uint256 amount, uint256 lockDuration)
        internal
        hasSufficientTokens(amount)
        returns (uint256 tokenId)
    {
        if (lockDuration == 0 || lockDuration > maxLockIntervals) {
            revert ISignals.InvalidInput("Invalid lock interval");
        }

        Initiative storage initiative = _initiatives[initiativeId];

        if (initiative.state != InitiativeState.Proposed) {
            revert ISignals.InvalidInitiativeState("Initiative is not in Proposed state");
        }

        if (!IERC20(underlyingToken).transferFrom(msg.sender, address(this), amount)) {
            revert ISignals.TokenTransferFailed();
        }

        tokenId = nextTokenId++;

        _safeMint(supporter, tokenId);

        _locks[tokenId] = TokenLock({
            initiativeId: initiativeId,
            tokenAmount: amount,
            lockDuration: lockDuration,
            created: block.timestamp,
            withdrawn: false
        });

        initiativeLocks[initiativeId].push(tokenId);
        supporterLocks[supporter].push(tokenId);

        // Update the initiative's underlying locked amount
        initiative.underlyingLocked += amount;

        // Update the initiative's last activity timestamp
        initiative.lastActivity = block.timestamp;

        // Inscribe the users support
        if (!isSupporter[initiativeId][supporter]) {
            supporters[initiativeId].push(supporter);
            isSupporter[initiativeId][supporter] = true;
        }

        emit InitiativeSupported(initiativeId, supporter, amount, lockDuration, tokenId);

        return tokenId;
    }

    function _calculateWeightAt(uint256 initiativeId, uint256 timestamp) internal view returns (uint256) {
        uint256[] memory tokenIds = initiativeLocks[initiativeId];
        uint256 weight = 0;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            TokenLock memory lock = _locks[tokenId];
            if (!lock.withdrawn) {
                weight += _calculateLockWeightAt(lock, timestamp);
            }
        }

        return weight;
    }

    function _calculateWeightForSupporterAt(uint256 initiativeId, address supporter, uint256 timestamp)
        internal
        view
        returns (uint256)
    {
        uint256[] memory tokenIds = supporterLocks[supporter];
        uint256 weight = 0;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            TokenLock memory lock = _locks[tokenId];
            if (lock.initiativeId == initiativeId && !lock.withdrawn) {
                weight += _calculateLockWeightAt(lock, timestamp);
            }
        }

        return weight;
    }

    function _calculateLockWeightAt(TokenLock memory lock, uint256 timestamp) internal view returns (uint256) {
        uint256 elapsedIntervals = (timestamp - lock.created) / lockInterval;
        if (elapsedIntervals >= lock.lockDuration || lock.withdrawn) {
            return 0;
        }

        require(decayCurveType < 2, "Invalid decayCurveType");
        if (decayCurveType == 0) {
            return DecayCurves.linear(lock.lockDuration, lock.tokenAmount, elapsedIntervals, decayCurveParameters);
        } else {
            return DecayCurves.exponential(lock.lockDuration, lock.tokenAmount, elapsedIntervals, decayCurveParameters);
        }
    }

    /**
     * @notice Permit initializing the contract exactly once
     */
    function initialize(ISignals.BoardConfig calldata config) external isNotInitialized {
        // Validate configuration parameters
        if (config.underlyingToken == address(0)) revert ISignals.InvalidInput("underlyingToken cannot be zero address");
        if (config.owner == address(0)) revert ISignals.InvalidInput("owner cannot be zero address");
        if (config.acceptanceThreshold == 0) revert ISignals.InvalidInput("acceptanceThreshold must be greater than 0");
        if (config.maxLockIntervals == 0) revert ISignals.InvalidInput("maxLockIntervals must be greater than 0");
        if (config.lockInterval == 0) revert ISignals.InvalidInput("lockInterval must be greater than 0");
        if (config.proposalCap == 0) revert ISignals.InvalidInput("proposalCap must be greater than 0");
        if (config.decayCurveType >= 2) revert ISignals.InvalidInput("decayCurveType must be 0 (linear) or 1 (exponential)");

        version = config.version;
        underlyingToken = config.underlyingToken;
        acceptanceThreshold = config.acceptanceThreshold;
        maxLockIntervals = config.maxLockIntervals;
        proposalCap = config.proposalCap;
        lockInterval = config.lockInterval;
        decayCurveType = config.decayCurveType;
        decayCurveParameters = config.decayCurveParameters;
        proposerRequirements = config.proposerRequirements;
        participantRequirements = config.participantRequirements;
        releaseLockDuration = config.releaseLockDuration;
        boardOpensAt = config.boardOpensAt;
        _boardIncentives = config.boardIncentives;
        boardState = BoardState.Open;

        // Validate requirements
        _validateProposerRequirements(config.proposerRequirements);
        _validateParticipantRequirements(config.participantRequirements);

        transferOwnership(config.owner);
    }

    /**
     * @notice Proposes a new initiative
     *
     * @param _title Title of the initiative
     * @param _body Body of the initiative
     */
    function proposeInitiative(string memory _title, string memory _body)
        external
        isOpen
        isEligibleProposer
        hasValidInput(_title, _body)
    {
        _addInitiative(_title, _body);
    }

    /**
     * @notice Proposes a new initiative with locked tokens
     *
     * @param _title Title of the initiative
     * @param _body Body of the initiative
     * @param _amount Amount of tokens to lock
     * @param _lockDuration Duration for which tokens are locked (in intervals)
     */
    function proposeInitiativeWithLock(
        string memory _title,
        string memory _body,
        uint256 _amount,
        uint256 _lockDuration
    )
        external
        isOpen
        isEligibleProposer
        hasValidInput(_title, _body)
        returns (uint256 tokenId)
    {
        uint256 id = _addInitiative(_title, _body);
        tokenId = _addLock(id, msg.sender, _amount, _lockDuration);
    }

    /**
     * @notice Allows a user to support an existing initiative with locked tokens
     *
     * @param initiativeId ID of the initiative to support
     * @param amount Amount of tokens to lock
     * @param lockDuration Duration for which tokens are locked (in intervals)
     */
    function supportInitiative(uint256 initiativeId, uint256 amount, uint256 lockDuration)
        external
        isOpen
        meetsParticipantRequirements
        exists(initiativeId)
        returns (uint256 tokenId)
    {
        tokenId = _addLock(initiativeId, msg.sender, amount, lockDuration);
    }

    function acceptInitiative(uint256 initiativeId) external payable exists(initiativeId) onlyOwner {
        Initiative storage initiative = _initiatives[initiativeId];
        if (initiative.state != InitiativeState.Proposed) {
            revert ISignals.InvalidInitiativeState("Initiative is not in Proposed state");
        }

        initiative.state = InitiativeState.Accepted;
        initiative.acceptanceTimestamp = block.timestamp;

        // Notify the Bounties contract
        // TODO: Reconsider tradeoffs of this design pattern properly
        if (address(bounties) != address(0)) {
            bounties.handleInitiativeAccepted(initiativeId);
        }

        // Calculate incentives if pool is configured (non-blocking)
        if (address(incentivesPool) != address(0)) {
            try incentivesPool.calculateIncentives(initiativeId, boardOpensAt, block.timestamp) {} catch {
                // Incentives calculation failed, but don't block acceptance
                // Silently continue - pool contract will emit events for monitoring
            }
        }

        emit InitiativeAccepted(initiativeId, msg.sender);
    }

    function expireInitiative(uint256 initiativeId) external payable exists(initiativeId) onlyOwner {
        Initiative storage initiative = _initiatives[initiativeId];
        if (initiative.state != InitiativeState.Proposed) {
            revert ISignals.InvalidInitiativeState("Initiative is not in Proposed state");
        }
        if (block.timestamp <= initiative.lastActivity + activityTimeout) {
            revert ISignals.InvalidInitiativeState("Initiative not yet eligible for expiration");
        }

        initiative.state = InitiativeState.Expired;

        // Notify the Bounties contract
        // TODO: Reconsider tradeoffs of this design pattern properly
        if (address(bounties) != address(0)) {
            bounties.handleInitiativeExpired(initiativeId);
        }

        emit InitiativeExpired(initiativeId, msg.sender);
    }

    function redeem(uint256 tokenId) public nonReentrant {
        require(!_locks[tokenId].withdrawn, ISignals.InvalidRedemption());
        require(ownerOf(tokenId) == msg.sender, "Not token owner");

        TokenLock storage lock = _locks[tokenId];

        Initiative storage initiative = _initiatives[lock.initiativeId];
        if (!(initiative.state == InitiativeState.Accepted || initiative.state == InitiativeState.Expired)) {
            revert ISignals.InvalidInitiativeState("Initiative not withdrawable");
        }

        // Check release timelock for accepted initiatives (unless board is closed)
        if (initiative.state == InitiativeState.Accepted && boardState != BoardState.Closed) {
            if (releaseLockDuration > 0) {
                uint256 releaseTime = initiative.acceptanceTimestamp + releaseLockDuration;
                if (block.timestamp < releaseTime) {
                    revert ISignals.InvalidInitiativeState("Tokens still locked after acceptance");
                }
            }
        }

        uint256 amount = lock.tokenAmount;
        lock.withdrawn = true;
        _burn(tokenId);

        // Transfer underlying tokens
        if (!IERC20(underlyingToken).transfer(msg.sender, amount)) revert ISignals.TokenTransferFailed();

        // Auto-claim incentives if pool is configured and initiative was accepted
        // Only claim if there are rewards to prevent revert on already-claimed or zero rewards
        if (address(incentivesPool) != address(0) && initiative.state == InitiativeState.Accepted) {
            uint256 pendingRewards = incentivesPool.getSupporterRewards(address(this), lock.initiativeId, msg.sender);
            if (pendingRewards > 0) {
                incentivesPool.claimRewards(address(this), lock.initiativeId, msg.sender);
            }
        }

        emit Redeemed(tokenId, msg.sender, amount);
    }

    function getLockData(uint256 tokenId) external view returns (ISignalsLock.LockData memory) {
        if (_locks[tokenId].initiativeId == 0) {
            revert ISignals.InvalidTokenId();
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

    function getUnderlyingToken() external view returns (address) {
        return underlyingToken;
    }

    // NOTE: This is not needed, as it is exactly the same as `signals.locks(tokenId)`
    function getTokenLock(uint256 tokenId) public view returns (TokenLock memory) {
        return _locks[tokenId];
    }

    /**
     * @notice Returns details about the specified initiative
     *
     * @param initiativeId The initiative to return
     */
    function getInitiative(uint256 initiativeId) external view exists(initiativeId) returns (Initiative memory) {
        return _initiatives[initiativeId];
    }

    /**
     * @notice Returns a list of addresses which have supported this initiative
     *
     * @param initiativeId The initiative to return supporters for
     */
    function getSupporters(uint256 initiativeId) external view exists(initiativeId) returns (address[] memory) {
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
                uint256 currentWeight = _calculateLockWeightAt(_locks[supporterLocks[supporter][j]], block.timestamp);
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
    function getWeightAt(uint256 initiativeId, uint256 timestamp)
        external
        view
        exists(initiativeId)
        returns (uint256)
    {
        return _calculateWeightAt(initiativeId, timestamp);
    }

    /**
     * @notice Returns the weight a supporter has provided/is providing for the specified initiative at a specific timestamp
     *
     * @param initiativeId The initiative to return the weight for
     * @param supporter The supporter to return the weight for
     */
    function getWeightForSupporterAt(uint256 initiativeId, address supporter, uint256 timestamp)
        external
        view
        exists(initiativeId)
        returns (uint256)
    {
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
    function setDecayCurve(uint256 _decayCurveType, uint256[] calldata _decayCurveParameters) external onlyOwner {
        require(_decayCurveType < 2, "Invalid decayCurveType");
        if (_decayCurveType == 0) {
            require(_decayCurveParameters.length == 1, "Invalid decayCurveParameters");
        } else if (_decayCurveType == 1) {
            require(_decayCurveParameters.length == 1, "Invalid decayCurveParameters");
        }

        decayCurveType = _decayCurveType;
        decayCurveParameters = _decayCurveParameters;
        emit DecayCurveUpdated(_decayCurveType, _decayCurveParameters);
    }

    /// @notice (Optional) Allows the owner to set the Bounties contract
    function setBounties(address _bounties) external onlyOwner {
        bounties = Bounties(_bounties);
    }

    /// @notice (Optional) Allows the owner to set the IncentivesPool contract
    /// @dev Can only be set before board opens to ensure fair configuration
    function setIncentivesPool(address _incentivesPool) external onlyOwner {
        if (block.timestamp >= boardOpensAt) {
            revert ISignals.BoardAlreadyOpened();
        }
        incentivesPool = IIncentivesPool(_incentivesPool);
    }

    /**
     * @notice Permanently closes the board, making all locks immediately withdrawable
     * @dev This is an irreversible action that should be used as an emergency exit or end-of-season cleanup
     */
    function closeBoard() external onlyOwner {
        if (boardState == BoardState.Closed) {
            revert ISignals.InvalidInitiativeState("Board already closed");
        }
        boardState = BoardState.Closed;
        emit BoardClosed(msg.sender);
    }

    // TODO: EIP-1153: Transient Storage?
    function getPositionsForInitiative(uint256 initiativeId) external view returns (uint256[] memory) {
        return initiativeLocks[initiativeId];
    }

    function getLockCountForSupporter(address supporter) public view returns (uint256) {
        return supporterLocks[supporter].length;
    }

    function getLocksForSupporter(address supporter) public view returns (uint256[] memory) {
        return supporterLocks[supporter];
    }

    /**
     * @notice Returns all token IDs owned by an address
     * @param owner The address to return the tokens for
     */
    function listPositions(address owner) public view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(owner);
        uint256[] memory tokens = new uint256[](tokenCount);

        for (uint256 i = 0; i < tokenCount; i++) {
            tokens[i] = tokenOfOwnerByIndex(owner, i);
        }

        return tokens;
    }

    /*//////////////////////////////////////////////////////////////
                    PROPOSAL REQUIREMENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get current proposal requirements
    function getProposerRequirements() external view returns (ProposerRequirements memory) {
        return proposerRequirements;
    }

    function getParticipantRequirements() external view returns (ParticipantRequirements memory) {
        return participantRequirements;
    }

    /// @notice Check if an address meets proposer requirements
    function canPropose(address proposer) public view returns (bool) {
        ProposerRequirements memory reqs = proposerRequirements;

        if (reqs.eligibilityType == EligibilityType.None) {
            return true;
        }

        if (reqs.eligibilityType == EligibilityType.MinBalance) {
            uint256 balance = IERC20(underlyingToken).balanceOf(proposer);
            return balance >= reqs.minBalance;
        }

        if (reqs.eligibilityType == EligibilityType.MinBalanceAndDuration) {
            uint256 balance = IERC20(underlyingToken).balanceOf(proposer);
            if (balance < reqs.minBalance) {
                return false;
            }

            // Try to check past balance (requires ERC20Votes)
            try IVotes(underlyingToken).getPastVotes(proposer, block.number - reqs.minHoldingDuration)
                returns (uint256 pastBalance) {
                return pastBalance >= reqs.minBalance;
            } catch {
                return false; // Token doesn't support checkpoints
            }
        }

        return false;
    }

    /// @notice Check if an address meets participant requirements
    function canParticipate(address participant) public view returns (bool) {
        ParticipantRequirements memory reqs = participantRequirements;

        if (reqs.eligibilityType == EligibilityType.None) {
            return true;
        }

        if (reqs.eligibilityType == EligibilityType.MinBalance) {
            uint256 balance = IERC20(underlyingToken).balanceOf(participant);
            return balance >= reqs.minBalance;
        }

        if (reqs.eligibilityType == EligibilityType.MinBalanceAndDuration) {
            uint256 balance = IERC20(underlyingToken).balanceOf(participant);
            if (balance < reqs.minBalance) {
                return false;
            }

            // Try to check past balance (requires ERC20Votes)
            try IVotes(underlyingToken).getPastVotes(participant, block.number - reqs.minHoldingDuration)
                returns (uint256 pastBalance) {
                return pastBalance >= reqs.minBalance;
            } catch {
                return false; // Token doesn't support checkpoints
            }
        }

        return false;
    }

    /// @notice Internal function to validate proposer requirements
    function _validateProposerRequirements(ProposerRequirements memory reqs) internal pure {
        // When eligibility type is None, threshold provides the only gate to proposing
        if (reqs.eligibilityType == EligibilityType.None) {
            if (reqs.threshold == 0) {
                revert ProposerRequirementsNotMet("Threshold must be greater than 0 when eligibility type is None");
            }
        }

        if (reqs.eligibilityType == EligibilityType.MinBalance) {
            if (reqs.minBalance == 0) {
                revert ProposerRequirementsNotMet("MinBalance must be greater than 0");
            }
        }

        if (reqs.eligibilityType == EligibilityType.MinBalanceAndDuration) {
            if (reqs.minBalance == 0) {
                revert ProposerRequirementsNotMet("MinBalance must be greater than 0");
            }
            if (reqs.minHoldingDuration == 0) {
                revert ProposerRequirementsNotMet("MinHoldingDuration must be greater than 0");
            }
        }
    }

    /// @notice Internal function to validate participant requirements
    function _validateParticipantRequirements(ParticipantRequirements memory reqs) internal pure {
        if (reqs.eligibilityType == EligibilityType.MinBalance) {
            if (reqs.minBalance == 0) {
                revert ParticipantRequirementsNotMet("MinBalance must be greater than 0");
            }
        }

        if (reqs.eligibilityType == EligibilityType.MinBalanceAndDuration) {
            if (reqs.minBalance == 0) {
                revert ParticipantRequirementsNotMet("MinBalance must be greater than 0");
            }
            if (reqs.minHoldingDuration == 0) {
                revert ParticipantRequirementsNotMet("MinHoldingDuration must be greater than 0");
            }
        }
    }

    /// @notice Get board incentives configuration
    /// @return Board incentives configuration
    function boardIncentives() external view returns (BoardIncentives memory) {
        return _boardIncentives;
    }
}

interface IVotes {
    function getPastVotes(address account, uint256 blockNumber) external view returns (uint256);
}
