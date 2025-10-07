// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {SignalsHarness} from "../utils/SignalsHarness.sol";

import {ISignals} from "../../src/interfaces/ISignals.sol";

/**
 * @title SignalsRedemptionTest
 * @notice Tests for redeeming locked tokens from initiatives
 * @dev Covers redemption after acceptance, expiration, and error cases
 */
contract SignalsRedemptionTest is Test, SignalsHarness {
    ISignals signals;

    function setUp() public {
        bool dealTokens = true;
        (, signals) = deploySignalsWithFactory(dealTokens);
    }

    /*//////////////////////////////////////////////////////////////
                    REDEMPTION AFTER ACCEPTANCE
    //////////////////////////////////////////////////////////////*/

    /// Test redeeming tokens after initiative is accepted
    function test_Redeem_AfterAcceptance() public {
        // Propose an initiative with lock
        vm.startPrank(_bob);
        _tokenERC20.approve(address(signals), 200 * 1e18);
        signals.proposeInitiativeWithLock("Initiative 2", "Description 2", 200 * 1e18, 6);

        // Accept the initiative
        vm.startPrank(_deployer);
        signals.acceptInitiative(1);

        // Check initial token balance
        // Withdraw tokens
        vm.startPrank(_bob);
        uint256 initialBalance = _tokenERC20.balanceOf(_bob);
        signals.redeem(1);

        // Check token balance after withdrawal
        uint256 finalBalance = _tokenERC20.balanceOf(_bob);
        assertEq(finalBalance, initialBalance + 200 * 1e18);

        // Note: Double redemption is tested separately in test_Redeem_RevertsTwice()
    }

    /// Test redeeming tokens before initiative is accepted (should fail)
    function test_Redeem_RevertsBeforeAcceptance() public {
        // Propose an initiative with lock
        vm.startPrank(_bob);
        _tokenERC20.approve(address(signals), 200 * 1e18);
        signals.proposeInitiativeWithLock("Initiative 2", "Description 2", 200 * 1e18, 6);

        // Attempt to withdraw tokens before acceptance
        vm.expectRevert(abi.encodeWithSignature("InvalidInitiativeState(string)", "Initiative not withdrawable"));
        signals.redeem(1);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                    MULTIPLE REDEMPTIONS
    //////////////////////////////////////////////////////////////*/

    /// Test redeeming multiple escrow locks
    function test_Redeem_MultipleLocks() public {
        // Propose an initiative with lock
        vm.startPrank(_alice);
        _tokenERC20.approve(address(signals), 100 * 1e18);
        signals.proposeInitiativeWithLock("Initiative 1", "Description 1", 100 * 1e18, 6);

        // Add a second lock to the same initiative
        _tokenERC20.approve(address(signals), 75 * 1e18);
        signals.supportInitiative(1, 75 * 1e18, 6);

        // Support another initiative
        _tokenERC20.approve(address(signals), 150 * 1e18);
        signals.supportInitiative(1, 150 * 1e18, 6);

        // Accept the initiative
        vm.startPrank(_deployer);
        signals.acceptInitiative(1);

        // Record the balance before withdrawal
        vm.startPrank(_alice);
        uint256 balanceBefore = _tokenERC20.balanceOf(_alice);

        // List all NFTs owned by the alice
        uint256[] memory nfts = signals.listPositions(_alice);
        assertEq(nfts.length, 3);

        // Iterate over the NFTs and redeem them
        for (uint256 i = 0; i < nfts.length; i++) {
            signals.redeem(nfts[i]);
        }

        uint256 balanceAfter = _tokenERC20.balanceOf(_alice);
        uint256 balanceDifference = balanceAfter - balanceBefore;

        // Assert that the balance difference is equal to the withdrawn amount
        assertEq(balanceDifference, 325 * 1e18);
    }

    /// Test that redeeming multiple escrow locks only withdraws from initiatives in withdrawable state
    function test_Redeem_PartialWithdrawal() public {
        // Propose initiative with lock
        vm.startPrank(_bob);
        _tokenERC20.approve(address(signals), defaultConfig.proposerRequirements.threshold);
        signals.proposeInitiativeWithLock("Initiative 1", "Description 1", defaultConfig.proposerRequirements.threshold, 6);

        // Propose another initiative with lock
        _tokenERC20.approve(address(signals), defaultConfig.proposerRequirements.threshold);
        signals.proposeInitiativeWithLock("Initiative 2", "Description 2", defaultConfig.proposerRequirements.threshold, 6);

        // Accept the first initiative
        vm.startPrank(_deployer);
        signals.acceptInitiative(1);

        // Record the balance before first withdrawal
        vm.startPrank(_bob);
        uint256 initialBalance = _tokenERC20.balanceOf(_bob);

        // Withdraw all tokens (should only withdraw from the accepted initiative)
        signals.redeem(1); // veBond 1

        // Record the balance after first withdrawal
        uint256 balanceAfterFirstWithdraw = _tokenERC20.balanceOf(_bob);
        uint256 balanceDifference = balanceAfterFirstWithdraw - initialBalance;
        assertEq(balanceDifference, defaultConfig.proposerRequirements.threshold);

        // Attempt to withdraw the second lock...
        vm.startPrank(_bob);
        vm.expectRevert(abi.encodeWithSignature("InvalidInitiativeState(string)", "Initiative not withdrawable"));
        signals.redeem(2); // veBond 2

        // Fast forward time beyond inactivity threshold
        skip(61 days);

        // Expire the second initiative
        vm.startPrank(_deployer);
        signals.expireInitiative(2);

        // Withdraw tokens from the expired initiative
        vm.startPrank(_bob);
        signals.redeem(2); // veBond 2

        // Assert that the total balance difference equals the sum of both withdrawals
        uint256 finalBalance = _tokenERC20.balanceOf(_bob);
        uint256 totalBalanceDifference = finalBalance - initialBalance;
        assertEq(totalBalanceDifference, defaultConfig.proposerRequirements.threshold * 2);
    }

    /*//////////////////////////////////////////////////////////////
                    REDEMPTION AFTER EXPIRATION
    //////////////////////////////////////////////////////////////*/

    /// Test withdrawing tokens after initiative is expired
    function test_Redeem_AfterExpiration() public {
        // Propose an initiative with lock
        vm.startPrank(_bob);
        _tokenERC20.approve(address(signals), 200 * 1e18);
        signals.proposeInitiativeWithLock("Initiative 2", "Description 2", 200 * 1e18, 6);

        // Fast forward time beyond inactivity threshold
        vm.warp(block.timestamp + 61 days);

        // Expire the initiative
        vm.startPrank(_deployer);
        signals.expireInitiative(1);

        // Check initial token balance
        // Withdraw tokens
        vm.startPrank(_bob);

        uint256 initialBalance = _tokenERC20.balanceOf(_bob);
        signals.redeem(1);

        uint256 finalBalance = _tokenERC20.balanceOf(_bob);
        assertEq(finalBalance, initialBalance + 200 * 1e18);
    }

    /*//////////////////////////////////////////////////////////////
                        ERROR CASES
    //////////////////////////////////////////////////////////////*/

    // Test that users cannot redeem tokens twice
    function test_Redeem_RevertsTwice() public {
        // Propose an initiative with lock
        vm.startPrank(_bob);
        _tokenERC20.approve(address(signals), 200 * 1e18);
        signals.proposeInitiativeWithLock("Initiative 1", "Description 1", 200 * 1e18, 6);

        // Accept the initiative
        vm.startPrank(_deployer);
        signals.acceptInitiative(1);

        // Withdraw all tokens
        vm.startPrank(_bob);
        signals.redeem(1);

        // Attempt to withdraw again
        vm.expectRevert(ISignals.InvalidRedemption.selector);
        signals.redeem(1);
    }

    /*//////////////////////////////////////////////////////////////
                    TODO: NFT TRANSFER & OWNERSHIP TESTS
    //////////////////////////////////////////////////////////////*/

    // TODO: Test redeeming after NFT transfer
    // function test_Redeem_AfterNFTTransfer() public {}

    // TODO: Test redeeming as non-owner should fail
    // function test_Redeem_RevertsAsNonOwner() public {}

    /*//////////////////////////////////////////////////////////////
                    TODO: INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    // TODO: Test concurrent redemptions
    // function test_Redeem_ConcurrentRedemptions() public {}

    /*//////////////////////////////////////////////////////////////
                    TODO: BALANCE VERIFICATION TESTS
    //////////////////////////////////////////////////////////////*/

    // TODO: Test contract balance matches locked tokens
    // function test_Balance_ContractMatchesLockedTokens() public {}

    // TODO: Test total locked tokens equals sum of all locks
    // function test_Balance_TotalLockedEqualsIndividualLocks() public {}

    // TODO: Test balance consistency after multiple operations
    // function test_Balance_ConsistencyAfterMultipleOps() public {}

    /*//////////////////////////////////////////////////////////////
                    TODO: EVENT EMISSION TESTS
    //////////////////////////////////////////////////////////////*/

    // TODO: Test all events are emitted with correct parameters for redeem
    // function test_Redeem_EmitsEvent() public {}
}
