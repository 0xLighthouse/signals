// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {ISignalsLock} from "./ISignalsLock.sol";

import {IAuthorizer} from "./IAuthorizer.sol";
import {IIncentivizer} from "./IIncentivizer.sol";

interface ISignals is IERC721Enumerable, ISignalsLock, IAuthorizer, IIncentivizer {
    /**
     * @notice All configuration parameters for initializing the Signals contract
     *
     * @param owner The address which will own the contract
     * @param underlyingToken The address of the underlying ERC20 token
     * @param version The version of the Signals contract
     * @param acceptanceThreshold Weight required for an initiative to be accepted
     * @param maxLockIntervals Maximum lock intervals allowed
     * @param proposalCap The maximum active proposals a user can submit
     * TODO(@arnold): [LOW] Verify proposalCap behavior and rename to activeProposalLimit
     *                Field name should clearly indicate it limits concurrent active proposals
     * @param lockInterval Time interval for lockup duration and decay calculations
     * @param decayCurveType Which decay curve to use (e.g., 0 = linear, 1 = exponential)
     * @param decayCurveParameters Parameters to control the decay curve behavior
     * @param proposerRequirements Requirements for who can propose (immutable)
     * @param participantRequirements Requirements for who can support initiatives (immutable)
     * @param releaseLockDuration Duration tokens remain locked after acceptance (0 = immediate release)
     * @param boardOpenAt Timestamp when board opens for participation (0 = doesn't open until updated)
     * @param boardClosedAt Timestamp when board closes for participation (0 = never closes)
     */
    struct BoardConfig {
        string version;
        address owner;
        address underlyingToken;
        uint256 acceptanceThreshold;
        uint256 maxLockIntervals;
        uint256 proposalCap;
        uint256 lockInterval;
        uint256 decayCurveType;
        uint256[] decayCurveParameters;
        uint256 inactivityTimeout;
        IAuthorizer.ParticipantRequirements proposerRequirements;
        IAuthorizer.ParticipantRequirements supporterRequirements;
        uint256 releaseLockDuration;
        uint256 boardOpenAt;
        uint256 boardClosedAt;
    }

    /**
     * @notice Represents an initiative in the Signals contract
     * @dev Stores all relevant information about a single initiative
     *
     * @param title The title of the initiative
     * @param body The detailed body of the initiative in markdown format
     * @param attachments Optional metadata attachments associated with the initiative
     * @param state The current state of the initiative
     * @param proposer The address of the account that proposed this initiative
     * @param timestamp The timestamp when the initiative was created
     * @param lastActivity Used to determine if an initiative has become inactive and can be expired
     * @param acceptanceTimestamp The timestamp when the initiative was accepted (0 if not accepted)
     */
    struct Initiative {
        string title;
        string body;
        Attachment[] attachments;
        InitiativeState state;
        address proposer;
        uint256 timestamp;
        uint256 lastActivity;
        uint256 underlyingLocked;
        uint256 acceptanceTimestamp;
    }

    /**
     * @notice Details for each lockup
     *
     * @param initiativeId ID of the initiative
     * @param tokenAmount Amount of tokens locked
     * @param lockDuration Total duration of the lock in intervals
     * @param created Timestamp of when the lock was created
     * @param withdrawn Flag indicating whether the locked tokens have been withdrawn
     */
    struct TokenLock {
        uint256 initiativeId;
        uint256 tokenAmount;
        uint256 lockDuration;
        uint256 created;
        bool withdrawn;
    }

    /**
     * @notice Optional metadata attachment associated with an initiative
     */
    struct Attachment {
        string uri;
        string mimeType;
        string description;
    }

    // Enums
    enum InitiativeState {
        Proposed,
        Accepted,
        Cancelled,
        Expired
    }

