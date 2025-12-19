// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {ISignalsLock} from "./ISignalsLock.sol";

import {IAuthorizer} from "./IAuthorizer.sol";
import {IIncentivizer} from "./IIncentivizer.sol";

interface ISignals is IERC721Enumerable, ISignalsLock, IAuthorizer, IIncentivizer {
    /**
     * @notice Defines who is permitted to accept initiatives
     *
     * @dev Permissionless: Anyone can accept; anyone else can accept if threshold is met
     * @dev OnlyOwner: Only the board owner can accept initiatives
     */
    enum AcceptancePermissions {
        Permissionless,
        OnlyOwner
    }

    /**
     * @notice Defines whether the owner can bypass threshold requirements
     *
     * @dev None: Owner must meet threshold to accept (same rules as everyone)
     * @dev OnlyOwner: Owner can accept regardless of threshold
     */
    enum ThresholdOverride {
        None,
        OnlyOwner
    }

    /**
     * @notice Defines the type of decay curve for vote weight calculations
     *
     * @dev Linear: Vote weight decreases linearly over time
     * @dev Exponential: Vote weight decreases exponentially over time
     */
    enum DecayCurveType {
        Linear,
        Exponential
    }

    /**
     * @notice Configuration for token locking parameters
     *
     * @param lockInterval Time interval for lockup duration and decay calculations
     * @param maxLockIntervals Maximum lock intervals allowed
     * @param releaseLockDuration Duration tokens remain locked after acceptance (in seconds)
     * @param inactivityTimeout Time after which an initiative becomes inactive
     */
    struct LockingConfig {
        uint256 lockInterval;
        uint256 maxLockIntervals;
        uint256 releaseLockDuration;
        uint256 inactivityTimeout;
    }

    /**
     * @notice Configuration for vote weight decay calculations
     *
     * @param curveType Which decay curve to use (Linear or Exponential)
     * @param params Parameters to control the decay curve behavior
     */
    struct DecayConfig {
        DecayCurveType curveType;
        uint256[] params;
    }

    /**
     * @notice All configuration parameters for initializing the Signals contract
     *
     * @param version The version of the Signals contract
     * @param owner The address which will own the contract
     * @param underlyingToken The address of the underlying ERC20 token
     * @param opensAt Timestamp when board opens for participation (0 = doesn't open until updated)
     * @param closesAt Timestamp when board closes for participation (0 = never closes)
     * @param boardMetadata Metadata for the board (title, body, attachments)
     * @param acceptanceCriteria Criteria for accepting initiatives (permissions and thresholds)
     * @param proposerRequirements Requirements for who can propose (immutable)
     * @param supporterRequirements Requirements for who can support initiatives (immutable)
     * @param lockingConfig Configuration for token locking parameters
     * @param decayConfig Configuration for vote weight decay
     */
    struct BoardConfig {
        string version;
        address owner;
        address underlyingToken;
        uint256 opensAt;
        uint256 closesAt;
        Metadata boardMetadata;
        AcceptanceCriteria acceptanceCriteria;
        IAuthorizer.ParticipantRequirements proposerRequirements;
        IAuthorizer.ParticipantRequirements supporterRequirements;
        LockingConfig lockingConfig;
        DecayConfig decayConfig;
    }

    /**
     * @notice Metadata associated with the board or initiative
     *
     * @param title The title of the board
     * @param body The detailed body of the board in markdown format
     * @param attachments Optional metadata attachments associated with the board
     */
    struct Metadata {
        string title;
        string body;
        Attachment[] attachments;
    }

    /**
     * @notice Optional metadata attachment associated with an initiative
     */
    struct Attachment {
        string uri;
        string mimeType;
        string description;
    }

