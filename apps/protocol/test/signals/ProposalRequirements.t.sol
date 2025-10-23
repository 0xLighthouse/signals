// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {SignalsHarness} from "../utils/SignalsHarness.sol";

import {ISignals} from "../../src/interfaces/ISignals.sol";
import {IAuthorizer} from "../../src/interfaces/IAuthorizer.sol";
import {Signals} from "../../src/Signals.sol";

/**
 * @title SignalsProposerRequirementsTest
 * @notice Tests for proposal requirements configuration
 */
contract SignalsProposerRequirementsTest is Test, SignalsHarness {
/*//////////////////////////////////////////////////////////////
                        INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

// function test_Initialize_AllRequirementModes() public {
//     // None mode (default)
//     Signals signals1 = deploySignals(defaultConfig, false);
//     IAuthorizer.ParticipantRequirements memory reqs1 = signals1.getProposerRequirements();
//     assertEq(uint256(reqs1.eligibilityType), uint256(IAuthorizer.EligibilityType.None));

//     // MinBalance mode
//     ISignals.BoardConfig memory config2 = defaultConfig;
//     config2.proposerRequirements = IAuthorizer.ParticipantRequirements({
//         eligibilityType: IAuthorizer.EligibilityType.MinBalance,
//         minBalance: 10_000 * 1e18,
//         minHoldingDuration: 0,
//         minLockAmount: 50_000 * 1e18
//     });
//     Signals signals2 = new Signals();
//     signals2.initialize(config2);
//     IAuthorizer.ParticipantRequirements memory reqs2 = signals2.getProposerRequirements();
//     assertEq(uint256(reqs2.eligibilityType), uint256(IAuthorizer.EligibilityType.MinBalance));
//     assertEq(reqs2.minBalance, 10_000 * 1e18);

//     // MinBalanceAndDuration mode
//     ISignals.BoardConfig memory config3 = erc20VotesConfig;
//     config3.proposerRequirements = IAuthorizer.ParticipantRequirements({
//         eligibilityType: IAuthorizer.EligibilityType.MinBalanceAndDuration,
//         minBalance: 10_000 * 1e18,
//         minHoldingDuration: 100,
//         minLockAmount: 50_000 * 1e18
//     });
//     Signals signals3 = new Signals();
//     signals3.initialize(config3);
//     IAuthorizer.ParticipantRequirements memory reqs3 = signals3.getProposerRequirements();
//     assertEq(uint256(reqs3.eligibilityType), uint256(IAuthorizer.EligibilityType.MinBalanceAndDuration));
//     assertEq(reqs3.minHoldingDuration, 100);
// }

// /*//////////////////////////////////////////////////////////////
//                     MIN BALANCE MODE TESTS
// //////////////////////////////////////////////////////////////*/

// function test_Propose_MinBalance_EnforcesThreshold() public {
//     ISignals.BoardConfig memory config = defaultConfig;
//     config.proposerRequirements = IAuthorizer.ParticipantRequirements({
//         eligibilityType: IAuthorizer.EligibilityType.MinBalance,
//         minBalance: 75_000 * 1e18,
//         minHoldingDuration: 0,
//         minLockAmount: 50_000 * 1e18
//     });

//     Signals signals = deploySignals(config, true);

//     // Alice (50k) - should fail
//     vm.startPrank(_alice);
//     _tokenERC20.approve(address(signals), 50_000 * 1e18);
//     vm.expectRevert(abi.encodeWithSelector(ISignals.Signals_ParticipantInsufficientBalance.selector));
//     signals.proposeInitiative("Test", "Description");
//     vm.stopPrank();

//     // Bob (100k) - should succeed
//     vm.startPrank(_bob);
//     _tokenERC20.approve(address(signals), 100_000 * 1e18);
//     signals.proposeInitiative("Test", "Description");
//     vm.stopPrank();

//     assertEq(signals.getInitiative(1).proposer, _bob);
// }

// function test_CanPropose_MinBalance_ChecksCorrectly() public {
//     ISignals.BoardConfig memory config = defaultConfig;
//     config.proposerRequirements = IAuthorizer.ParticipantRequirements({
//         eligibilityType: IAuthorizer.EligibilityType.MinBalance,
//         minBalance: 75_000 * 1e18,
//         minHoldingDuration: 0,
//         minLockAmount: 50_000 * 1e18
//     });

//     Signals signals = new Signals();
//     signals.initialize(config);
//     _dealDefaultTokens();

//     assertFalse(signals.accountCanPropose(_alice, 50_000 * 1e18)); // 50k
//     assertTrue(signals.accountCanPropose(_bob, 50_000 * 1e18)); // 100k
//     assertFalse(signals.accountCanPropose(_charlie, 50_000 * 1e18)); // 25k
// }

// /*//////////////////////////////////////////////////////////////
//                     MIN BALANCE AND DURATION TESTS
// //////////////////////////////////////////////////////////////*/

// function test_Propose_MinBalanceAndDuration_AllowsWhenMet() public {
//     ISignals.BoardConfig memory config = erc20VotesConfig;
//     config.proposerRequirements = IAuthorizer.ParticipantRequirements({
//         eligibilityType: IAuthorizer.EligibilityType.MinBalanceAndDuration,
//         minBalance: 40_000 * 1e18,
//         minHoldingDuration: 10,
//         minLockAmount: 50_000 * 1e18
//     });

//     Signals signals = new Signals();
//     signals.initialize(config);
//     _dealAndDelegateERC20Votes();

//     vm.roll(block.number + 15);

//     vm.startPrank(_alice);
//     _tokenERC20Votes.approve(address(signals), 50_000 * 1e18);
//     signals.proposeInitiative("Test", "Description");
//     vm.stopPrank();

//     assertEq(signals.getInitiative(1).proposer, _alice);
// }

// function test_Propose_MinBalanceAndDuration_RevertsOnFailure() public {
//     ISignals.BoardConfig memory config = erc20VotesConfig;
//     config.proposerRequirements = IAuthorizer.ParticipantRequirements({
//         eligibilityType: IAuthorizer.EligibilityType.MinBalanceAndDuration,
//         minBalance: 40_000 * 1e18,
//         minHoldingDuration: 50,
//         minLockAmount: 50_000 * 1e18
//     });

//     Signals signals = new Signals();
//     signals.initialize(config);

//     vm.roll(100);
//     _tokenERC20Votes.mint(_alice, 50_000 * 1e18);
//     vm.prank(_alice);
//     _tokenERC20Votes.delegate(_alice);

//     // Only 10 blocks elapsed (needs 50)
//     vm.roll(block.number + 10);

//     vm.startPrank(_alice);
//     _tokenERC20Votes.approve(address(signals), 50_000 * 1e18);
//     vm.expectRevert(abi.encodeWithSelector(ISignals.Signals_ParticipantInsufficientDuration.selector));
//     signals.proposeInitiative("Test", "Description");
//     vm.stopPrank();
// }

// function test_Propose_MinBalanceAndDuration_RevertsForStandardERC20() public {
//     ISignals.BoardConfig memory config = defaultConfig;
//     config.proposerRequirements = IAuthorizer.ParticipantRequirements({
//         eligibilityType: IAuthorizer.EligibilityType.MinBalanceAndDuration,
//         minBalance: 10_000 * 1e18,
//         minHoldingDuration: 10,
//         minLockAmount: 50_000 * 1e18
//     });

//     Signals signals = new Signals();
//     signals.initialize(config);
//     _dealDefaultTokens();

//     vm.roll(block.number + 15);

//     vm.startPrank(_alice);
//     _tokenERC20.approve(address(signals), 50_000 * 1e18);
//     vm.expectRevert(abi.encodeWithSelector(ISignals.Signals_ParticipantNoCheckpointSupport.selector));
//     signals.proposeInitiative("Test", "Description");
//     vm.stopPrank();
// }

// /*//////////////////////////////////////////////////////////////
//                     VALIDATION TESTS
// //////////////////////////////////////////////////////////////*/

// function test_Initialize_RevertsInvalidConfigurations() public {
//     // MinBalance with zero balance
//     ISignals.BoardConfig memory config1 = defaultConfig;
//     config1.proposerRequirements = IAuthorizer.ParticipantRequirements({
//         eligibilityType: IAuthorizer.EligibilityType.MinBalance,
//         minBalance: 0,
//         minHoldingDuration: 0,
//         minLockAmount: 50_000 * 1e18
//     });
//     Signals signals1 = new Signals();
//     vm.expectRevert(abi.encodeWithSelector(ISignals.Signals_ConfigErrorZeroMinBalance.selector));
//     signals1.initialize(config1);

//     // MinBalanceAndDuration with zero duration
//     ISignals.BoardConfig memory config2 = erc20VotesConfig;
//     config2.proposerRequirements = IAuthorizer.ParticipantRequirements({
//         eligibilityType: IAuthorizer.EligibilityType.MinBalanceAndDuration,
//         minBalance: 10_000 * 1e18,
//         minHoldingDuration: 0,
//         minLockAmount: 50_000 * 1e18
//     });
//     Signals signals2 = new Signals();
//     vm.expectRevert(abi.encodeWithSelector(ISignals.Signals_ConfigErrorZeroMinDuration.selector));
//     signals2.initialize(config2);
// }

// /*//////////////////////////////////////////////////////////////
//                     INTEGRATION TESTS
// //////////////////////////////////////////////////////////////*/

// function test_Integration_RequirementsIndependentFromThreshold() public {
//     ISignals.BoardConfig memory config = defaultConfig;
//     config.proposerRequirements = IAuthorizer.ParticipantRequirements({
//         eligibilityType: IAuthorizer.EligibilityType.MinBalance,
//         minBalance: 75_000 * 1e18,
//         minHoldingDuration: 0,
//         minLockAmount: 50_000 * 1e18
//     });

//     Signals signals = new Signals();
//     signals.initialize(config);
//     _dealDefaultTokens();

//     // Alice has 50k - meets minLockAmount but NOT minBalance requirement
//     assertFalse(signals.accountCanPropose(_alice, 50_000 * 1e18));

//     // Bob has 100k - meets both
//     assertTrue(signals.accountCanPropose(_bob, 50_000 * 1e18));
// }

// function test_Integration_BalanceChangesAffectEligibility() public {
//     ISignals.BoardConfig memory config = defaultConfig;
//     config.proposerRequirements = IAuthorizer.ParticipantRequirements({
//         eligibilityType: IAuthorizer.EligibilityType.MinBalance,
//         minBalance: 60_000 * 1e18,
//         minHoldingDuration: 0,
//         minLockAmount: 50_000 * 1e18
//     });

//     Signals signals = new Signals();
//     signals.initialize(config);

//     // Alice gains tokens
//     deal(address(_tokenERC20), _alice, 50_000 * 1e18);
//     assertFalse(signals.accountCanPropose(_alice, 50_000 * 1e18));

//     deal(address(_tokenERC20), _alice, 70_000 * 1e18);
//     assertTrue(signals.accountCanPropose(_alice, 50_000 * 1e18));

//     // Alice loses tokens
//     vm.prank(_alice);
//     _tokenERC20.transfer(_bob, 30_000 * 1e18);
//     assertFalse(signals.accountCanPropose(_alice, 50_000 * 1e18));
// }

// function test_Integration_LockingReducesEligibility() public {
//     ISignals.BoardConfig memory config = defaultConfig;
//     config.proposerRequirements = IAuthorizer.ParticipantRequirements({
//         eligibilityType: IAuthorizer.EligibilityType.MinBalance,
//         minBalance: 40_000 * 1e18,
//         minHoldingDuration: 0,
//         minLockAmount: 50_000 * 1e18
//     });

//     Signals signals = new Signals();
//     signals.initialize(config);
//     _dealDefaultTokens();

//     // Alice locks 30k, leaving 20k
//     vm.startPrank(_alice);
//     _tokenERC20.approve(address(signals), 50_000 * 1e18);
//     signals.proposeInitiativeWithLock("First", "Description", 30_000 * 1e18, 6);

//     // Alice now has 20k - cannot propose again
//     assertFalse(signals.accountCanPropose(_alice, 50_000 * 1e18));
//     vm.expectRevert(abi.encodeWithSelector(ISignals.Signals_ParticipantInsufficientBalance.selector));
//     signals.proposeInitiative("Second", "Description");
//     vm.stopPrank();
// }
}
