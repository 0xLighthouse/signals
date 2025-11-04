// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {SignalsHarness} from "../utils/SignalsHarness.sol";

import {ISignals} from "../../src/interfaces/ISignals.sol";
import {Signals} from "../../src/Signals.sol";

/**
 * @title SignalsBoardOpenTimeTest
 * @notice Tests for the board open time feature (fair launch mechanism)
 * @dev Covers board opening time checks, early proposal/support prevention
 */
contract SignalsBoardOpenTimeTest is Test, SignalsHarness {
    Signals signals;

    /*//////////////////////////////////////////////////////////////
                        BOARD DOES NOT OPEN IMMEDIATELY
    //////////////////////////////////////////////////////////////*/

    /// Test board with boardOpensAt = 0 stays closed until opened
    function test_BoardOpenTime_ZeroAllowsImmediate() public {
        signals = deploySignalsWithBoardOpenTime(0, 0);

        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), 100 ether);

        vm.expectRevert(ISignals.Signals_IncorrectBoardState.selector);
        signals.proposeInitiative("Initiative 1", "Description 1", new ISignals.Attachment[](0));

        vm.warp(block.timestamp + 720 days);
        vm.expectRevert(ISignals.Signals_IncorrectBoardState.selector);
        signals.proposeInitiative("Initiative 1", "Description 1", new ISignals.Attachment[](0));
        vm.stopPrank();

        signals.setBoardOpenAt(block.timestamp);
        vm.prank(_alice);
        signals.proposeInitiative("Initiative 1", "Description 1", new ISignals.Attachment[](0));
    }

    /*//////////////////////////////////////////////////////////////
                        BOARD WITH FUTURE OPEN TIME
    //////////////////////////////////////////////////////////////*/

    /// Test proposing before board opens reverts
    function test_BoardOpenTime_ProposeBeforeOpen_Reverts() public {
        // Deploy board that opens 1 hour from now
        uint256 futureOpenTime = block.timestamp + 1 hours;
        signals = deploySignalsWithBoardOpenTime(futureOpenTime, 0);

        // Try to propose before board opens - should revert
        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), 100 ether);

        vm.expectRevert(ISignals.Signals_IncorrectBoardState.selector);
        signals.proposeInitiative("Early Initiative", "Should fail", new ISignals.Attachment[](0));
        vm.stopPrank();
    }

    /// Test proposing after board opens succeeds
    function test_BoardOpenTime_ProposeAndSupportAfterOpen_Succeeds() public {
        // Deploy board that opens 1 hour from now
        uint256 futureOpenTime = block.timestamp + 1 hours;
        signals = deploySignalsWithBoardOpenTime(futureOpenTime, 0);

        // Fast forward to after board opens
        vm.warp(futureOpenTime);

        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), 100 ether);
        signals.proposeInitiative("Initiative 1", "Description 1", new ISignals.Attachment[](0));
        vm.stopPrank();

        // Support should also succeed
        vm.startPrank(_bob);
        _tokenERC20.approve(address(signals), 150 ether);
        signals.supportInitiative(1, 150 ether, 6);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        BOARD CLOSING TESTS
    //////////////////////////////////////////////////////////////*/

    /// Test board closing via boardClosedAt time
    function test_BoardClosedTime_BlocksProposalsAndSupport() public {
        // Deploy board that opens immediately and closes in 2 hours
        uint256 openTime = block.timestamp;
        uint256 closeTime = block.timestamp + 2 hours;
        signals = deploySignalsWithBoardOpenTime(openTime, closeTime);

        // Alice proposes initiative (before close time)
        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), 200 ether);
        signals.proposeInitiative("Initiative 1", "Description 1", new ISignals.Attachment[](0));
        vm.stopPrank();

        // Bob supports initiative (before close time)
        vm.startPrank(_bob);
        _tokenERC20.approve(address(signals), 150 ether);
        signals.supportInitiative(1, 150 ether, 6);
        vm.stopPrank();

        // Fast forward to close time
        vm.warp(closeTime);

        // Alice tries to propose new initiative (after close time) - should revert
        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), 100 ether);
        vm.expectRevert(ISignals.Signals_IncorrectBoardState.selector);
        signals.proposeInitiative("Initiative 2", "Should fail", new ISignals.Attachment[](0));
        vm.stopPrank();

        // Charlie tries to support existing initiative (after close time) - should revert
        vm.startPrank(_charlie);
        _tokenERC20.approve(address(signals), 50 ether);
        vm.expectRevert(ISignals.Signals_IncorrectBoardState.selector);
        signals.supportInitiative(1, 50 ether, 6);
        vm.stopPrank();
    }

    /// Test board closing via closeBoard() function
    function test_CloseBoard_BlocksProposalsAndSupport() public {
        // Deploy board that opens immediately and never closes (boardClosedAt = 0)
        uint256 openTime = block.timestamp;
        signals = deploySignalsWithBoardOpenTime(openTime, 0);

        // Alice proposes initiative
        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), 200 ether);
        signals.proposeInitiative("Initiative 1", "Description 1", new ISignals.Attachment[](0));
        vm.stopPrank();

        // Bob supports initiative
        vm.startPrank(_bob);
        _tokenERC20.approve(address(signals), 150 ether);
        signals.supportInitiative(1, 150 ether, 6);
        vm.stopPrank();

        // Owner closes the board
        vm.prank(_deployer);
        signals.closeBoard();

        // Alice tries to propose new initiative (after board closed) - should revert
        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), 100 ether);
        vm.expectRevert(ISignals.Signals_IncorrectBoardState.selector);
        signals.proposeInitiative("Initiative 2", "Should fail", new ISignals.Attachment[](0));
        vm.stopPrank();

        // Charlie tries to support existing initiative (after board closed) - should revert
        vm.startPrank(_charlie);
        _tokenERC20.approve(address(signals), 50 ether);
        vm.expectRevert(ISignals.Signals_IncorrectBoardState.selector);
        signals.supportInitiative(1, 50 ether, 6);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        BOARD CANCELLATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// Test successfully cancelling an open board
    function test_CancelBoard_Success() public {
        // Deploy board that opens immediately
        uint256 openTime = block.timestamp;
        signals = deploySignalsWithBoardOpenTime(openTime, 0);

        // Verify board is open
        assertTrue(signals.isBoardOpen(), "Board should be open");
        assertFalse(signals.boardCancelled(), "Board should not be cancelled initially");

        // Record timestamp before cancellation
        uint256 timeBeforeCancel = block.timestamp;

        // Owner cancels the board
        vm.expectEmit(true, false, false, false);
        emit ISignals.BoardCancelled(_deployer);
        vm.prank(_deployer);
        signals.cancelBoard();

        // Verify board state after cancellation
        assertTrue(signals.boardCancelled(), "Board should be marked as cancelled");
        assertFalse(signals.isBoardOpen(), "Board should not be open after cancellation");
        assertTrue(signals.isBoardClosed(), "Board should be closed after cancellation");
        assertEq(signals.boardClosedAt(), timeBeforeCancel, "boardClosedAt should be set to cancellation time");
    }

    /// Test that proposals are blocked after board cancellation
    function test_CancelBoard_BlocksProposals() public {
        // Deploy board that opens immediately
        uint256 openTime = block.timestamp;
        signals = deploySignalsWithBoardOpenTime(openTime, 0);

        // Alice proposes an initiative before cancellation
        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), 200 ether);
        signals.proposeInitiative("Initiative 1", "Description 1", new ISignals.Attachment[](0));
        vm.stopPrank();

        // Owner cancels the board
        vm.prank(_deployer);
        signals.cancelBoard();

        // Alice tries to propose new initiative after cancellation - should revert
        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), 100 ether);
        vm.expectRevert(ISignals.Signals_IncorrectBoardState.selector);
        signals.proposeInitiative("Initiative 2", "Should fail", new ISignals.Attachment[](0));
        vm.stopPrank();
    }

    /// Test that support is blocked after board cancellation
    function test_CancelBoard_BlocksSupport() public {
        // Deploy board that opens immediately
        uint256 openTime = block.timestamp;
        signals = deploySignalsWithBoardOpenTime(openTime, 0);

        // Alice proposes an initiative before cancellation
        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), 200 ether);
        signals.proposeInitiative("Initiative 1", "Description 1", new ISignals.Attachment[](0));
        vm.stopPrank();

        // Bob supports before cancellation
        vm.startPrank(_bob);
        _tokenERC20.approve(address(signals), 150 ether);
        signals.supportInitiative(1, 150 ether, 6);
        vm.stopPrank();

        // Owner cancels the board
        vm.prank(_deployer);
        signals.cancelBoard();

        // Charlie tries to support existing initiative after cancellation - should revert
        vm.startPrank(_charlie);
        _tokenERC20.approve(address(signals), 50 ether);
        vm.expectRevert(ISignals.Signals_IncorrectBoardState.selector);
        signals.supportInitiative(1, 50 ether, 6);
        vm.stopPrank();
    }

    /// Test that only owner can cancel the board
    function test_CancelBoard_OnlyOwner() public {
        // Deploy board that opens immediately
        uint256 openTime = block.timestamp;
        signals = deploySignalsWithBoardOpenTime(openTime, 0);

        // Alice (non-owner) tries to cancel the board - should revert
        vm.expectRevert();
        vm.prank(_alice);
        signals.cancelBoard();

        // Verify board is still open
        assertTrue(signals.isBoardOpen(), "Board should still be open");
        assertFalse(signals.boardCancelled(), "Board should not be cancelled");

        // Owner can successfully cancel
        vm.prank(_deployer);
        signals.cancelBoard();
        assertTrue(signals.boardCancelled(), "Board should be cancelled by owner");
    }

    /// Test that board can only be cancelled when open
    function test_CancelBoard_RequiresBoardOpen() public {
        // Deploy board that hasn't opened yet
        uint256 futureOpenTime = block.timestamp + 1 hours;
        signals = deploySignalsWithBoardOpenTime(futureOpenTime, 0);

        // Try to cancel before board opens - should revert
        vm.expectRevert(ISignals.Signals_IncorrectBoardState.selector);
        vm.prank(_deployer);
        signals.cancelBoard();

        // Warp to when board is open
        vm.warp(futureOpenTime);

        // Now cancellation should succeed
        vm.prank(_deployer);
        signals.cancelBoard();
        assertTrue(signals.boardCancelled(), "Board should be cancelled");
    }

    /// Test that board cannot be cancelled twice
    function test_CancelBoard_CannotCancelTwice() public {
        // Deploy board that opens immediately
        uint256 openTime = block.timestamp;
        signals = deploySignalsWithBoardOpenTime(openTime, 0);

        // Owner cancels the board first time
        vm.prank(_deployer);
        signals.cancelBoard();
        assertTrue(signals.boardCancelled(), "Board should be cancelled");

        // Try to cancel again - should revert because board is no longer open
        vm.expectRevert(ISignals.Signals_IncorrectBoardState.selector);
        vm.prank(_deployer);
        signals.cancelBoard();
    }

    /// Test that board cannot be cancelled after it has naturally closed
    function test_CancelBoard_CannotCancelClosedBoard() public {
        // Deploy board that opens immediately and closes in 1 hour
        uint256 openTime = block.timestamp;
        uint256 closeTime = block.timestamp + 1 hours;
        signals = deploySignalsWithBoardOpenTime(openTime, closeTime);

        // Warp past close time
        vm.warp(closeTime);

        // Try to cancel after board is already closed - should revert
        vm.expectRevert(ISignals.Signals_IncorrectBoardState.selector);
        vm.prank(_deployer);
        signals.cancelBoard();
    }

    /*//////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// Helper to deploy Signals with specific boardOpensAt
    function deploySignalsWithBoardOpenTime(uint256 openTime, uint256 closeTime)
        internal
        returns (Signals)
    {
        ISignals.BoardConfig memory config = defaultConfig;
        config.boardOpenAt = openTime;
        config.boardClosedAt = closeTime;
        Signals newSignals = new Signals();
        newSignals.initialize(config);

        dealMockTokens();
        return newSignals;
    }
}
