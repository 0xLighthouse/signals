// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {SignalsHarness} from "../utils/SignalsHarness.sol";

import {IBondIssuer} from "../../src/interfaces/IBondIssuer.sol";
import {ISignals} from "../../src/interfaces/ISignals.sol";

/**
 * @title SignalsBondIssuerTest
 * @notice Tests for IBondIssuer interface compliance
 * @dev Covers bond details retrieval, NFT queries, and interface compliance
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

    /// Test retrieving bond details through IBondIssuer interface
    function test_BondDetails_Retrieve() public {
        vm.startPrank(_alice);
        _token.approve(address(signals), 100 * 1e18);
        signals.proposeInitiativeWithLock("Initiative 1", "Description 1", 100 * 1e18, 6);
        vm.stopPrank();

        // Test the signals contract as an IBondIssuer
        IBondIssuer signalsIssuer = IBondIssuer(address(signals));
        IBondIssuer.BondInfo memory bondInfo = signalsIssuer.getBondInfo(1);

        assertEq(bondInfo.referenceId, 1);
        assertEq(bondInfo.nominalValue, 100 * 1e18);
        assertEq(bondInfo.expires, block.timestamp + 6 * 60 * 60 * 24);
        assertEq(bondInfo.created, block.timestamp);
        assertEq(bondInfo.claimed, false);
    }

    /*//////////////////////////////////////////////////////////////
                        NFT LISTING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ListPositions_ByOwner() public {
        vm.startPrank(_alice);
        _token.approve(address(signals), 100 * 1e18);
        signals.proposeInitiativeWithLock("Initiative 1", "Description 1", 100 * 1e18, 6);
        vm.stopPrank();

        vm.startPrank(_alice);
        uint256[] memory nfts = signals.listPositions(_alice);
        assertEq(nfts.length, 1);
        assertEq(nfts[0], 1);
    }

    /*//////////////////////////////////////////////////////////////
                    TODO: BOND INFO ACCURACY TESTS
    //////////////////////////////////////////////////////////////*/

    // TODO: Test bond info accuracy across different states
    // function test_BondInfo_Accuracy() public {}

    // TODO: Test bond info after redemption
    // function test_BondInfo_AfterRedemption() public {}

    /*//////////////////////////////////////////////////////////////
                    TODO: NFT TRANSFER TESTS
    //////////////////////////////////////////////////////////////*/

    // TODO: Test transferring a locked NFT
    // function test_Transfer_LockedNFT() public {}

    // TODO: Test bond info after NFT transfer
    // function test_BondInfo_AfterTransfer() public {}

    /*//////////////////////////////////////////////////////////////
                    TODO: NFT METADATA TESTS
    //////////////////////////////////////////////////////////////*/

    // TODO: Test NFT metadata (if implemented)
    // function test_NFT_Metadata() public {}

    // TODO: Test tokenURI (if implemented)
    // function test_NFT_TokenURI() public {}
}
