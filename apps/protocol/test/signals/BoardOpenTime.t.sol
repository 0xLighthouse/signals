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

        vm.expectRevert(ISignals.Signals_BoardNotOpen.selector);
        signals.proposeInitiative("Initiative 1", "Description 1");

        vm.warp(block.timestamp + 720 days);
        vm.expectRevert(ISignals.Signals_BoardNotOpen.selector);
        signals.proposeInitiative("Initiative 1", "Description 1");
        vm.stopPrank();

        signals.setBoardOpenAt(block.timestamp);
        vm.prank(_alice);
        signals.proposeInitiative("Initiative 1", "Description 1");
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

        vm.expectRevert(ISignals.Signals_BoardNotOpen.selector);
        signals.proposeInitiative("Early Initiative", "Should fail");
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
        signals.proposeInitiative("Initiative 1", "Description 1");
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
        signals.proposeInitiative("Initiative 1", "Description 1");
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
        vm.expectRevert(ISignals.Signals_BoardNotOpen.selector);
        signals.proposeInitiative("Initiative 2", "Should fail");
        vm.stopPrank();

        // Charlie tries to support existing initiative (after close time) - should revert
        vm.startPrank(_charlie);
        _tokenERC20.approve(address(signals), 50 ether);
        vm.expectRevert(ISignals.Signals_BoardNotOpen.selector);
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
        signals.proposeInitiative("Initiative 1", "Description 1");
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
        vm.expectRevert(ISignals.Signals_BoardNotOpen.selector);
        signals.proposeInitiative("Initiative 2", "Should fail");
        vm.stopPrank();

        // Charlie tries to support existing initiative (after board closed) - should revert
        vm.startPrank(_charlie);
        _tokenERC20.approve(address(signals), 50 ether);
        vm.expectRevert(ISignals.Signals_BoardNotOpen.selector);
        signals.supportInitiative(1, 50 ether, 6);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// Helper to deploy Signals with specific boardOpensAt
    function deploySignalsWithBoardOpenTime(uint256 openTime, uint256 closeTime) internal returns (Signals) {
        ISignals.BoardConfig memory config = defaultConfig;
        config.boardOpenAt = openTime;
        config.boardClosedAt = closeTime;
        Signals newSignals = new Signals();
        newSignals.initialize(config);

        dealMockTokens();
        return newSignals;
    }
}
