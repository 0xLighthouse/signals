// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import 'forge-std/Test.sol';
import 'forge-std/StdUtils.sol';
import 'forge-std/mocks/MockERC20.sol';
import '@openzeppelin/contracts/utils/Strings.sol';

import {SignalsFactory} from '../SignalsFactory.sol';
import {Signals} from '../Signals.sol';
import {TokenRegistry} from '../TokenRegistry.sol';
import {Incentives} from '../Incentives.sol';
import {MockStable} from '../__mocks__/MockStable.m.sol';

contract IncentivesTest is Test {
  Incentives _incentives;
  TokenRegistry _registry;
  SignalsFactory _factory;
  MockERC20 _mToken;
  MockStable _mUSDC;

  address _deployer;
  address _instance;

  address _alice;
  address _bob;
  address _charlie;

  address _feesAddress;
  address _votersAddress;
  address _treasuryAddress;

  // Parameters
  uint256 constant _PROPOSAL_THRESHOLD = 50_000 * 1e18; // 50k
  uint256 constant _ACCEPTANCE_THRESHOLD = 100_000 * 1e18; // 100k
  uint256 constant _LOCK_DURATION_CAP = 365 days; // 1 year
  uint256 constant _PROPOSAL_CAP = 100; // 100 proposals
  uint256 constant _LOCK_INTERVAL = 1 days; // 1 day
  uint256 constant _DECAY_CURVE_TYPE = 0; // Linear

  function setUp() public {
    _deployer = address(this);
    _alice = address(0x1111);
    _bob = address(0x2222);
    _charlie = address(0x3333);

    _feesAddress = address(0x4444);
    _votersAddress = address(0x5555);
    _treasuryAddress = address(0x6666);

    // Deploy MockERC20 token and mint 1 million tokens
    _mToken = new MockERC20();
    _mToken.initialize('MockToken', 'MTK', 18);
    uint256 initialSupply = 1_000_000 * 1e18;
    deal(address(_mToken), _deployer, initialSupply);

    _mUSDC = new MockStable('MockUSDC', 'MUSDC');
    _mUSDC.initialize(1_000_000 * 1e6);
    deal(address(_mUSDC), _deployer, initialSupply);

    // Distribute tokens to test addresses
    deal(address(_mToken), _alice, 200_000 * 1e18);
    deal(address(_mToken), _bob, 200_000 * 1e18);
    deal(address(_mToken), _charlie, 40_000 * 1e18);

    // Distribute some mocked USDC to the test addresses
    deal(address(_mUSDC), _alice, 200_000 * 1e6);
    deal(address(_mUSDC), _bob, 200_000 * 1e6);
    deal(address(_mUSDC), _charlie, 40_000 * 1e6);

    // Deploy SignalsFactory with the Signals implementation
    _factory = new SignalsFactory();

    // Ensure the caller is the owner
    vm.prank(_deployer);

    uint256[] memory _decayCurveParameters = new uint256[](1); // 0.9
    _decayCurveParameters[0] = 9e17;

    // Deploy a new Signals contract using the factory
    _instance = _factory.create(
      _alice,
      address(_mToken),
      _PROPOSAL_THRESHOLD,
      _ACCEPTANCE_THRESHOLD,
      _LOCK_DURATION_CAP,
      _PROPOSAL_CAP,
      _LOCK_INTERVAL,
      _DECAY_CURVE_TYPE,
      _decayCurveParameters
    );

    // Initialize TokenRegistry
    _registry = new TokenRegistry();
    vm.prank(_deployer);
    _registry.allow(address(_mToken)); // Allow token rewards
    _registry.allow(address(_mUSDC)); // Allow usdc rewards


    // Create incentives
    uint256[3] memory _allocations = [uint256(5), uint256(20), uint256(75)];
    address[3] memory _receivers = [address(_feesAddress), address(_votersAddress), address(_treasuryAddress)];

    // Create a new Incentives contract bound to the Signals instance and Token Registry
    _incentives = new Incentives(
        address(_instance),
        address(_registry),
        _allocations,
        _receivers
    );

    // Set the Incentives contract in the Signals contract
    vm.prank(_alice);
    Signals(_instance).setIncentives(address(_incentives));
  }

  function testInitialState() public view {
    // Ensure the owner is the deployer
    assertEq(Signals(_instance).owner(), address(_alice));
    // Addresses have token and usdc balances
    assertEq(_mToken.balanceOf(_alice), 200_000 * 1e18);
    assertEq(_mUSDC.balanceOf(_alice), 200_000 * 1e6);
    // TokenRegistry has token and usdc registered
    assertEq(_registry.isAllowed(address(_mToken)), true);
    assertEq(_registry.isAllowed(address(_mUSDC)), true);
  }

  function testAddIncentive() public {
    vm.startPrank(_alice);
    Signals(_instance).proposeInitiative('Initiative 1', 'Description 1');

    uint256 initiativeId = 0;
    address rewardToken = address(_mUSDC);
    uint256 amount = 500 * 1e6;
    uint256 expiresAt = 0;
    Incentives.Conditions conditions = Incentives.Conditions.NONE;

    // Add a 2k USDC bounty
    _mUSDC.approve(address(_incentives), amount * 4);

    // Add 4 incentives
    for (uint256 i = 1; i <= 4; i++) {
        vm.expectEmit();
        emit Incentives.IncentiveAdded(i, initiativeId, rewardToken, amount, expiresAt, conditions);
        _incentives.addIncentive(initiativeId, rewardToken, amount, expiresAt, conditions);
    }

    (address[] memory tokens, uint256[] memory amounts, uint256 expiredCount) = _incentives.getIncentives(initiativeId);

    assertEq(tokens.length, 1);
    assertEq(tokens[0], rewardToken);
    assertEq(amounts[0], amount * 4);
    assertEq(expiredCount, 0);
  }











}
