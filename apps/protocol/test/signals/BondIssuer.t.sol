// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {SignalsHarness} from "../utils/SignalsHarness.sol";

import {ISignalsLock} from "../../src/interfaces/ISignalsLock.sol";
import {ISignals} from "../../src/interfaces/ISignals.sol";

/**
 * @title SignalsBondIssuerTest
 * @notice Tests for ISignalsLock interface compliance
 * @dev Covers lock details retrieval, NFT queries, and interface compliance
 */
contract SignalsBondIssuerTest is Test, SignalsHarness {
    ISignals signals;

    function setUp() public {
        signals = deploySignals(defaultConfig);
        dealMockTokens();
    }

    /*//////////////////////////////////////////////////////////////
                        BOND DETAILS TESTS
    //////////////////////////////////////////////////////////////*/

    /// Test retrieving lock details through ISignalsLock interface
    function test_BondDetails_Retrieve() public {
        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), 100 ether);
        signals.proposeInitiativeWithLock(
            "Initiative 1",
            "Description 1",
            100 ether,
            6,
            new ISignals.Attachment[](0)
        );
        vm.stopPrank();

        // Test the signals contract as an ISignalsLock
        ISignalsLock signalsIssuer = ISignalsLock(address(signals));
        ISignalsLock.LockData memory lockData = signalsIssuer.getLockData(1);

        assertEq(lockData.referenceId, 1);
        assertEq(lockData.nominalValue, 100 ether);
        assertEq(lockData.expires, block.timestamp + 6 * 60 * 60 * 24);
        assertEq(lockData.created, block.timestamp);
        assertEq(lockData.claimed, false);
    }

    /*//////////////////////////////////////////////////////////////
                        NFT LISTING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ListPositions_ByOwner() public {
        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), 100 ether);
        signals.proposeInitiativeWithLock(
            "Initiative 1",
            "Description 1",
            100 ether,
            6,
            new ISignals.Attachment[](0)
        );
        vm.stopPrank();

        vm.startPrank(_alice);
        uint256[] memory nfts = signals.listPositions(_alice);
        assertEq(nfts.length, 1);
        assertEq(nfts[0], 1);
    }
}
