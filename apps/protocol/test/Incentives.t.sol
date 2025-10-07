// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "forge-std/console.sol";
import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";

import "solmate/src/test/utils/mocks/MockERC20.sol";

import "@openzeppelin/contracts/utils/Strings.sol";

import {Signals} from "../src/Signals.sol";
import {TokenRegistry} from "../src/TokenRegistry.sol";
import {Incentives} from "../src/Incentives.sol";
import {SignalsHarness} from "./utils/SignalsHarness.sol";
import {IIncentives} from "../src/interfaces/IIncentives.sol";

contract IncentivesTest is Test, SignalsHarness {
    Incentives _incentives;
    TokenRegistry _registry;
    Signals signals;

    address _feesAddress = address(0x4444);
    address _votersAddress = address(0x5555);
    address _treasuryAddress = address(0x6666);
    // Parameters

    function setUp() public {
        // Deploy SignalsFactory with the Signals implementation
        bool dealTokens = true;
        signals = deploySignals(dealTokens);
        dealMockTokens();

        _registry = new TokenRegistry();
        _registry.allow(address(_token));
        _registry.allow(address(_usdc));

        // Declare how incentives are allocated
        // 5% to fees, 20% to voters, 75% to treasury
        uint256[3] memory _allocations = [uint256(5), uint256(20), uint256(75)];

        // Addresses that will receive the incentives
        address[3] memory _receivers = [address(_feesAddress), address(_votersAddress), address(_treasuryAddress)];

        // Create a new Incentives contract bound to the Signals instance and Token Registry
        _incentives = new Incentives(address(signals), address(_registry), _allocations, _receivers);

        // Set the Incentives contract in the Signals contract
        signals.setIncentives(address(_incentives));
    }

    /*//////////////////////////////////////////////////////////////
                        INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Setup_InitialState() public view {
        // Ensure the owner is the deployer
        assertEq(signals.owner(), address(_deployer));

        // Accounts have been created with the expected balances
        assertEq(_token.balanceOf(_alice), 200_000 * 1e18);
        assertEq(_usdc.balanceOf(_alice), 200_000 * 1e6);

        // TokenRegistry has token and usdc registered
        assertEq(_registry.isAllowed(address(_token)), true);
        assertEq(_registry.isAllowed(address(_usdc)), true);
    }

    /*//////////////////////////////////////////////////////////////
                        INCENTIVE ADDITION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_AddIncentive_Multiple() public {
        // Propose an initiative
        vm.startPrank(_alice);
        signals.proposeInitiative("Initiative 1", "Test adding incentives");

        // Add a 500 USDC bounty (4 times)
        uint256 initiativeId = 1;
        address rewardToken = address(_usdc);
        uint256 amount = 500 * 1e6;
        uint256 expiresAt = 0;
        IIncentives.Conditions conditions = IIncentives.Conditions.NONE;
        // Approve the incentives contract to spend the USDC
        _usdc.approve(address(_incentives), amount * 4);

        // Add 4 incentives
        for (uint256 i = 1; i <= 4; i++) {
            vm.expectEmit();
            emit IIncentives.IncentiveAdded(i, initiativeId, rewardToken, amount, expiresAt, conditions);
            _incentives.addIncentive(initiativeId, rewardToken, amount, expiresAt, conditions);
        }

        (address[] memory tokens, uint256[] memory amounts, uint256 expiredCount) =
            _incentives.getIncentives(initiativeId);

        // Ensure the incentives are summed up correctly
        assertEq(tokens.length, 1);
        assertEq(tokens[0], rewardToken);
        assertEq(amounts[0], amount * 4);
        assertEq(expiredCount, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        REWARD CALCULATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_PreviewRewards_CalculatesCorrectly() public {
        // Propose an initiative
        vm.startPrank(_alice);

        // Propose an initiative with a lock
        uint256 lockedAmount = 200 * 1e18;
        _token.approve(address(signals), lockedAmount);
        signals.proposeInitiativeWithLock("Initiative 1", "Test adding incentives", lockedAmount, 6);

        // Add a 500 USDC bounty (4 times)
        uint256 initiativeId = 1;
        address rewardToken = address(_usdc);
        uint256 amount = 500 * 1e6;
        uint256 expiresAt = 0;
        IIncentives.Conditions conditions = IIncentives.Conditions.NONE;
        // Approve the incentives contract to spend the USDC
        _usdc.approve(address(_incentives), amount * 4);

        // Add 4 incentives
        for (uint256 i = 1; i <= 4; i++) {
            _incentives.addIncentive(initiativeId, rewardToken, amount, expiresAt, conditions);
        }

        // Calculate Alices share of the rewards
        // 20% of the total rewards are allocated to voters
        uint256 rewards = _incentives.previewRewards(initiativeId, 1);
        assertEq(rewards, amount * 4 * 20 / 100);
    }

    /*//////////////////////////////////////////////////////////////
                        TODO: CLAIM REWARD TESTS
    //////////////////////////////////////////////////////////////*/

    // TODO: Test claiming rewards after initiative acceptance
    // function test_Claim_AfterAcceptance() public {}

    // TODO: Test claiming rewards with multiple supporters
    // function test_Claim_WithMultipleSupporters() public {}

    // TODO: Test cannot claim rewards before acceptance
    // function test_Claim_RevertsBeforeAcceptance() public {}

    // TODO: Test cannot claim expired incentives
    // function test_Claim_RevertsForExpiredIncentives() public {}

    /*//////////////////////////////////////////////////////////////
                        TODO: ALLOCATION TESTS
    //////////////////////////////////////////////////////////////*/

    // TODO: Test allocation distribution matches configuration
    // function test_Allocation_DistributionMatchesConfig() public {}

    // TODO: Test changing allocation percentages
    // function test_Allocation_ChangePercentages() public {}

    // TODO: Test allocation with different token types
    // function test_Allocation_WithDifferentTokenTypes() public {}

    /*//////////////////////////////////////////////////////////////
                        TODO: TOKEN REGISTRY TESTS
    //////////////////////////////////////////////////////////////*/

    // TODO: Test adding incentives with unregistered token
    // function test_AddIncentive_RevertsWithUnregisteredToken() public {}

    // TODO: Test registering and unregistering tokens
    // function test_Registry_RegisterAndUnregisterTokens() public {}

    // TODO: Test only owner can modify registry
    // function test_Registry_OnlyOwnerCanModify() public {}

    /*//////////////////////////////////////////////////////////////
                        TODO: EXPIRATION TESTS
    //////////////////////////////////////////////////////////////*/

    // TODO: Test incentive expiration handling
    // function test_Incentive_HandlesExpiration() public {}

    // TODO: Test expired incentive count
    // function test_Incentive_CountsExpired() public {}

    // TODO: Test claiming non-expired incentives only
    // function test_Claim_OnlyNonExpiredIncentives() public {}

    /*//////////////////////////////////////////////////////////////
                        TODO: INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    // TODO: Test full flow: add incentive -> support -> accept -> claim
    // function test_FullFlow_AddToClaim() public {}

    // TODO: Test multiple incentives across multiple initiatives
    // function test_MultipleIncentives_AcrossMultipleInitiatives() public {}

    /*//////////////////////////////////////////////////////////////
                        TODO: EVENT EMISSION TESTS
    //////////////////////////////////////////////////////////////*/

    // TODO: Test IncentiveAdded event emits correctly
    // function test_AddIncentive_EmitsEvent() public {}

    // TODO: Test IncentiveClaimed event emits correctly
    // function test_Claim_EmitsEvent() public {}

    /*//////////////////////////////////////////////////////////////
                        TODO: BALANCE VERIFICATION TESTS
    //////////////////////////////////////////////////////////////*/

    // TODO: Test contract holds correct amount of incentive tokens
    // function test_Balance_ContractHoldsCorrectAmount() public {}

    // TODO: Test balance consistency after claims
    // function test_Balance_ConsistencyAfterClaims() public {}
}
