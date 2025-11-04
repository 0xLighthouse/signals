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
        AcceptanceCriteria acceptanceCriteria;
        uint256 maxLockIntervals;
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
     * @notice Criteria for accepting an initiative
     *
     * @param anyoneCanAccept If true, anyone can accept an initiative (otherwise, only owner)
     * @param ownerMustFollowThreshold If true, the owner must follow the threshold (otherwise, owner can accept any initiative)
     * @param percentageThresholdWAD Support must exceed this percentage (in WAD) of total underlying token supply
     * @param fixedThreshold Support must also exceed this fixed threshold for accepting an initiative
     */
    struct AcceptanceCriteria {
        bool anyoneCanAccept;
        bool ownerMustFollowThreshold;
        uint256 percentageThresholdWAD;
        uint256 fixedThreshold;
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
        address supporter;
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
     * @param supporter Address of the supporter      * @param tokenAmount Amount of tokens locked
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

    /// @notice Sender is not the owner of board or token they are interacting with
    error Signals_NotOwner();

    /// @notice Initiative or token ID is invalid
    error Signals_InvalidID();

    /// @notice Provided arguments are invalid (set to 0? Exceeding the maximum?)
    error Signals_InvalidArguments();

    /// @notice Title or body is empty
    error Signals_EmptyTitleOrBody();

    /// @notice Number of attachments exceeds the limit
    error Signals_AttachmentLimitExceeded();

    /// @notice A token balance is insufficient to carry out the requested action
    error Signals_InsufficientTokens();

    /// @notice User hasn't held tokens long enough for the requested action
    error Signals_InsufficientTokenDuration();

    /// @notice The requested lock amount is insufficient
    error Signals_InsufficientLockAmount();

    /// @notice Initiative is not in the correct state for the requested action
    error Signals_IncorrectInitiativeState();

    /// @notice Token transfer failed
    error Signals_TokenTransferFailed();

    /// @notice Token has already been redeemed
    error Signals_TokenAlreadyRedeemed(uint256 tokenId);

    /// @notice Token is still timelocked and cannot be redeemed yet
    error Signals_StillTimelocked();

    /// @notice The board is in the incorrect state for the requested action (open, closed, unitialized, etc.)
    error Signals_IncorrectBoardState();

    /// @notice Support is insufficient for acceptance
    error Signals_InsufficientSupport();

    /// @notice Token doesn't support holding duration checks
    error Signals_TokenHasNoCheckpointSupport();

    /// @notice Thrown when attempting to set incentives pool when one is already set
    error Signals_IncentivesPoolAlreadySet();

    /// @notice Thrown when incentives pool is not approved for this board
    error Signals_IncentivesPoolNotApproved();

    // Public state variables
    function version() external view returns (string memory);
    function title() external view returns (string memory);
    function getAcceptanceCriteria() external view returns (AcceptanceCriteria memory);
    function getAcceptanceThreshold() external view returns (uint256);
    function maxLockIntervals() external view returns (uint256);
    function lockInterval() external view returns (uint256);
    function decayCurveType() external view returns (uint256);
    function decayCurveParameters(uint256) external view returns (uint256);
    function underlyingToken() external view returns (address);
    function inactivityTimeout() external view returns (uint256);
    function locksForInitiative(uint256) external view returns (uint256[] memory);
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
    function redeemLocksForInitiative(uint256 initiativeId, uint256[] memory lockIds) external;
    function setTitle(string memory _title) external;
    function setAcceptanceCriteria(AcceptanceCriteria calldata acceptanceCriteria) external;
    function getTokenLock(uint256 tokenId) external view returns (TokenLock memory);
    function getInitiative(uint256 initiativeId) external view returns (Initiative memory);
    function getLocksBySupporterForInitiative(uint256 initiativeId, address supporter)
        external
        view
        returns (uint256[] memory);
    function getLocksByOwnerForInitiative(uint256 initiativeId, address owner)
        external
        view
        returns (uint256[] memory);
    function getSupportersOfInitiative(uint256 initiativeId)
        external
        view
        returns (address[] memory);
    function getWeight(uint256 initiativeId) external view returns (uint256);
    function getWeightAt(uint256 initiativeId, uint256 timestamp) external view returns (uint256);
    function getWeightForSupporterAt(uint256 initiativeId, address supporter, uint256 timestamp)
        external
        view
        returns (uint256);
    function setDecayCurve(uint256 _decayCurveType, uint256[] calldata _decayCurveParameters)
        external;
    function setIncentivesPool(address _incentivesPool, IncentivesConfig calldata incentivesConfig)
        external;
    function setBoardOpenAt(uint256 _boardOpenAt) external;
    function setBoardClosedAt(uint256 _boardClosedAt) external;
    function isBoardOpen() external view returns (bool);
    function isBoardClosed() external view returns (bool);
}
