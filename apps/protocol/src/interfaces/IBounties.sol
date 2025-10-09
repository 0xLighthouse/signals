// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ISignals.sol";

interface IBounties {
    enum Conditions {
        NONE,
        ACCEPTED_ON_OR_BEFORE_TIMESTAMP
    }

    struct Bounty {
        uint256 initiativeId;
        IERC20 token;
        uint256 amount;
        uint256 paid;
        uint256 refunded;
        uint256 expiresAt;
        address contributor;
        Conditions terms;
    }

    event BountyAdded(
        uint256 indexed bountyId,
        uint256 indexed initiativeId,
        address indexed token,
        uint256 amount,
        uint256 expiresAt,
        Conditions terms
    );

    event BountyPaidOut(
        uint256 indexed bountyId, uint256 protocolAmount, uint256 voterAmount, uint256 treasuryAmount
    );

    event BountiesUpdated(uint256 version);

    event RewardClaimed(uint256 indexed initiativeId, address indexed supporter, uint256 amount);

    event BountyRefunded(uint256 indexed initiativeId, address indexed contributor, uint256 amount);

    function signalsContract() external view returns (ISignals);
    function balances(address account, address token) external view returns (uint256);
    function version() external view returns (uint256);
    function bountyCount() external view returns (uint256);

    function updateSplits(uint256[3] memory _allocations, address[3] memory _receivers) external;
    function config(uint256 _version) external view returns (uint256, uint256[3] memory, address[3] memory);
    function getBounties(uint256 _initiativeId) external view returns (address[] memory, uint256[] memory, uint256);
    function addBounty(uint256 _initiativeId, address _token, uint256 _amount, uint256 _expiresAt, Conditions _terms)
        external
        payable;
    function previewRewards(uint256 _initiativeId, uint256 _tokenId) external view returns (uint256);
    function handleInitiativeAccepted(uint256 _initiativeId) external;
    function handleInitiativeExpired(uint256 _initiativeId) external;
}
