// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {IBondIssuer} from "./IBondIssuer.sol";

interface ISignals is IERC721Enumerable, IBondIssuer {
    /**
     * @notice All configuration parameters for initializing the Signals contract
     *
     * @param owner The address which will own the contract
     * @param underlyingToken The address of the underlying ERC20 token
     * @param version The version of the Signals contract
     * @param acceptanceThreshold Weight required for an initiative to be accepted
     * @param maxLockIntervals Maximum lock intervals allowed
     * @param proposalCap The maximum active proposals a user can submit (TODO: Verify this, rename to activeProposalLimit)
     * @param lockInterval Time interval for lockup duration and decay calculations
     * @param decayCurveType Which decay curve to use (e.g., 0 = linear, 1 = exponential)
     * @param decayCurveParameters Parameters to control the decay curve behavior
     * @param proposerRequirements Requirements for who can propose (immutable)
     * @param participantRequirements Requirements for who can support initiatives (immutable)
     * @param releaseLockDuration Duration tokens remain locked after acceptance (0 = immediate release)
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
        ProposerRequirements proposerRequirements;
        ParticipantRequirements participantRequirements;
        uint256 releaseLockDuration;
    }

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
     * @param acceptanceTimestamp The timestamp when the initiative was accepted (0 if not accepted)
     */
    struct Initiative {
        string title;
        string body;
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
     * @notice Requirements for who can propose initiatives
     *
     * @param eligibilityType Type of eligibility check (None, MinBalance, MinBalanceAndDuration)
     * @param minBalance Minimum token balance required to be eligible
     * @param minHoldingDuration Minimum blocks tokens must be held (for MinBalanceAndDuration)
     * @param threshold Tokens proposer must lock when creating an initiative
     */
    struct ProposerRequirements {
        EligibilityType eligibilityType;
        uint256 minBalance;
        uint256 minHoldingDuration;
        uint256 threshold;
    }

    /**
     * @notice Requirements for who can participate (support initiatives)
     *
     * @param eligibilityType Type of eligibility check (None, MinBalance, MinBalanceAndDuration)
     * @param minBalance Minimum token balance required to be eligible
     * @param minHoldingDuration Minimum blocks tokens must be held (for MinBalanceAndDuration)
     */
    struct ParticipantRequirements {
        EligibilityType eligibilityType;
        uint256 minBalance;
        uint256 minHoldingDuration;
    }

    // Enums
    enum InitiativeState {
        Proposed,
        Accepted,
        Cancelled,
        Expired
    }

    enum BoardState {
        Open,
        Closed
    }

    /// @notice Types of eligibility requirements for proposers and participants
    enum EligibilityType {
        None,                    // No requirements
        MinBalance,              // Requires minimum token balance
        MinBalanceAndDuration    // Requires min balance held for min duration
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
    event InitiativeProposed(uint256 indexed initiativeId, address indexed proposer, string title, string body);
    event InitiativeAccepted(uint256 indexed initiativeId, address indexed actor);
    event InitiativeExpired(uint256 indexed initiativeId, address indexed actor);
    event Redeemed(uint256 indexed tokenId, address indexed actor, uint256 amount);
    event DecayCurveUpdated(uint256 decayCurveType, uint256[] decayCurveParameters);
    event BoardClosed(address indexed actor);

    // Errors
    error InvalidInput(string message);
    error InsufficientTokens();
    error InvalidInitiativeState(string message);
    error TokenTransferFailed();
    error InvalidRedemption();
    error InitiativeNotFound();
    error InvalidTokenId();
    error BoardClosedError();

    /// @notice Error when user doesn't meet proposer requirements
    error ProposerRequirementsNotMet(string reason);

    /// @notice Error when user doesn't meet participant requirements
    error ParticipantRequirementsNotMet(string reason);

    // Public state variables
    function acceptanceThreshold() external view returns (uint256);
    function maxLockIntervals() external view returns (uint256);
    function proposalCap() external view returns (uint256);
    function lockInterval() external view returns (uint256);
    function decayCurveType() external view returns (uint256);
    function decayCurveParameters(uint256) external view returns (uint256);
    function underlyingToken() external view returns (address);
    function activityTimeout() external view returns (uint256);
    function initiativeLocks(uint256, uint256) external view returns (uint256);
    function supporterLocks(address, uint256) external view returns (uint256);
    function supporters(uint256, uint256) external view returns (address);
    function isSupporter(uint256, address) external view returns (bool);
    function nextTokenId() external view returns (uint256);
    function initiativeCount() external view returns (uint256);
    function releaseLockDuration() external view returns (uint256);
    function boardState() external view returns (BoardState);

    // Public functions
    function initialize(BoardConfig calldata config) external;
    function proposeInitiative(string memory title, string memory body) external;
    function proposeInitiativeWithLock(string memory title, string memory body, uint256 amount, uint256 lockDuration)
        external
        returns (uint256);
    function supportInitiative(uint256 initiativeId, uint256 amount, uint256 lockDuration) external returns (uint256);
    function acceptInitiative(uint256 initiativeId) external payable;
    function expireInitiative(uint256 initiativeId) external payable;
    function redeem(uint256 tokenId) external;
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
    function setInactivityThreshold(uint256 _newThreshold) external;
    function setDecayCurve(uint256 _decayCurveType, uint256[] calldata _decayCurveParameters) external;
    function setBounties(address _bounties) external;
    function closeBoard() external;
    function getPositionsForInitiative(uint256 initiativeId) external view returns (uint256[] memory);
    function getLockCountForSupporter(address supporter) external view returns (uint256);
    function getLocksForSupporter(address supporter) external view returns (uint256[] memory);
    function listPositions(address owner) external view returns (uint256[] memory);

    /// @notice Get current proposer requirements (immutable)
    /// @return Current proposer requirements configuration
    function getProposerRequirements() external view returns (ProposerRequirements memory);

    /// @notice Get current participant requirements (immutable)
    /// @return Current participant requirements configuration
    function getParticipantRequirements() external view returns (ParticipantRequirements memory);

    /// @notice Check if an address meets proposer requirements
    /// @param proposer Address to check
    /// @return True if address can propose
    function canPropose(address proposer) external view returns (bool);

    /// @notice Check if an address meets participant requirements
    /// @param participant Address to check
    /// @return True if address can participate
    function canParticipate(address participant) external view returns (bool);
}
