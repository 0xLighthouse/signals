// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.26;

import "forge-std/console.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "solmate/src/utils/ReentrancyGuard.sol";

import "./Signals.sol";
import "./interfaces/ISignals.sol";
import "./interfaces/IBounties.sol";
import "./TokenRegistry.sol";

contract Bounties is IBounties, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    ISignals public signalsContract;
    TokenRegistry public registry;

    /// @notice [0]: protocolFee, [1]: voterRewards, [2]: treasuryShare
    mapping(uint256 => uint256[3]) public allocations;
    mapping(uint256 => address[3]) public receivers;

    mapping(uint256 => Bounty) public bounties;

    /// (address => (token => amount))
    mapping(address => mapping(address => uint256)) public balances;

    /// (initiativeId => bountyId[])
    mapping(uint256 => uint256[]) public bountiesByInitiative;
    uint256 public version = 0;

    uint256 public bountyCount;

    function _updateShares(uint256[3] memory _allocations, address[3] memory _receivers) internal {
        require(_allocations[0] + _allocations[1] + _allocations[2] == 100, "Total distribution must be 100%");
        version++;
        allocations[version] = _allocations;
        receivers[version] = _receivers;
        emit BountiesUpdated(version);
    }

    constructor(
        address _signalsContract,
        address _tokenRegistry,
        uint256[3] memory _allocations,
        address[3] memory _receivers
    ) Ownable(msg.sender) {
        signalsContract = Signals(_signalsContract);
        registry = TokenRegistry(_tokenRegistry);

        _updateShares(_allocations, _receivers);
    }

    function updateSplits(uint256[3] memory _allocations, address[3] memory _receivers) external onlyOwner {
        _updateShares(_allocations, _receivers);
    }

    function config(uint256 _version) external view returns (uint256, uint256[3] memory, address[3] memory) {
        return (version, allocations[_version], receivers[_version]);
    }

    /**
     * Quick and dirty greedy function to get all the bounties for an initiative
     * and sum them by token address. This is not efficient and should be replaced
     */
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
            Bounty storage bounty = bounties[_bountyIds[i]];

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

    /**
     * @notice Add a bounty to the contract.
     *
     * @param _initiativeId The ID of the initiative to which the bounty belongs.
     * @param _token The address of the token to be used for the bounty.
     * @param _amount The amount of the token to be used for the bounty.
     * @param _expiresAt The timestamp at which the bounty expires.
     * @param _terms The terms of the bounty.
     */
    function addBounty(uint256 _initiativeId, address _token, uint256 _amount, uint256 _expiresAt, Conditions _terms)
        external
        payable
    {
        _addBounty(_initiativeId, _token, _amount, _expiresAt, _terms);
    }

    function _addBounty(
        uint256 _initiativeId,
        address _token,
        uint256 _amount,
        uint256 _expiresAt,
        Conditions _terms
    ) internal {
        require(registry.isAllowed(_token), "Token not registered for bounties");
        require(_initiativeId <= signalsContract.initiativeCount(), "Invalid initiative");

        IERC20 token = IERC20(_token);
        require(token.balanceOf(msg.sender) >= _amount, "Insufficient balance");
        require(token.allowance(msg.sender, address(this)) >= _amount, "Insufficient allowance");

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

    function _refundBounty(Bounty storage _bounty) internal {
        _bounty.refunded = _bounty.amount;
        balances[_bounty.contributor][address(_bounty.token)] += _bounty.amount;
    }

    function _distributeBounties(uint256 _initiativeId) internal {
        (address[] memory tokens, uint256[] memory amounts, uint256 expiredCount) = getBounties(_initiativeId);

        if (expiredCount > 0) {
            // TODO: Refund expired bounties
        }

        // Iterate through all the tokens for this initiative
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 amount = amounts[i];

            // Update balances for the bounty based on the current splits to the receivers
            uint256[3] memory _allocations = allocations[version];
            address[3] memory _receivers = receivers[version];

            uint256 protocolAmount = (amount * _allocations[0]) / 100;
            uint256 voterAmount = (amount * _allocations[1]) / 100;
            uint256 treasuryAmount = (amount * _allocations[2]) / 100;

            balances[_receivers[0]][token] += protocolAmount;
            balances[_receivers[1]][token] += voterAmount;
            balances[_receivers[2]][token] += treasuryAmount;
        }
    }

    /**
     * @notice Returns the voter rewards for a specific bond.
     *
     * @param _initiativeId The ID of the initiative.
     * @param _tokenId The ID of the NFT token (lock position).
     *
     * @return The voter rewards amount.
     */
    function previewRewards(uint256 _initiativeId, uint256 _tokenId) external view returns (uint256) {
        // Fetch bounties for this initiative
        uint256[] memory bountyIds = bountiesByInitiative[_initiativeId];
        if (bountyIds.length == 0) return 0;

        // Get token metadata
        ISignals.TokenLock memory bond = signalsContract.getTokenLock(_tokenId);

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
        uint256 underlyingLocked = signalsContract.getInitiative(_initiativeId).underlyingLocked;
        uint256 shareOfPool = bond.tokenAmount / underlyingLocked;
        uint256 voterRewards = (totalRewards * allocations[version][1]) / 100;
        uint256 tokenRewards = (voterRewards * shareOfPool);

        console.log("Share of pool", shareOfPool);

        return tokenRewards;
    }

    // Functions to handle notifications from Signals contract
    function handleInitiativeAccepted(uint256 _initiativeId) external nonReentrant {
        require(msg.sender == address(signalsContract), "Only Signals contract can call this function");

        console.log("Initiative accepted", _initiativeId);
        // Pay out relevant parties
        _distributeBounties(_initiativeId);
    }

    function handleInitiativeExpired(uint256 _initiativeId) external view {
        require(msg.sender == address(signalsContract), "Only Signals contract can call this function");
        // Additional logic if needed
        // TODO: Flag any bounties for this initiative as ready to be refunded
        console.log("Initiative expired", _initiativeId);
    }
}
