// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.28;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import './Signals.sol';
import './RewardRegistry.sol';

contract Incentives is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Incentive {
        uint256 initiativeId;
        IERC20 token;
        uint256 amount;
        uint256 expiresAt;
        IncentiveTerms terms;
    }

    enum IncentiveTerms {
        NONE,
        ACCEPTED_ON_OR_BEFORE_TIMESTAMP
    }

    mapping(uint256 => Incentive) public incentives;
    uint256 public incentiveCount;

    Signals public signalsContract;
    RewardRegistry public rewardRegistry;
    address public protocolTreasury;
    address public voterRewardsPool;

    uint256 public constant PROTOCOL_FEE = 3;
    uint256 public constant VOTER_REWARD = 7;
    uint256 public constant TREASURY_SHARE = 90;

    event IncentiveAdded(uint256 indexed incentiveId, uint256 indexed initiativeId, address indexed token, uint256 amount, IncentiveTerms terms, uint256 expiresAt);
    event IncentivePaidOut(uint256 indexed incentiveId, uint256 protocolAmount, uint256 voterAmount, uint256 treasuryAmount);

    constructor(address _signalsContract, address _rewardRegistry, address _protocolTreasury, address _voterRewardsPool) {
        signalsContract = Signals(_signalsContract);
        rewardRegistry = RewardRegistry(_rewardRegistry);
        protocolTreasury = _protocolTreasury;
        voterRewardsPool = _voterRewardsPool;
    }

    /**
     * @notice Add an incentive to the contract.
     * 
     * @param _initiativeId The ID of the initiative to which the incentive belongs.
     * @param _token The address of the token to be used for the incentive.
     * @param _amount The amount of the token to be used for the incentive.
     * @param _expiresAt The timestamp at which the incentive expires.
     * @param _terms The terms of the incentive.
     */
    function addIncentive(
        uint256 _initiativeId,
        address _token,
        uint256 _amount,
        uint256 _expiresAt,
        IncentiveTerms _terms
    ) external payable {
        if (_expiresAt == 0 && _terms == IncentiveTerms.NONE) {
            _terms = IncentiveTerms.ACCEPTED_ON_OR_BEFORE_TIMESTAMP;
        }
        _addIncentive(_initiativeId, _token, _amount, _expiresAt, _terms);
    }

    function _addIncentive(uint256 _initiativeId, address _token, uint256 _amount, uint256 _expiresAt, IncentiveTerms _terms) internal {
        require(rewardRegistry.isRegistered(_token), "Token not approved");
        require(_initiativeId < signalsContract.totalInitiatives(), "Invalid initiative");

        IERC20 token = IERC20(_token);
        require(token.balanceOf(msg.sender) >= _amount, "Insufficient balance");
        require(token.allowance(msg.sender, address(this)) >= _amount, "Insufficient allowance");

        token.safeTransferFrom(msg.sender, address(this), _amount);

        incentiveCount++;
        incentives[incentiveCount] = Incentive({
            initiativeId: _initiativeId,
            token: token,
            amount: _amount,
            expiresAt: _expiresAt,
            terms: _terms
        });

        emit IncentiveAdded(incentiveCount, _initiativeId, _token, _amount, _terms, _expiresAt);
    }

    function payout(uint256 _incentiveId) external nonReentrant {
        Incentive storage incentive = incentives[_incentiveId];
        require(incentive.amount > 0, "Incentive already paid out or doesn't exist");
        require(incentive.expiresAt == 0 || block.timestamp <= incentive.expiresAt, "Incentive expired");

        Signals.Initiative memory initiative = signalsContract.getInitiative(incentive.initiativeId);
        require(initiative.state == Signals.InitiativeState.Accepted, "Initiative not accepted");

        IERC20 token = incentive.token;
        uint256 totalAmount = incentive.amount;

        uint256 protocolAmount = (totalAmount * PROTOCOL_FEE) / 100;
        uint256 voterAmount = (totalAmount * VOTER_REWARD) / 100;
        uint256 treasuryAmount = totalAmount - protocolAmount - voterAmount;

        token.safeTransfer(protocolTreasury, protocolAmount);
        token.safeTransfer(voterRewardsPool, voterAmount);
        token.safeTransfer(address(signalsContract), treasuryAmount);

        incentive.amount = 0; // Mark as paid out

        emit IncentivePaidOut(_incentiveId, protocolAmount, voterAmount, treasuryAmount);
    }
}
