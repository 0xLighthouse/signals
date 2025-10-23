// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.26;

import "forge-std/console.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "solady/src/utils/ReentrancyGuard.sol";

import "./interfaces/ISignals.sol";
import "./interfaces/IBounties.sol";

import "./Signals.sol";
import "./TokenRegistry.sol";
import {SignalsConstants} from "./utils/Constants.sol";

/**
 * @title Bounties
 * @notice Manages bounties (rewards) attached to Signals initiatives
 * @dev Handles bounty creation, distribution on acceptance, and refunds on expiration
 */
contract Bounties is IBounties, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    ISignals public immutable SIGNALS_CONTRACT;
    TokenRegistry public immutable REGISTRY;

    /// @notice [0]: protocolFee, [1]: voterRewards, [2]: treasuryShare
    mapping(uint256 => uint256[3]) public allocations;
    mapping(uint256 => address[3]) public receivers;

    mapping(uint256 => Bounty) public bounties;

    /// @notice (address => (token => amount))
    mapping(address => mapping(address => uint256)) public balances;

    /// @notice (initiativeId => bountyId[])
    mapping(uint256 => uint256[]) public bountiesByInitiative;
    uint256 public version;

    uint256 public bountyCount;

    /**
     * @notice Initialize the Bounties contract
     * @param _SIGNALS_CONTRACT Address of the Signals contract
     * @param _tokenRegistry Address of the TokenRegistry contract
     * @param _allocations Initial split allocations
     * @param _receivers Initial receiver addresses
     */
    constructor(
        address _SIGNALS_CONTRACT,
        address _tokenRegistry,
        uint256[3] memory _allocations,
        address[3] memory _receivers
    ) Ownable(msg.sender) {
        SIGNALS_CONTRACT = Signals(_SIGNALS_CONTRACT);
        REGISTRY = TokenRegistry(_tokenRegistry);

        _updateShares(_allocations, _receivers);
    }

    /// @inheritdoc IBounties
    function signalsContract() external view returns (ISignals) {
        return SIGNALS_CONTRACT;
    }

    /// @inheritdoc IBounties
    function updateSplits(uint256[3] memory _allocations, address[3] memory _receivers) external onlyOwner {
        _updateShares(_allocations, _receivers);
    }

    /// @inheritdoc IBounties
    function addBounty(uint256 _initiativeId, address _token, uint256 _amount, uint256 _expiresAt, Conditions _terms)
        external
        payable
    {
        _addBounty(_initiativeId, _token, _amount, _expiresAt, _terms);
    }

    /// @inheritdoc IBounties
    function handleInitiativeAccepted(uint256 _initiativeId) external nonReentrant {
        if (msg.sender != address(SIGNALS_CONTRACT)) {
            revert IBounties.Bounties_NotAuthorized();
        }

        console.log("Initiative accepted", _initiativeId);
        // Pay out relevant parties
        _distributeBounties(_initiativeId);
    }

    /// @inheritdoc IBounties
    function handleInitiativeExpired(uint256 _initiativeId) external view {
        if (msg.sender != address(SIGNALS_CONTRACT)) {
            revert IBounties.Bounties_NotAuthorized();
        }
        // Additional logic if needed
        // TODO(@arnold): [MEDIUM] Flag bounties for this initiative as refundable
        //                When an initiative expires, mark associated bounties as refundable
        //                so contributors can reclaim their tokens via a claim function
        console.log("Initiative expired", _initiativeId);
    }

    /**
     * @notice Internal function to update bounty split allocations
     * @dev Validates allocations sum to 100 (basis points), increments version
     * @param _allocations Array of [protocolFee, voterRewards, treasuryShare]
     * @param _receivers Array of addresses to receive each allocation
     */
    function _updateShares(uint256[3] memory _allocations, address[3] memory _receivers) internal {
        if (_allocations[0] + _allocations[1] + _allocations[2] != SignalsConstants.BASIS_POINTS) {
            revert IBounties.Bounties_InvalidAllocation();
        }
        version++;
        allocations[version] = _allocations;
        receivers[version] = _receivers;
        emit BountiesUpdated(version);
    }

    /**
     * @notice Internal function to add a bounty
     * @dev Validates token is registered, transfers tokens, and stores bounty data
     * @param _initiativeId Initiative ID to attach bounty to
     * @param _token Token address for the bounty
     * @param _amount Amount of tokens to bounty
     * @param _expiresAt Expiration timestamp
     * @param _terms Conditions for distribution
     */
    function _addBounty(
        uint256 _initiativeId,
        address _token,
        uint256 _amount,
        uint256 _expiresAt,
        Conditions _terms
    ) internal {
        if (!REGISTRY.isAllowed(_token)) revert IBounties.Bounties_TokenNotRegistered();
        if (_initiativeId > SIGNALS_CONTRACT.initiativeCount()) revert IBounties.Bounties_InvalidInitiative();

        IERC20 token = IERC20(_token);
        if (token.balanceOf(msg.sender) < _amount) revert IBounties.Bounties_InsufficientBalance();
        if (token.allowance(msg.sender, address(this)) < _amount) revert IBounties.Bounties_InsufficientAllowance();

        token.safeTransferFrom(msg.sender, address(this), _amount);

        bounties[bountyCount] = Bounty({
            initiativeId: _initiativeId,
            token: token,
            amount: _amount,
            paid: 0,
            refunded: 0,
            expiresAt: _expiresAt,
            contributor: msg.sender,
            terms: _terms
        });

        // Store the bounty ID in the initiative's list of bounties
        bountiesByInitiative[_initiativeId].push(bountyCount);

        bountyCount++;

        emit BountyAdded(bountyCount, _initiativeId, address(_token), _amount, _expiresAt, _terms);
    }

    /**
     * @notice Internal function to refund a bounty to its contributor
     * @dev Marks bounty as refunded and credits contributor's balance
     * @param _bounty Storage reference to the bounty to refund
     */
    function _refundBounty(Bounty storage _bounty) internal {
        _bounty.refunded = _bounty.amount;
        balances[_bounty.contributor][address(_bounty.token)] += _bounty.amount;
    }

    /**
     * @notice Internal function to distribute bounties when initiative is accepted
     * @dev Splits bounties according to current version's allocations
     * @param _initiativeId Initiative ID to distribute bounties for
     */
    function _distributeBounties(uint256 _initiativeId) internal {
        (address[] memory tokens, uint256[] memory amounts, uint256 expiredCount) = getBounties(_initiativeId);

        if (expiredCount > 0) {
            // TODO(@arnold): [MEDIUM] Implement refund logic for expired bounties
            //                Expired bounties should be marked as refundable and returned to contributors
            //                Consider gas implications of processing expired bounties in this function
        }

        // Cache version-specific allocations and receivers outside the loop
        uint256[3] memory _allocations = allocations[version];
        address[3] memory _receivers = receivers[version];

        // Iterate through all the tokens for this initiative
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 amount = amounts[i];

            uint256 protocolAmount = (amount * _allocations[0]) / SignalsConstants.BASIS_POINTS;
            uint256 voterAmount = (amount * _allocations[1]) / SignalsConstants.BASIS_POINTS;
            uint256 treasuryAmount = (amount * _allocations[2]) / SignalsConstants.BASIS_POINTS;

            balances[_receivers[0]][token] += protocolAmount;
            balances[_receivers[1]][token] += voterAmount;
            balances[_receivers[2]][token] += treasuryAmount;
        }
    }

    /// @inheritdoc IBounties
    function config(uint256 _version) external view returns (uint256, uint256[3] memory, address[3] memory) {
        return (version, allocations[_version], receivers[_version]);
    }

    /// @inheritdoc IBounties
    function getBounties(uint256 _initiativeId)
        public
        view
        returns (address[] memory, uint256[] memory, uint256 expiredCount)
    {
        uint256[] memory _bountyIds = bountiesByInitiative[_initiativeId];

        // Using arrays to store tokens and their total amounts
        address[] memory tokens = new address[](_bountyIds.length);
        uint256[] memory amounts = new uint256[](_bountyIds.length);
        uint256 _expiredCount = 0;
        uint256 tokenCount = 0;

        for (uint256 i = 0; i < _bountyIds.length; i++) {
            Bounty memory bounty = bounties[_bountyIds[i]]; // Use memory for read-only access

            // If the bounty has expired, exclude it from the sum
            if (bounty.expiresAt != 0 && block.timestamp > bounty.expiresAt) {
                _expiredCount++;
                continue;
            }

            address tokenAddress = address(bounty.token);
            bool found = false;
            for (uint256 j = 0; j < tokenCount; j++) {
                if (tokens[j] == tokenAddress) {
                    // Token found, accumulate the amount
                    amounts[j] += bounty.amount;
                    found = true;
                    break;
                }
            }

            // If the token was not found, add it to the tokens array
            if (!found) {
                tokens[tokenCount] = tokenAddress;
                amounts[tokenCount] = bounty.amount;
                tokenCount++;
            }
        }

        // Create arrays with the actual size
        address[] memory resultTokens = new address[](tokenCount);
        uint256[] memory resultAmounts = new uint256[](tokenCount);

        for (uint256 i = 0; i < tokenCount; i++) {
            resultTokens[i] = tokens[i];
            resultAmounts[i] = amounts[i];
        }

        return (resultTokens, resultAmounts, _expiredCount);
    }

    /// @inheritdoc IBounties
    function previewRewards(uint256 _initiativeId, uint256 _tokenId) external view returns (uint256) {
        // Fetch bounties for this initiative
        uint256[] memory bountyIds = bountiesByInitiative[_initiativeId];
        if (bountyIds.length == 0) return 0;

        // Get token metadata
        ISignals.TokenLock memory bond = SIGNALS_CONTRACT.getTokenLock(_tokenId);

        // Verify this token is for the specified initiative
        if (bond.initiativeId != _initiativeId) return 0;

        // If the token has already been withdrawn, return 0
        if (bond.withdrawn) return 0;

        // Calculate the proportion of rewards this token should receive
        uint256 totalRewards = 0;

        // FIXME: This is a bit sketchy as we are mixing various token denominations...
        (, uint256[] memory _amounts,) = getBounties(_initiativeId);
        for (uint256 i = 0; i < _amounts.length; i++) {
            totalRewards += _amounts[i];
        }

        // Calculate voter rewards
        uint256 underlyingLocked = SIGNALS_CONTRACT.getInitiative(_initiativeId).underlyingLocked;
        uint256 shareOfPool = bond.tokenAmount / underlyingLocked;
        uint256 voterRewards = (totalRewards * allocations[version][1]) / SignalsConstants.BASIS_POINTS;
        uint256 tokenRewards = (voterRewards * shareOfPool);

        console.log("Share of pool", shareOfPool);

        return tokenRewards;
    }
}
