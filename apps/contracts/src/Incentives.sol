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

    Signals public signalsContract;
    RewardRegistry public rewardRegistry;
    
    struct Incentive {
        uint256 initiativeId;
        IERC20 token;
        uint256 amount;
        uint256 paid;
        uint256 expiresAt;
        Conditions terms;
    }

    enum Conditions {
        NONE,
        ACCEPTED_ON_OR_BEFORE_TIMESTAMP
    }

    /// @notice [0]: protocolFee, [1]: voterRewards, [2]: treasuryShare
    mapping(uint256 => uint256[3]) public allocations;
    mapping(uint256 => address[3]) public receivers;


    mapping(uint256 => Incentive) public incentives;
    
    uint256 public version = 0;

    uint256 public incentiveCount;

    event IncentiveAdded(uint256 indexed incentiveId,
        uint256 indexed initiativeId,
        address indexed token,
        uint256 amount,
        uint256 expiresAt,
        Conditions terms
    );

    event IncentivePaidOut(uint256 indexed incentiveId, 
        uint256 protocolAmount, 
        uint256 voterAmount, 
        uint256 treasuryAmount
    );
    
    event DistributionScheduleUpdated(uint256 scheduleId);

    function _updateShares(uint256[3] memory _allocations, address[3] memory _receivers) internal {
        require(_allocations[0] + _allocations[1] + _allocations[2] == 100, "Total distribution must be 100%");
        version++;
        allocations[version] = _allocations;
        receivers[version] = _receivers;
        emit DistributionScheduleUpdated(version);
    }

    constructor(
        address _signalsContract,
        address _rewardRegistry,
        uint256[3] memory _allocations,
        address[3] memory _receivers    
    ) {
        signalsContract = Signals(_signalsContract);
        rewardRegistry = RewardRegistry(_rewardRegistry);
        
        _updateShares(_allocations, _receivers);
    }

    function updateSplits(uint256[3] memory _allocations, address[3] memory _receivers) external onlyOwner {
        _updateShares(_allocations, _receivers);
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
        Conditions _terms
    ) external payable {
        // if (_expiresAt == 0 && _terms == Conditions.NONE) {
        //     _terms = Conditions.ACCEPTED_ON_OR_BEFORE_TIMESTAMP;
        // }
        _addIncentive(_initiativeId, _token, _amount, _expiresAt, _terms);
    }

    function _addIncentive(uint256 _initiativeId, address _token, uint256 _amount, uint256 _expiresAt, Conditions _terms) internal {
        require(rewardRegistry.isRegistered(_token), "Token not registered for incentives");
        require(_initiativeId < signalsContract.totalInitiatives(), "Invalid initiative");

        IERC20 token = IERC20(_token);
        require(token.balanceOf(msg.sender) >= _amount, "Insufficient balance");
        require(token.allowance(msg.sender, address(this)) >= _amount, "Insufficient allowance");

        token.safeTransferFrom(msg.sender, address(this), _amount);
            
        incentives[incentiveCount] = Incentive({
            initiativeId: _initiativeId,
            token: token,
            amount: _amount,
            paid: 0,
            expiresAt: _expiresAt,
            terms: _terms
        });

        incentiveCount++;

        emit IncentiveAdded(incentiveCount, _initiativeId, address(_token), _amount,_expiresAt, _terms);
    }

    function payout(uint256 _incentiveId) external nonReentrant {
        Incentive storage incentive = incentives[_incentiveId];
        require(incentive.paid > 0, "Incentive already paid out or doesn't exist");
        require(incentive.expiresAt == 0 || block.timestamp <= incentive.expiresAt, "Incentive expired");

        Signals.Initiative memory initiative = signalsContract.getInitiative(incentive.initiativeId);
        require(initiative.state == Signals.InitiativeState.Accepted, "Initiative not accepted");

        IERC20 token = incentive.token;
        uint256 totalAmount = incentive.amount;

        uint256 protocolAmount = (totalAmount * allocations[version][0]) / 100;
        uint256 voterAmount = (totalAmount * allocations[version][1]) / 100;
        uint256 treasuryAmount = totalAmount - protocolAmount - voterAmount;

        // TODO: Check these transfers emit a transfer event
        token.safeTransfer(receivers[version][0], protocolAmount);
        token.safeTransfer(receivers[version][1], voterAmount);
        token.safeTransfer(receivers[version][2], treasuryAmount);

        incentive.paid = incentive.amount; // Record the amount paid out

        emit IncentivePaidOut(_incentiveId, protocolAmount, voterAmount, treasuryAmount);
    }
}
