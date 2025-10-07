// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {SignalsHarness} from "../utils/SignalsHarness.sol";

import {ISignals} from "../../src/interfaces/ISignals.sol";
import {ISignalsFactory} from "../../src/interfaces/ISignalsFactory.sol";
import {Signals} from "../../src/Signals.sol";

/**
 * @title SignalsGovernanceTokenTest
 * @notice Tests for creating Signals boards with ERC20Votes (Governor-style) tokens
 * @dev Verifies that boards work with tokens that have checkpoint/voting capabilities
 */
contract SignalsGovernanceTokenTest is Test, SignalsHarness {
    Signals signals;

    function setUp() public {
        // Deploy signals with ERC20Votes token config
        ISignals.SignalsConfig memory config = getERC20VotesConfig();
        signals = new Signals();
        signals.initialize(config);

        // Deal and delegate ERC20Votes tokens
        _dealAndDelegateERC20Votes();
    }

    /*//////////////////////////////////////////////////////////////
                        INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Initialize_WithERC20Votes() public view {
        assertEq(signals.underlyingToken(), address(_tokenERC20Votes));
        assertEq(signals.proposalThreshold(), 50_000 * 1e18);
        assertEq(signals.acceptanceThreshold(), 100_000 * 1e18);
    }

    function test_ERC20Votes_HasCheckpoints() public view {
        // Verify ERC20Votes token supports voting
        assertEq(_tokenERC20Votes.getVotes(_alice), 50_000 * 1e18);
        assertEq(_tokenERC20Votes.getVotes(_bob), 100_000 * 1e18);
        assertEq(_tokenERC20Votes.getVotes(_charlie), 25_000 * 1e18);
    }

    /*//////////////////////////////////////////////////////////////
                        PROPOSAL TESTS WITH GOVERNANCE TOKEN
    //////////////////////////////////////////////////////////////*/

    function test_Propose_WithERC20Votes() public {
        vm.startPrank(_alice);
        _tokenERC20Votes.approve(address(signals), 50_000 * 1e18);

        signals.proposeInitiative("Initiative 1", "Test with ERC20Votes token");

        ISignals.Initiative memory initiative = signals.getInitiative(1);
        assertEq(initiative.title, "Initiative 1");
        assertEq(initiative.proposer, _alice);
        vm.stopPrank();
    }

    function test_ProposeWithLock_WithERC20Votes() public {
        vm.startPrank(_bob);
        _tokenERC20Votes.approve(address(signals), 100_000 * 1e18);

        uint256 tokenId = signals.proposeInitiativeWithLock(
            "Initiative 1",
            "Test with governance token",
            50_000 * 1e18,
            6
        );

        assertEq(tokenId, 1);
        assertEq(signals.ownerOf(1), _bob);

        ISignals.TokenLock memory lock = signals.getTokenLock(1);
        assertEq(lock.tokenAmount, 50_000 * 1e18);
        assertEq(lock.lockDuration, 6);

        vm.stopPrank();
    }

    function test_Support_WithERC20Votes() public {
        // Alice proposes
        vm.startPrank(_alice);
        _tokenERC20Votes.approve(address(signals), 50_000 * 1e18);
        signals.proposeInitiative("Initiative 1", "Description");
        vm.stopPrank();

        // Bob supports
        vm.startPrank(_bob);
        _tokenERC20Votes.approve(address(signals), 75_000 * 1e18);
        uint256 tokenId = signals.supportInitiative(1, 75_000 * 1e18, 6);

        assertEq(tokenId, 1);
        assertEq(signals.ownerOf(1), _bob);

        ISignals.TokenLock memory lock = signals.getTokenLock(1);
        assertEq(lock.tokenAmount, 75_000 * 1e18);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        REDEMPTION TESTS WITH GOVERNANCE TOKEN
    //////////////////////////////////////////////////////////////*/

    function test_Redeem_WithGovernanceToken() public {
        // Bob proposes with lock
        vm.startPrank(_bob);
        _tokenERC20Votes.approve(address(signals), 60_000 * 1e18);
        signals.proposeInitiativeWithLock("Initiative 1", "Description", 60_000 * 1e18, 6);
        vm.stopPrank();

        // Accept initiative
        vm.prank(_deployer);
        signals.acceptInitiative(1);

        // Redeem
        vm.startPrank(_bob);
        uint256 balanceBefore = _tokenERC20Votes.balanceOf(_bob);
        signals.redeem(1);
        uint256 balanceAfter = _tokenERC20Votes.balanceOf(_bob);

        assertEq(balanceAfter - balanceBefore, 60_000 * 1e18);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        CHECKPOINT VERIFICATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GovernanceToken_VotingPowerDecreasesWhenLocked() public {
        // Alice starts with 50k voting power
        assertEq(_tokenERC20Votes.getVotes(_alice), 50_000 * 1e18);
        assertEq(_tokenERC20Votes.balanceOf(_alice), 50_000 * 1e18);

        // Alice locks tokens
        vm.startPrank(_alice);
        _tokenERC20Votes.approve(address(signals), 30_000 * 1e18);
        signals.proposeInitiativeWithLock("Initiative 1", "Description", 30_000 * 1e18, 6);
        vm.stopPrank();

        // Alice now has reduced voting power (tokens transferred out)
        assertEq(_tokenERC20Votes.balanceOf(_alice), 20_000 * 1e18);
        assertEq(_tokenERC20Votes.getVotes(_alice), 20_000 * 1e18);

        // The Signals contract holds the tokens but has no voting power (not delegated)
        assertEq(_tokenERC20Votes.balanceOf(address(signals)), 30_000 * 1e18);
        assertEq(_tokenERC20Votes.getVotes(address(signals)), 0);
    }

    function test_GovernanceToken_SupportsHistoricalQueries() public {
        // Capture initial state
        vm.roll(block.number + 10);
        uint256 initialBlock = block.number - 1;
        uint256 initialVotes = _tokenERC20Votes.getPastVotes(_alice, initialBlock);

        // Alice locks some tokens
        vm.startPrank(_alice);
        _tokenERC20Votes.approve(address(signals), 20_000 * 1e18);
        signals.proposeInitiativeWithLock("Initiative 1", "Description", 20_000 * 1e18, 6);
        vm.stopPrank();

        // Advance blocks
        vm.roll(block.number + 10);

        // Current voting power is reduced
        uint256 currentVotes = _tokenERC20Votes.getVotes(_alice);
        assertEq(currentVotes, 30_000 * 1e18);

        // But we can still query historical votes
        uint256 historicalVotes = _tokenERC20Votes.getPastVotes(_alice, initialBlock);
        assertEq(historicalVotes, initialVotes); // Should equal initial votes

        // This proves checkpoints are working
        assertTrue(historicalVotes > currentVotes);
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_FullLifecycle_WithGovernanceToken() public {
        // 1. Alice proposes with lock
        vm.startPrank(_alice);
        _tokenERC20Votes.approve(address(signals), 40_000 * 1e18);
        uint256 tokenId1 = signals.proposeInitiativeWithLock(
            "Initiative 1",
            "Full lifecycle test",
            40_000 * 1e18,
            12
        );
        vm.stopPrank();

        // 2. Bob supports
        vm.startPrank(_bob);
        _tokenERC20Votes.approve(address(signals), 50_000 * 1e18);
        uint256 tokenId2 = signals.supportInitiative(1, 50_000 * 1e18, 12);
        vm.stopPrank();

        // 3. Accept initiative
        vm.prank(_deployer);
        signals.acceptInitiative(1);

        // 4. Alice redeems
        vm.startPrank(_alice);
        uint256 aliceBalanceBefore = _tokenERC20Votes.balanceOf(_alice);
        signals.redeem(tokenId1);
        uint256 aliceBalanceAfter = _tokenERC20Votes.balanceOf(_alice);
        assertEq(aliceBalanceAfter - aliceBalanceBefore, 40_000 * 1e18);
        vm.stopPrank();

        // 5. Bob redeems
        vm.startPrank(_bob);
        uint256 bobBalanceBefore = _tokenERC20Votes.balanceOf(_bob);
        signals.redeem(tokenId2);
        uint256 bobBalanceAfter = _tokenERC20Votes.balanceOf(_bob);
        assertEq(bobBalanceAfter - bobBalanceBefore, 50_000 * 1e18);
        vm.stopPrank();

        // 6. Verify final state
        ISignals.Initiative memory initiative = signals.getInitiative(1);
        assertEq(uint256(initiative.state), uint256(ISignals.InitiativeState.Accepted));
    }

    /*//////////////////////////////////////////////////////////////
                        FACTORY DEPLOYMENT WITH GOVERNANCE TOKEN
    //////////////////////////////////////////////////////////////*/

    function test_Factory_DeployWithGovernanceToken() public {
        // Create factory deployment config
        ISignalsFactory.FactoryDeployment memory factoryConfig = ISignalsFactory.FactoryDeployment({
            owner: _deployer,
            underlyingToken: address(_tokenERC20Votes),
            proposalThreshold: 50_000 * 1e18,
            acceptanceThreshold: 100_000 * 1e18,
            maxLockIntervals: 365 days,
            proposalCap: 100,
            lockInterval: 1 days,
            decayCurveType: 0,
            decayCurveParameters: new uint256[](1),
            proposalRequirements: ISignals.ProposalRequirements({
                requirementType: ISignals.ProposalRequirementType.None,
                minBalance: 0,
                minHoldingDuration: 0
            })
        });

        address instance = factory.create(factoryConfig);
        Signals deployedSignals = Signals(instance);

        assertEq(deployedSignals.underlyingToken(), address(_tokenERC20Votes));
        assertEq(deployedSignals.proposalThreshold(), 50_000 * 1e18);
        assertEq(deployedSignals.owner(), _deployer);
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GovernanceToken_WithoutDelegation() public {
        // Create a new governance token board
        ISignals.SignalsConfig memory config = getERC20VotesConfig();
        Signals newSignals = new Signals();
        newSignals.initialize(config);

        // Mint tokens to new user without delegation
        address newUser = address(0x9999);
        _tokenERC20Votes.mint(newUser, 100_000 * 1e18);

        // User has balance but NO voting power (not delegated)
        assertEq(_tokenERC20Votes.balanceOf(newUser), 100_000 * 1e18);
        assertEq(_tokenERC20Votes.getVotes(newUser), 0);

        // User CAN still propose (proposalThreshold checks balance, not votes)
        vm.startPrank(newUser);
        _tokenERC20Votes.approve(address(newSignals), 100_000 * 1e18);
        newSignals.proposeInitiative("Test", "Works without delegation");
        vm.stopPrank();
    }

    function test_GovernanceToken_TransferDoesNotAffectLocks() public {
        // Alice locks tokens
        vm.startPrank(_alice);
        _tokenERC20Votes.approve(address(signals), 30_000 * 1e18);
        uint256 tokenId = signals.proposeInitiativeWithLock(
            "Initiative 1",
            "Description",
            30_000 * 1e18,
            6
        );
        vm.stopPrank();

        // Alice transfers remaining balance to someone else
        vm.prank(_alice);
        _tokenERC20Votes.transfer(address(0x8888), 20_000 * 1e18);

        // Lock is still valid and owned by Alice
        assertEq(signals.ownerOf(tokenId), _alice);

        ISignals.TokenLock memory lock = signals.getTokenLock(tokenId);
        assertEq(lock.tokenAmount, 30_000 * 1e18);
        assertEq(lock.withdrawn, false);
    }
}