    /**
     * @notice Event emitted when a supporter supports an initiative
     *
     * @param initiativeId ID of the initiative
     * @param supporter Address of the supporter // FIXME: Consider renameing to originalSupporter ??
     * @param tokenAmount Amount of tokens locked
     * @param lockDuration Duration for which tokens are locked (in intervals)
     * @param tokenId ID of the NFT issued
     */
    event InitiativeSupported(
        uint256 indexed initiativeId,
        address indexed supporter,
        uint256 tokenAmount,
        uint256 lockDuration,
        uint256 tokenId
    );
    event InitiativeProposed(
        uint256 indexed initiativeId,
        address indexed proposer,
        string title,
        string body,
        Attachment[] attachments
    );
    event InitiativeAccepted(uint256 indexed initiativeId, address indexed actor);
    event InitiativeExpired(uint256 indexed initiativeId, address indexed actor);
    event Redeemed(
        uint256 indexed initiativeId, uint256 indexed tokenId, address indexed payee, uint256 amount
    );
    event DecayCurveUpdated(uint256 decayCurveType, uint256[] decayCurveParameters);
    event BoardClosed(address indexed actor);

    // Errors

    /// @notice Thrown when title is empty
    error Signals_EmptyTitle();

    /// @notice Thrown when body is empty
    error Signals_EmptyBody();

    /// @notice Thrown when caller has insufficient token balance
    error Signals_InsufficientTokens();

    /// @notice Thrown when initiative is not in the required state
    error Signals_InvalidInitiativeState();

    /// @notice Thrown when initiative is not in Proposed state
    error Signals_NotProposedState();

    /// @notice Thrown when initiative is not in Accepted or Expired state
    error Signals_NotWithdrawableState();

    /// @notice Thrown when token transfer fails
    error Signals_TokenTransferFailed();

    /// @notice Thrown when attempting to redeem already-withdrawn tokens
    error Signals_AlreadyRedeemed();

    /// @notice Thrown when attempting to redeem before release timelock expires
    error Signals_StillTimelocked();

    /// @notice Thrown when token owner attempts to redeem token they don't own
    error Signals_NotTokenOwner();

    /// @notice Thrown when initiative ID exceeds initiative count
    error Signals_InitiativeNotFound();

    /// @notice Thrown when token ID does not exist
    error Signals_InvalidTokenId();

    /// @notice Thrown when attempting to interact before board opens
    error Signals_BoardNotOpen();

    /// @notice Thrown when attempting to set incentives pool after board has opened
    error Signals_BoardAlreadyOpened();

    /// @notice Thrown when contract is already initialized
    error Signals_AlreadyInitialized();

    /// @notice Thrown when lock duration is zero or exceeds max
    error Signals_InvalidLockDuration();

    /// @notice Thrown when underlying token address is zero
    error Signals_ZeroAddressToken();

    /// @notice Thrown when owner address is zero
    error Signals_ZeroAddressOwner();

    error Signals_ZeroAddressIncentivesPool();

    /// @notice Thrown when acceptance threshold is zero
    error Signals_ZeroAcceptanceThreshold();

    /// @notice Thrown when max lock intervals is zero
    error Signals_ZeroMaxLockIntervals();

    /// @notice Thrown when lock interval is zero
    error Signals_ZeroLockInterval();

    /// @notice Thrown when proposal cap is zero
    error Signals_ZeroProposalCap();

    /// @notice Thrown when decay curve type is invalid
    error Signals_InvalidDecayCurveType();

    /// @notice Thrown when user has insufficient token balance for participating
    error Signals_ParticipantInsufficientBalance();

    /// @notice Thrown when user hasn't held tokens long enough to participate
    error Signals_ParticipantInsufficientDuration();

    /// @notice Thrown when token doesn't support holding duration checks
    error Signals_ParticipantNoCheckpointSupport();

    /// @notice Thrown when user has insufficient lock amount for proposing
    error Signals_ParticipantInsufficientLockAmount();

    /// @notice Thrown when participant min balance is zero
    error Signals_ConfigErrorZeroMinBalance();

    /// @notice Thrown when participant min holding duration is zero
    error Signals_ConfigErrorZeroMinDuration();

    /// @notice Thrown when initiative not eligible for expiration (still active)
    error Signals_NotEligibleForExpiration();

