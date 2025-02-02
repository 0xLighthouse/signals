// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.26;

import 'forge-std/console.sol';

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import 'solmate/src/utils/ReentrancyGuard.sol';

import './Signals.sol';
import './TokenRegistry.sol';

contract Incentives is Ownable, ReentrancyGuard {
  using SafeERC20 for IERC20;

  Signals public signalsContract;
  TokenRegistry public registry;

  struct Incentive {
    uint256 initiativeId;
    IERC20 token;
    uint256 amount;
    uint256 paid;
    uint256 refunded;
    uint256 expiresAt;
    address contributor;
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

  /// (address => (token => amount))
  mapping(address => mapping(address => uint256)) public balances;

  /// (initiativeId => incentiveId[])
  mapping(uint256 => uint256[]) public incentivesByInitiative;
  uint256 public version = 0;

  uint256 public incentiveCount;

  event IncentiveAdded(
    uint256 indexed incentiveId,
    uint256 indexed initiativeId,
    address indexed token,
    uint256 amount,
    uint256 expiresAt,
    Conditions terms
  );

  event IncentivePaidOut(
    uint256 indexed incentiveId,
    uint256 protocolAmount,
    uint256 voterAmount,
    uint256 treasuryAmount
  );

  event IncentivesUpdated(uint256 version);

  event RewardClaimed(uint256 indexed initiativeId, address indexed supporter, uint256 amount);

  event IncentiveRefunded(
    uint256 indexed initiativeId,
    address indexed contributor,
    uint256 amount
  );

  function _updateShares(uint256[3] memory _allocations, address[3] memory _receivers) internal {
    require(
      _allocations[0] + _allocations[1] + _allocations[2] == 100,
      'Total distribution must be 100%'
    );
    version++;
    allocations[version] = _allocations;
    receivers[version] = _receivers;
    emit IncentivesUpdated(version);
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

  function updateSplits(
    uint256[3] memory _allocations,
    address[3] memory _receivers
  ) external onlyOwner {
    _updateShares(_allocations, _receivers);
  }

  function config(
    uint256 _version
  ) external view returns (uint256, uint256[3] memory, address[3] memory) {
    return (version, allocations[_version], receivers[_version]);
  }

  /**
   * Quick and dirty greedy function to get all the incentives for an initiative
   * and sum them by token address. This is not efficient and should be replaced
   */
  function getIncentives(
    uint256 _initiativeId
  ) public view returns (address[] memory, uint256[] memory, uint256 expiredCount) {
    uint256[] memory _incentiveIds = incentivesByInitiative[_initiativeId];

    // Using arrays to store tokens and their total amounts
    address[] memory tokens = new address[](_incentiveIds.length);
    uint256[] memory amounts = new uint256[](_incentiveIds.length);
    uint256 _expiredCount = 0;
    uint256 tokenCount = 0;

    for (uint256 i = 0; i < _incentiveIds.length; i++) {
      Incentive storage incentive = incentives[_incentiveIds[i]];

      // If the incentive has expired, exclude it from the sum
      if (incentive.expiresAt != 0 && block.timestamp > incentive.expiresAt) {
        _expiredCount++;
        continue;
      }

      address tokenAddress = address(incentive.token);
      bool found = false;
      for (uint256 j = 0; j < tokenCount; j++) {
        if (tokens[j] == tokenAddress) {
          // Token found, accumulate the amount
          amounts[j] += incentive.amount;
          found = true;
          break;
        }
      }

      // If the token was not found, add it to the tokens array
      if (!found) {
        tokens[tokenCount] = tokenAddress;
        amounts[tokenCount] = incentive.amount;
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

  function _addIncentive(
    uint256 _initiativeId,
    address _token,
    uint256 _amount,
    uint256 _expiresAt,
    Conditions _terms
  ) internal {
    require(registry.isAllowed(_token), 'Token not registered for incentives');
    require(_initiativeId < signalsContract.totalInitiatives(), 'Invalid initiative');

    IERC20 token = IERC20(_token);
    require(token.balanceOf(msg.sender) >= _amount, 'Insufficient balance');
    require(token.allowance(msg.sender, address(this)) >= _amount, 'Insufficient allowance');

    token.safeTransferFrom(msg.sender, address(this), _amount);

    incentives[incentiveCount] = Incentive({
      initiativeId: _initiativeId,
      token: token,
      amount: _amount,
      paid: 0,
      refunded: 0,
      expiresAt: _expiresAt,
      contributor: msg.sender,
      terms: _terms
    });

    // Store the incentive ID in the initiative's list of incentives
    incentivesByInitiative[_initiativeId].push(incentiveCount);

    incentiveCount++;

    emit IncentiveAdded(
      incentiveCount,
      _initiativeId,
      address(_token),
      _amount,
      _expiresAt,
      _terms
    );
  }

  function _refundIncentive(Incentive storage _incentive) internal {
    _incentive.refunded = _incentive.amount;
    balances[_incentive.contributor][address(_incentive.token)] += _incentive.amount;
  }

  function _distributeIncentives(uint256 _initiativeId) internal {
    (address[] memory tokens, uint256[] memory amounts, uint256 expiredCount) = getIncentives(
      _initiativeId
    );

    if (expiredCount > 0) {
      // TODO: Refund expired incentives
    }

    // Iterate through all the tokens for this initiative
    for (uint256 i = 0; i < tokens.length; i++) {
      address token = tokens[i];
      uint256 amount = amounts[i];

      // Update balances for the incentive based on the current splits to the receivers
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
   * @notice Get the potential reward for a supporter for a given initiative.
   *
   * @param _initiativeId The ID of the initiative.
   * @param _supporter The address of the supporter.
   *
   * @return The potential reward amount.
   */
  function getRewards(uint256 _initiativeId, address _supporter) external view returns (uint256) {
    Incentive storage incentive = incentives[_initiativeId];

    uint256 totalWeight = signalsContract.getWeight(_initiativeId);
    if (totalWeight == 0) {
      return 0; // Avoid division by zero
    }

    uint256 supporterWeight = signalsContract.getWeightForSupporterAt(
      _initiativeId,
      _supporter,
      block.timestamp
    );
    if (supporterWeight == 0) {
      return 0; // No rewards for this supporter
    }

    uint256 potentialReward = (incentive.amount * supporterWeight) / totalWeight;
    return potentialReward;
  }

  // Functions to handle notifications from Signals contract
  function handleInitiativeAccepted(uint256 _initiativeId) external nonReentrant {
    require(msg.sender == address(signalsContract), 'Only Signals contract can call this function');

    console.log('Initiative accepted', _initiativeId);
    // Pay out relevant parties
    _distributeIncentives(_initiativeId);
  }

  function handleInitiativeExpired(uint256 _initiativeId) external view {
    require(msg.sender == address(signalsContract), 'Only Signals contract can call this function');
    // Additional logic if needed
    // TODO: Flag any incentives for this initiative as ready to be refunded
    console.log('Initiative expired', _initiativeId);
  }
}
