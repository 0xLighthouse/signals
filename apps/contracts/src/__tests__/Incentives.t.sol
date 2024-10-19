// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/console.sol';
import 'forge-std/StdUtils.sol';
import 'forge-std/mocks/MockERC20.sol';
import '@openzeppelin/contracts/utils/Strings.sol';

import {SignalsFactory} from '../SignalsFactory.sol';
import {Signals} from '../Signals.sol';
import {RewardRegistry} from '../RewardRegistry.sol';
import {Incentives} from '../Incentives.sol';
import {MockStable} from '../__mocks__/MockStable.m.sol';

contract IncentivesTest is Test {
  Incentives _incentives;
  RewardRegistry _registry;
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

    // Initialize RewardRegistry
    _registry = new RewardRegistry();
    vm.prank(_deployer);
    _registry.register(address(_mToken)); // Allow token rewards
    _registry.register(address(_mUSDC)); // Allow usdc rewards


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
  }

  function testInitialState() public view {
    // Ensure the owner is the deployer
    assertEq(Signals(_instance).owner(), address(_alice));
    // Addresses have token and usdc balances
    assertEq(_mToken.balanceOf(_alice), 200_000 * 1e18);
    assertEq(_mUSDC.balanceOf(_alice), 200_000 * 1e6);
    // RewardRegistry has token and usdc registered
    assertEq(_registry.isRegistered(address(_mToken)), true);
    assertEq(_registry.isRegistered(address(_mUSDC)), true);
  }

  function testCreateIncentive() public {
    vm.startPrank(_alice);
    Signals(_instance).proposeInitiative('Initiative 1', 'Description 1');
    
    uint256 initiativeId = 0;
    address rewardToken = address(_mUSDC);
    uint256 amount = 500 * 1e6;
    uint256 expiresAt = 0;
    Incentives.Conditions conditions = Incentives.Conditions.NONE;

    // Add a 500 USDC bounty
    _mUSDC.approve(address(_incentives), amount);

    vm.expectEmit(true, true, true, true);
    emit Incentives.IncentiveAdded(1, initiativeId, rewardToken, amount, expiresAt, conditions);
    _incentives.addIncentive(initiativeId, rewardToken, amount, expiresAt, conditions);
  }

  





  
}