    /// @notice Thrown when attempting to set incentives pool when one is already set
    error Signals_IncentivesPoolAlreadySet();

    /// @notice Thrown when incentives pool is not approved for this board
    error Signals_IncentivesPoolNotApproved();

    /// @notice Thrown when incentive parameters are invalid
    error Signals_InvalidIncentiveParameters();

    /// @notice Thrown when attachment array exceeds supported bounds
    error Signals_AttachmentLimitExceeded();

    /// @notice Thrown when attachment URI is empty
    error Signals_AttachmentInvalidURI();

    /// @notice Thrown when board open timestamp is invalid (in the past)
    error Signals_InvalidBoardOpenTime();

    /// @notice Thrown when board closed timestamp is invalid (before open time)
    error Signals_InvalidBoardClosedTime();

    // Public state variables
    function acceptanceThreshold() external view returns (uint256);
    function maxLockIntervals() external view returns (uint256);
    function proposalCap() external view returns (uint256);
    function lockInterval() external view returns (uint256);
    function decayCurveType() external view returns (uint256);
    function decayCurveParameters(uint256) external view returns (uint256);
    function underlyingToken() external view returns (address);
    function inactivityTimeout() external view returns (uint256);
    function initiativeLocks(uint256, uint256) external view returns (uint256);
    function supporterLocks(address, uint256) external view returns (uint256);
    function supporters(uint256, uint256) external view returns (address);
    function isSupporter(uint256, address) external view returns (bool);
    function lockCount() external view returns (uint256);
    function initiativeCount() external view returns (uint256);
    function releaseLockDuration() external view returns (uint256);
    function boardOpenAt() external view returns (uint256);
    function boardClosedAt() external view returns (uint256);

    // Public functions
    function initialize(BoardConfig calldata config) external;
    function proposeInitiative(
        string memory title,
        string memory body,
        Attachment[] calldata attachments
    ) external returns (uint256 initiativeId);
    function proposeInitiativeWithLock(
        string memory title,
        string memory body,
        Attachment[] calldata attachments,
        uint256 amount,
        uint256 lockDuration
    ) external returns (uint256 initiativeId, uint256 lockId);
    function supportInitiative(uint256 initiativeId, uint256 amount, uint256 lockDuration)
        external
        returns (uint256);
    function acceptInitiative(uint256 initiativeId) external payable;
    function expireInitiative(uint256 initiativeId) external payable;
    function redeemLock(uint256 lockId) external;
    function redeemLocksForInitiative(uint256 initiativeId, uint256[] calldata lockIds) external;
    function getTokenLock(uint256 tokenId) external view returns (TokenLock memory);
    function getInitiative(uint256 initiativeId) external view returns (Initiative memory);
    function getSupporters(uint256 initiativeId) external view returns (address[] memory);
    function getWeight(uint256 initiativeId) external view returns (uint256);
    function getWeightAt(uint256 initiativeId, uint256 timestamp) external view returns (uint256);
    function getWeightForSupporterAt(uint256 initiativeId, address supporter, uint256 timestamp)
        external
        view
        returns (uint256);
    function token() external view returns (address);
    function totalInitiatives() external view returns (uint256);
    function totalSupporters(uint256 initiativeId) external view returns (uint256);
    function setDecayCurve(uint256 _decayCurveType, uint256[] calldata _decayCurveParameters)
        external;
    function setBounties(address _bounties) external;
    function setIncentivesPool(address _incentivesPool, IncentivesConfig calldata incentivesConfig)
        external;
    function setBoardOpenAt(uint256 _boardOpenAt) external;
    function closeBoard() external;
    function getPositionsForInitiative(uint256 initiativeId)
        external
        view
        returns (uint256[] memory);
    function getLockCountForSupporter(address supporter) external view returns (uint256);
    function getLocksForSupporter(address supporter) external view returns (uint256[] memory);
    function listPositions(address owner) external view returns (uint256[] memory);
    function isBoardOpen() external view returns (bool);
    function isBoardClosed() external view returns (bool);
}
