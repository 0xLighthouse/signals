// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {SignalsHarness} from "../utils/SignalsHarness.sol";

import {ISignals} from "../../src/interfaces/ISignals.sol";

/**
 * @title SignalsSupportTest
 * @notice Tests for supporting initiatives with locked tokens
 * @dev Covers support operations, locking mechanics, and NFT minting
 */
contract SignalsSupportTest is Test, SignalsHarness {
    ISignals signals;

    function setUp() public {
        bool dealTokens = true;
        (, signals) = deploySignalsWithFactory(dealTokens);
    }

    /*//////////////////////////////////////////////////////////////
                        SUPPORT TESTS
    //////////////////////////////////////////////////////////////*/

    /// Test supporting an initiative with locked tokens
    function test_Support_WithLockedTokens() public {
        vm.startPrank(_alice);

        // Propose an initiative
        _tokenERC20.approve(address(signals), 100 * 1e18);
        signals.proposeInitiative("Initiative 1", "Description 1");
        vm.stopPrank();

        vm.startPrank(_bob);
        // Approve tokens
        _tokenERC20.approve(address(signals), 150 * 1e18);

        // Support the initiative
        signals.supportInitiative(1, 150 * 1e18, 6);
        vm.stopPrank();

        // Check that the lock info is stored
        ISignals.TokenLock memory lock = signals.getTokenLock(1);
        assertEq(lock.tokenAmount, 150 * 1e18);
        assertEq(lock.lockDuration, 6);
        assertEq(lock.withdrawn, false);
    }

    /*//////////////////////////////////////////////////////////////
                    TODO: SUPPORT EDGE CASES
    //////////////////////////////////////////////////////////////*/

    // TODO: Test cannot support an expired initiative
    // function test_Support_RevertsWhenExpired() public {}

    // TODO: Test supporting with minimum amount
    // function test_Support_MinimumAmount() public {}

    // TODO: Test supporting multiple times with same NFT
    // function test_Support_RevertsWithSameNFT() public {}

    /*//////////////////////////////////////////////////////////////
                    TODO: INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    // TODO: Test multiple users supporting same initiative with different durations
    // function test_Support_MultipleUsersWithDifferentDurations() public {}

    /*//////////////////////////////////////////////////////////////
                    TODO: EVENT EMISSION TESTS
    //////////////////////////////////////////////////////////////*/

    // TODO: Test all events are emitted with correct parameters for support
    // function test_SupportInitiative_EmitsEvent() public {}

    /*//////////////////////////////////////////////////////////////
                    TODO: BALANCE VERIFICATION TESTS
    //////////////////////////////////////////////////////////////*/

    // TODO: Test balance consistency after support
    // function test_Balance_ConsistencyAfterSupport() public {}

    /*//////////////////////////////////////////////////////////////
                    TODO: FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    // TODO: Fuzz test support with various amounts and durations
    // function testFuzz_Support_VariousAmountsAndDurations(uint256 amount, uint256 duration) public {}
}