    /**
     * @notice Criteria for accepting an initiative
     *
     * @param permissions Who can accept initiatives (OnlyOwner or Permissionless)
     * @param thresholdOverride Whether owner can bypass threshold (None or OnlyOwner)
     * @param thresholdPercentTotalSupplyWAD Support must exceed this percentage (in WAD) of total underlying token supply
     * @param minThreshold Support must also exceed this minimum fixed threshold for accepting an initiative
     *
     * @dev The effective acceptance threshold is: max(totalSupply * thresholdPercentTotalSupplyWAD / 1e18, minThreshold)
     * @dev At least one of thresholdPercentTotalSupplyWAD or minThreshold must be non-zero
     *
     * Permission combinations:
     * - OnlyOwner + None: Only owner can accept, and owner must meet threshold
     * - OnlyOwner + OnlyOwner: Only owner can accept, owner can bypass threshold
     * - Permissionless + None: Owner must meet threshold; anyone can accept if threshold met
     * - Permissionless + OnlyOwner: Owner can always accept; others need threshold met
     */
    struct AcceptanceCriteria {
        AcceptancePermissions permissions;
        ThresholdOverride thresholdOverride;
        uint256 thresholdPercentTotalSupplyWAD;
        uint256 minThreshold;
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
        InitiativeState state;
        address proposer;
        uint256 timestamp;
        uint256 lastActivity;
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

    // Enums
    enum InitiativeState {
        Proposed,
        Accepted,
        Cancelled,
        Expired
    }

    /* ------------------------------
     * Events
     * ------------------------------ */

    event IncentivesPoolSet(address indexed incentivesPool, IncentivesConfig indexed config);
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
        uint256 indexed initiativeId, address indexed proposer, Metadata metadata
    );
    event InitiativeAccepted(uint256 indexed initiativeId, address indexed actor);
    event InitiativeExpired(uint256 indexed initiativeId, address indexed actor);
    event Redeemed(
        uint256 indexed initiativeId, uint256 indexed tokenId, address indexed payee, uint256 amount
    );

    event OpensAtChanged(uint256 indexed opensAt);
    event ClosesAtChanged(uint256 indexed closesAt);

    event BoardClosed(address indexed sender);
    event BoardCancelled(address indexed sender);

    /* ------------------------------
     * Errors
     * ------------------------------ */

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
    error Signals_StillTimelocked(uint256 tokenId);

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
    function getAcceptanceCriteria() external view returns (AcceptanceCriteria memory);
    function getAcceptanceThreshold() external view returns (uint256);
    function maxLockIntervals() external view returns (uint256);
    function lockInterval() external view returns (uint256);
    function decayCurveType() external view returns (DecayCurveType);
    function decayCurveParameters(uint256) external view returns (uint256);
    function underlyingToken() external view returns (address);
    function inactivityTimeout() external view returns (uint256);
    function locksForInitiative(uint256) external view returns (uint256[] memory);
    function lockCount() external view returns (uint256);
    function initiativeCount() external view returns (uint256);
    function releaseLockDuration() external view returns (uint256);
    function opensAt() external view returns (uint256);
    function closesAt() external view returns (uint256);

    // Public functions
    function initialize(BoardConfig calldata config) external;
    function proposeInitiative(Metadata calldata metadata)
        external
        returns (uint256 initiativeId);
    function proposeInitiativeWithLock(
        Metadata calldata metadata,
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
    function getTokenLock(uint256 tokenId) external view returns (TokenLock memory);
    function getInitiative(uint256 initiativeId) external view returns (Initiative memory);
    function getWeight(uint256 initiativeId) external view returns (uint256);
    function getWeightAt(uint256 initiativeId, uint256 timestamp) external view returns (uint256);
    function getWeightForSupporterAt(uint256 initiativeId, address supporter, uint256 timestamp)
        external
        view
        returns (uint256);


    /**
     * Allows the board owner to set an incentives pool
     *
     * @param incentivesPool_ The address of the incentives pool
     * @param config_ The configuration for the incentives pool
     *
     * @dev Emits an IncentivesPoolChanged event
     */
    function setIncentivesPool(address incentivesPool_, IncentivesConfig calldata config_)
        external;

    /**
     * Allows the board owner to change the opensAt timestamp
     * while the board is not open or closed
     *
     * @param opensAt_ The new opensAt timestamp
     * @dev Emits an OpensAtChanged event
     */
    function setOpensAt(uint256 opensAt_) external;

    /**
     * Allows the board owner to change the closesAt timestamp
     * while the board not closed
     *
     * @param closesAt_ The new closesAt timestamp
     * @dev Emits an ClosesAtChanged event
     */
    function setClosesAt(uint256 closesAt_) external;

    /// @dev Returns true if the board is open
    function isBoardOpen() external view returns (bool);

    /// @dev Returns true if the board is closed
    function isBoardClosed() external view returns (bool);
}
