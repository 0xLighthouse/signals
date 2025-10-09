// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {SignalsHarness} from "../utils/SignalsHarness.sol";

import {ISignals} from "../../src/interfaces/ISignals.sol";
import {Signals} from "../../src/Signals.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

/**
 * @title SignalsBoardOpenTimeTest
 * @notice Tests for the board open time feature (fair launch mechanism)
 * @dev Covers board opening time checks, early proposal/support prevention
 */
contract SignalsBoardOpenTimeTest is Test, SignalsHarness {
    Signals signals;
    MockERC20 token;

    /*//////////////////////////////////////////////////////////////
                        BOARD OPENS IMMEDIATELY (DEFAULT)
    //////////////////////////////////////////////////////////////*/

    /// Test board with boardOpensAt = 0 opens immediately
    function test_BoardOpenTime_ZeroAllowsImmediate() public {
        signals = deploySignalsWithBoardOpenTime(0);

        // Should be able to propose immediately (boardOpensAt = 0)
        vm.startPrank(_alice);
        token.approve(address(signals), 100 * 1e18);
        signals.proposeInitiative("Initiative 1", "Description 1");
        vm.stopPrank();

        // Verify initiative was created
        ISignals.Initiative memory initiative = signals.getInitiative(1);
        assertEq(initiative.proposer, _alice);
        assertEq(initiative.title, "Initiative 1");
    }

    /*//////////////////////////////////////////////////////////////
                        BOARD WITH FUTURE OPEN TIME
    //////////////////////////////////////////////////////////////*/

    /// Test proposing before board opens reverts
    function test_BoardOpenTime_ProposeBeforeOpen_Reverts() public {
        // Deploy board that opens 1 hour from now
        uint256 futureOpenTime = block.timestamp + 1 hours;
        signals = deploySignalsWithBoardOpenTime(futureOpenTime);

        // Try to propose before board opens - should revert
        vm.startPrank(_alice);
        token.approve(address(signals), 100 * 1e18);

        vm.expectRevert(ISignals.BoardNotYetOpen.selector);
        signals.proposeInitiative("Early Initiative", "Should fail");
        vm.stopPrank();
    }

    /// Test supporting before board opens reverts
    function test_BoardOpenTime_SupportBeforeOpen_Reverts() public {
        // Deploy board that opens 2 hours from now
        uint256 futureOpenTime = block.timestamp + 2 hours;
        signals = deploySignalsWithBoardOpenTime(futureOpenTime);

        // Fast forward to after board opens and create an initiative as Alice
        vm.warp(futureOpenTime);
        vm.startPrank(_alice);
        token.approve(address(signals), 100 * 1e18);
        signals.proposeInitiative("Initiative 1", "Description 1");
        vm.stopPrank();

        // Deploy a NEW board that opens 1 hour from NOW (current time)
        uint256 newOpenTime = block.timestamp + 1 hours;
        Signals newSignals = deploySignalsWithBoardOpenTime(newOpenTime);

        // Try to support the new board before it opens - should revert
        vm.startPrank(_bob);
        token.approve(address(newSignals), 150 * 1e18);

        vm.expectRevert(ISignals.BoardNotYetOpen.selector);
        newSignals.proposeInitiative("Should fail", "Board not open yet");
        vm.stopPrank();
    }

    /// Test proposing after board opens succeeds
    function test_BoardOpenTime_ProposeAfterOpen_Succeeds() public {
        // Deploy board that opens 1 hour from now
        uint256 futureOpenTime = block.timestamp + 1 hours;
        signals = deploySignalsWithBoardOpenTime(futureOpenTime);

        // Fast forward to after board opens
        vm.warp(futureOpenTime);

        // Should be able to propose now
        vm.startPrank(_alice);
        token.approve(address(signals), 100 * 1e18);
        signals.proposeInitiative("Initiative 1", "Description 1");
        vm.stopPrank();

        // Verify initiative was created
        ISignals.Initiative memory initiative = signals.getInitiative(1);
        assertEq(initiative.proposer, _alice);
        assertEq(initiative.title, "Initiative 1");
    }

    /// Test supporting after board opens succeeds
    function test_BoardOpenTime_SupportAfterOpen_Succeeds() public {
        // Deploy board that opens 1 hour from now
        uint256 futureOpenTime = block.timestamp + 1 hours;
        signals = deploySignalsWithBoardOpenTime(futureOpenTime);

        // Fast forward to after board opens
        vm.warp(futureOpenTime);

        // Create an initiative
        vm.startPrank(_alice);
        token.approve(address(signals), 100 * 1e18);
        signals.proposeInitiative("Initiative 1", "Description 1");
        vm.stopPrank();

        // Support should succeed
        vm.startPrank(_bob);
        token.approve(address(signals), 150 * 1e18);
        signals.supportInitiative(1, 150 * 1e18, 6);
        vm.stopPrank();

        // Verify support was recorded
        ISignals.TokenLock memory lock = signals.getTokenLock(1);
        assertEq(lock.tokenAmount, 150 * 1e18);
        assertEq(lock.lockDuration, 6);
    }

    /// Test proposeInitiativeWithLock before board opens reverts
    function test_BoardOpenTime_ProposeWithLockBeforeOpen_Reverts() public {
        // Deploy board that opens 1 hour from now
        uint256 futureOpenTime = block.timestamp + 1 hours;
        signals = deploySignalsWithBoardOpenTime(futureOpenTime);

        // Try to propose with lock before board opens - should revert
        vm.startPrank(_alice);
        token.approve(address(signals), 200 * 1e18);

        vm.expectRevert(ISignals.BoardNotYetOpen.selector);
        signals.proposeInitiativeWithLock("Early Initiative", "Should fail", 100 * 1e18, 10);
        vm.stopPrank();
    }

    /// Test proposeInitiativeWithLock after board opens succeeds
    function test_BoardOpenTime_ProposeWithLockAfterOpen_Succeeds() public {
        // Deploy board that opens 1 hour from now
        uint256 futureOpenTime = block.timestamp + 1 hours;
        signals = deploySignalsWithBoardOpenTime(futureOpenTime);

        // Fast forward to after board opens
        vm.warp(futureOpenTime);

        // Should be able to propose with lock now
        vm.startPrank(_alice);
        token.approve(address(signals), 200 * 1e18);
        uint256 tokenId = signals.proposeInitiativeWithLock("Initiative 1", "Description 1", 100 * 1e18, 10);
        vm.stopPrank();

        // Verify initiative was created with lock
        ISignals.Initiative memory initiative = signals.getInitiative(1);
        assertEq(initiative.proposer, _alice);

        ISignals.TokenLock memory lock = signals.getTokenLock(tokenId);
        assertEq(lock.tokenAmount, 100 * 1e18);
        assertEq(lock.lockDuration, 10);
    }

    /// Test boardOpensAt getter returns correct value
    function test_BoardOpenTime_Getter() public {
        uint256 futureOpenTime = block.timestamp + 2 hours;
        signals = deploySignalsWithBoardOpenTime(futureOpenTime);

        uint256 actualOpenTime = signals.boardOpensAt();
        assertEq(actualOpenTime, futureOpenTime);
    }

    /*//////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// Helper to deploy Signals with specific boardOpensAt
    function deploySignalsWithBoardOpenTime(uint256 openTime) internal returns (Signals) {
        // Create a new token for this test
        token = new MockERC20("TestToken", "TEST", 18);

        // Mint tokens to test addresses
        token.mint(_alice, 1_000_000 * 1e18);
        token.mint(_bob, 1_000_000 * 1e18);
        token.mint(_charlie, 1_000_000 * 1e18);

        // Create config with custom boardOpensAt
        uint256[] memory params = new uint256[](1);
        params[0] = 9e17;

        ISignals.BoardConfig memory config = ISignals.BoardConfig({
            version: "1.0.0",
            owner: _deployer,
            underlyingToken: address(token),
            acceptanceThreshold: 100_000 * 1e18,
            maxLockIntervals: 365,
            proposalCap: 100,
            lockInterval: 1 days,
            decayCurveType: 0,
            decayCurveParameters: params,
            proposerRequirements: ISignals.ProposerRequirements({
                eligibilityType: ISignals.EligibilityType.None,
                minBalance: 0,
                minHoldingDuration: 0,
                threshold: 50_000 * 1e18
            }),
            participantRequirements: ISignals.ParticipantRequirements({
                eligibilityType: ISignals.EligibilityType.None,
                minBalance: 0,
                minHoldingDuration: 0
            }),
            releaseLockDuration: 0,
            boardOpensAt: openTime
        });

        // Deploy and initialize
        Signals newSignals = new Signals();
        newSignals.initialize(config);

        return newSignals;
    }
}
