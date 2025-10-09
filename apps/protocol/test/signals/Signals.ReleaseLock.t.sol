// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {SignalsHarness} from "../utils/SignalsHarness.sol";

import {ISignals} from "../../src/interfaces/ISignals.sol";
import {Signals} from "../../src/Signals.sol";

/**
 * @title SignalsReleaseLockTest
 * @notice Tests for release timelock and board closure features
 */
contract SignalsReleaseLockTest is Test, SignalsHarness {
    Signals signals;
    Signals signalsWithTimelock;

    function setUp() public {
        // Deploy board with immediate release
        bool dealTokens = true;
        (, ISignals _signals) = deploySignalsWithFactory(dealTokens);
        signals = Signals(address(_signals));

        // Deploy board with 7-day timelock
        ISignals.BoardConfig memory timelockConfig = defaultConfig;
        timelockConfig.releaseLockDuration = 7 days;

        vm.startPrank(_deployer);
        Signals instance = new Signals();
        instance.initialize(timelockConfig);
        signalsWithTimelock = instance;
        vm.stopPrank();

        // Deal tokens
        _tokenERC20.mint(_alice, 1_000_000 * 1e18);
        _tokenERC20.mint(_bob, 1_000_000 * 1e18);
        _tokenERC20.mint(_charlie, 1_000_000 * 1e18);
    }

    /*//////////////////////////////////////////////////////////////
                    IMMEDIATE RELEASE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ImmediateRelease_Accepted() public {
        (, uint256 tokenId) = proposeAndAccept(ISignals(address(signals)), _bob, 200_000 * 1e18, 10);

        // Should withdraw immediately
        vm.prank(_bob);
        signals.redeem(tokenId);
    }

    function test_ImmediateRelease_Expired() public {
        (, uint256 tokenId) = proposeAndExpire(ISignals(address(signals)), _bob, 100_000 * 1e18, 10);

        // Should withdraw immediately
        vm.prank(_bob);
        signals.redeem(tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                    TIMELOCKED RELEASE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_TimelockRelease_BlocksBeforeExpiry() public {
        (, uint256 tokenId) = proposeAndAccept(ISignals(address(signalsWithTimelock)), _bob, 200_000 * 1e18, 10);

        // Should revert before timelock expires
        vm.prank(_bob);
        vm.expectRevert(
            abi.encodeWithSelector(ISignals.Signals_StillTimelocked.selector)
        );
        signalsWithTimelock.redeem(tokenId);
    }

    function test_TimelockRelease_AllowsAfterExpiry() public {
        (, uint256 tokenId) =
            proposeAcceptAndWarp(ISignals(address(signalsWithTimelock)), _bob, 200_000 * 1e18, 10, 7 days);

        // Should succeed after timelock
        vm.prank(_bob);
        signalsWithTimelock.redeem(tokenId);
    }

    function test_TimelockRelease_ExpiredBypassesTimelock() public {
        (, uint256 tokenId) = proposeAndExpire(ISignals(address(signalsWithTimelock)), _bob, 100_000 * 1e18, 10);

        // Expired always bypasses timelock
        vm.prank(_bob);
        signalsWithTimelock.redeem(tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                    BOARD CLOSURE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CloseBoard_OnlyOwner() public {
        vm.prank(_bob);
        vm.expectRevert();
        signals.closeBoard();
    }

    function test_CloseBoard_BypassesTimelock() public {
        (, uint256 tokenId) = proposeAndAccept(ISignals(address(signalsWithTimelock)), _bob, 200_000 * 1e18, 10);

        // Close board immediately
        vm.prank(_deployer);
        signalsWithTimelock.closeBoard();

        // Should withdraw despite timelock
        vm.prank(_bob);
        signalsWithTimelock.redeem(tokenId);
    }

    function test_CloseBoard_BlocksNewProposals() public {
        vm.prank(_deployer);
        signals.closeBoard();

        vm.startPrank(_bob);
        _tokenERC20.approve(address(signals), 100_000 * 1e18);
        vm.expectRevert(ISignals.Signals_BoardClosed.selector);
        signals.proposeInitiative("New", "Description");
        vm.stopPrank();
    }

    function test_CloseBoard_BlocksNewSupport() public {
        vm.startPrank(_bob);
        _tokenERC20.approve(address(signals), 100_000 * 1e18);
        signals.proposeInitiativeWithLock("Test", "Description", 100_000 * 1e18, 10);
        vm.stopPrank();

        vm.prank(_deployer);
        signals.closeBoard();

        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), 50_000 * 1e18);
        vm.expectRevert(ISignals.Signals_BoardClosed.selector);
        signals.supportInitiative(1, 50_000 * 1e18, 5);
        vm.stopPrank();
    }

    function test_CloseBoard_CannotCloseTwice() public {
        vm.prank(_deployer);
        signals.closeBoard();

        vm.prank(_deployer);
        vm.expectRevert(abi.encodeWithSelector(ISignals.Signals_BoardClosed.selector));
        signals.closeBoard();
    }

    function test_CloseBoard_EmitsEvent() public {
        vm.expectEmit(true, false, false, false);
        emit ISignals.BoardClosed(_deployer);

        vm.prank(_deployer);
        signals.closeBoard();
    }

    function test_CloseBoard_UpdatesState() public {
        assertEq(uint256(signals.boardState()), uint256(ISignals.BoardState.Open));

        vm.prank(_deployer);
        signals.closeBoard();

        assertEq(uint256(signals.boardState()), uint256(ISignals.BoardState.Closed));
    }

    /*//////////////////////////////////////////////////////////////
                    STATE VERIFICATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ReleaseLockDuration_IsReadable() public view {
        assertEq(signals.releaseLockDuration(), 0);
        assertEq(signalsWithTimelock.releaseLockDuration(), 7 days);
    }

    function test_AcceptanceTimestamp_IsRecorded() public {
        vm.startPrank(_bob);
        _tokenERC20.approve(address(signals), 100_000 * 1e18);
        signals.proposeInitiativeWithLock("Test", "Desc", 100_000 * 1e18, 10);
        vm.stopPrank();

        ISignals.Initiative memory beforeInit = signals.getInitiative(1);
        assertEq(beforeInit.acceptanceTimestamp, 0);

        uint256 acceptTime = block.timestamp;
        vm.prank(_deployer);
        signals.acceptInitiative(1);

        ISignals.Initiative memory afterInit = signals.getInitiative(1);
        assertEq(afterInit.acceptanceTimestamp, acceptTime);
    }
}
