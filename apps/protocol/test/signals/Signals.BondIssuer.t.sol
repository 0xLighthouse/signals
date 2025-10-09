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
        bool dealTokens = true;
        (, signals) = deploySignalsWithFactory(dealTokens);
    }

    /*//////////////////////////////////////////////////////////////
                        BOND DETAILS TESTS
    //////////////////////////////////////////////////////////////*/

    /// Test retrieving lock details through ISignalsLock interface
    function test_BondDetails_Retrieve() public {
        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), 100 * 1e18);
        signals.proposeInitiativeWithLock("Initiative 1", "Description 1", 100 * 1e18, 6);
        vm.stopPrank();

        // Test the signals contract as an ISignalsLock
        ISignalsLock signalsIssuer = ISignalsLock(address(signals));
        ISignalsLock.LockData memory lockData = signalsIssuer.getLockData(1);

        assertEq(lockData.referenceId, 1);
        assertEq(lockData.nominalValue, 100 * 1e18);
        assertEq(lockData.expires, block.timestamp + 6 * 60 * 60 * 24);
        assertEq(lockData.created, block.timestamp);
        assertEq(lockData.claimed, false);
    }

    /*//////////////////////////////////////////////////////////////
                        NFT LISTING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ListPositions_ByOwner() public {
        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), 100 * 1e18);
        signals.proposeInitiativeWithLock("Initiative 1", "Description 1", 100 * 1e18, 6);
        vm.stopPrank();

        vm.startPrank(_alice);
        uint256[] memory nfts = signals.listPositions(_alice);
        assertEq(nfts.length, 1);
        assertEq(nfts[0], 1);
    }

    /*//////////////////////////////////////////////////////////////
                    TODO: LOCK DATA ACCURACY TESTS
    //////////////////////////////////////////////////////////////*/

    // TODO: Test lock data accuracy across different states
    // function test_LockData_Accuracy() public {}

    // TODO: Test lock data after redemption
    // function test_LockData_AfterRedemption() public {}

    /*//////////////////////////////////////////////////////////////
                    TODO: NFT TRANSFER TESTS
    //////////////////////////////////////////////////////////////*/

    // TODO: Test transferring a locked NFT
    // function test_Transfer_LockedNFT() public {}

    // TODO: Test lock data after NFT transfer
    // function test_LockData_AfterTransfer() public {}

    /*//////////////////////////////////////////////////////////////
                    TODO: NFT METADATA TESTS
    //////////////////////////////////////////////////////////////*/

    // TODO: Test NFT metadata (if implemented)
    // function test_NFT_Metadata() public {}

    // TODO: Test tokenURI (if implemented)
    // function test_NFT_TokenURI() public {}
}
