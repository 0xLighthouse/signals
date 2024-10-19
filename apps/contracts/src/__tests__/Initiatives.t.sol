// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/console.sol';
import 'forge-std/StdUtils.sol';
import 'forge-std/mocks/MockERC20.sol';
import '@openzeppelin/contracts/utils/Strings.sol';

import {SignalsFactory} from '../SignalsFactory.sol';
import {Signals} from '../Signals.sol';

contract InitiativesTest is Test {
  SignalsFactory _factory;
  MockERC20 _someERC20;

  address _deployer;
  address _instance;

  address _alice;
  address _bob;
  address _charlie;

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

    // Deploy MockERC20 token and mint 1 million tokens
    _someERC20 = new MockERC20();
    _someERC20.initialize('MockToken', 'MTK', 18);
    uint256 initialSupply = 1_000_000 * 1e18;
    deal(address(_someERC20), _deployer, initialSupply);

    // Distribute tokens to test addresses
    deal(address(_someERC20), _alice, 200_000 * 1e18);
    deal(address(_someERC20), _bob, 200_000 * 1e18);
    deal(address(_someERC20), _charlie, 40_000 * 1e18);

    // Deploy SignalsFactory with the Signals implementation
    _factory = new SignalsFactory();

    // Ensure the caller is the owner
      vm.prank(_deployer);

    uint256[] memory _decayCurveParameters = new uint256[](1); // 0.9
    _decayCurveParameters[0] = 9e17;

    // Deploy a new Signals contract using the factory
    _instance = _factory.create(
      _alice,
      address(_someERC20),
      _PROPOSAL_THRESHOLD,
      _ACCEPTANCE_THRESHOLD,
      _LOCK_DURATION_CAP,
      _PROPOSAL_CAP,
      _LOCK_INTERVAL,
      _DECAY_CURVE_TYPE,
      _decayCurveParameters
    );
  }

  function testRevertProposeInitiativeWithInsufficientTokens() public {
    // Impersonate Charlie
    vm.startPrank(_charlie);

    string memory title = 'Insufficient Tokens Initiative';
    string memory body = 'This initiative should fail due to insufficient tokens';

    // Approve the contract to spend the tokens
    _someERC20.approve(address(_instance), 40_000);

    Signals instance = Signals(_instance);

    // Charlie has InsufficientTokens, so this should revert
    vm.expectRevert(Signals.InsufficientTokens.selector);
    instance.proposeInitiative(title, body);
  }

  /// @notice Test proposing an initiative with empty title or body
  function testProposeInitiativeWithEmptyTitleOrBody() public {
    vm.startPrank(_alice);

    // Load the Signals contract instance
    Signals instance = Signals(_instance);

    // Attempt to propose with empty title
    vm.expectRevert(
      abi.encodeWithSelector(Signals.InvalidInput.selector, 'Title or body cannot be empty')
    );
    instance.proposeInitiative('', 'Some body');

    // Attempt to propose with empty body
    vm.expectRevert(
      abi.encodeWithSelector(Signals.InvalidInput.selector, 'Title or body cannot be empty')
    );
    instance.proposeInitiative('Some title', '');

    vm.stopPrank();
  }

  /**
   * @notice Test proposing multiple initiatives up to the cap
   *
   *  - TODO: Cap {n} of initiatives proposed in a given period
   *  - TODO: Bonus feature
   *  - TODO: Bonus feature
   *  - TODO: Bonus feature
   */
  // function testProposeMultipleInitiatives() public {
  //   vm.startPrank(alice);

  //   // Load the Signals contract instance
  //   Signals _instance = Signals(instance);

  //   // Propose initiatives up to the cap (5 in this case)
  //   for (uint i = 0; i < 5; i++) {
  //       string memory title = string(abi.encodePacked("Initiative ", Strings.toString(i+1)));
  //       string memory body = string(abi.encodePacked("Description for initiative ", Strings.toString(i+1)));
  //       _instance.proposeInitiative(title, body);
  //   }

  //   // Attempt to propose one more initiative (should fail)
  //   vm.expectRevert(abi.encodeWithSelector(Signals.ProposalCapReached.selector));
  //   _instance.proposeInitiative("Extra Initiative", "This should fail");

  //   vm.stopPrank();
  // }

  function testProposeInitiativeWithLock() public {
    // Bob has enough tokens to propose an initiative with a lock
    vm.prank(_bob);

    // Load the Signals contract instance
    Signals instance = Signals(_instance);

    string memory title = 'Test Proposing Initiative with Locks';
    string memory body = 'This initiative should be proposed with a lock';

    uint256 amountToLock = 100_000 * 1e18;

    console.log('Bob balance:', _someERC20.balanceOf(_bob));
    console.log('Decimals:', _someERC20.decimals());

    // Approve the contract to spend the tokens
    vm.startPrank(_bob);
    _someERC20.approve(address(_instance), amountToLock);
    instance.proposeInitiativeWithLock(title, body, amountToLock, 1);
    vm.stopPrank();

    // Retrieve the initiative and check the details
    Signals.Initiative memory initiative = instance.getInitiative(0);
    assertEq(uint256(initiative.state), uint256(Signals.InitiativeState.Proposed));
    assertEq(initiative.title, title);
    assertEq(initiative.body, body);
    assertEq(address(initiative.proposer), _bob);

    // The weight should be equal to the amount of tokens locked
    uint256 weight = instance.getWeightAt(0, block.timestamp);
    assertEq(weight, amountToLock);
  }
}
