// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {SignalsHarness} from "../utils/SignalsHarness.sol";

import {ISignals} from "../../src/interfaces/ISignals.sol";
import {IIncentivizer} from "../../src/interfaces/IIncentivizer.sol";
import {Signals} from "../../src/Signals.sol";
import {IncentivesPool} from "../../src/IncentivesPool.sol";
import {IncentivesMath} from "../../src/IncentivesMath.sol";
import {MockERC20} from "solady/test/utils/mocks/MockERC20.sol";

/**
 * @title IncentivesPoolTest
 * @notice Tests for IncentivesPool internal functions
 * @dev Tests bucket reduction and multiplier calculation logic
 */
contract IncentivesPoolTest is Test {
    IncentivesPool public incentivesPool;
    MockERC20 public rewardToken;
    address public testBoard;
    uint256 constant TEST_INITIATIVE_ID = 1;
    uint256 constant INCENTIVE_RESOLUTION = 24;
    IIncentivizer.IncentivesConfig public testConfig;

    function setUp() public {
        // Deploy reward token
        rewardToken = new MockERC20("Reward", "RWD", 18);

        // Deploy IncentivesPool
        incentivesPool = new IncentivesPool(address(rewardToken));

        // Use this test contract as the board
        testBoard = address(this);

        // Approve test board
        rewardToken.mint(address(this), 1000000e18);
        rewardToken.approve(address(incentivesPool), 1000000e18);
        incentivesPool.addFundsToPool(1000000e18);
        incentivesPool.approveBoard(testBoard, 100000e18, 10000e18);

        // Initialize incentives config for testing
        uint256[] memory params = new uint256[](3);
        params[0] = 1 * 1e18;
        params[1] = 2 * 1e18;
        params[2] = 3 * 1e18;
        testConfig = IIncentivizer.IncentivesConfig({
            incentiveType: IIncentivizer.IncentiveType.Linear,
            incentiveParametersWAD: params
        });
    }

    /*//////////////////////////////////////////////////////////////
                    GET BUCKET MULTIPLIERS TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test getBucketMultipliers with numberOfBuckets = 1
    function test_GetBucketMultipliers_SingleBucket() public {
        // Act
        uint256[] memory multipliers = IncentivesMath.getBucketMultipliers(testConfig.incentiveParametersWAD, 1);

        // Assert: Should return [1e18] (100%)
        assertEq(multipliers.length, 1);
        assertEq(multipliers[0], 1e18);
    }

    /// @notice Test getBucketMultipliers with numberOfBuckets = 2
    function test_GetBucketMultipliers_TwoBuckets() public {
        // Config is [1, 2, 3], with 2 buckets should use first and last: [1, 3]
        // Act
        uint256[] memory multipliers = IncentivesMath.getBucketMultipliers(testConfig.incentiveParametersWAD, 2);

        // Assert: Should use outermost config values
        assertEq(multipliers.length, 2);
        assertEq(multipliers[0], 25 * 1e16);
        assertEq(multipliers[1], 75 * 1e16);
    }

    function test_GetBucketMultipliers_ValleyParams() public {
        uint256[] memory valleyParams = new uint256[](3);
        valleyParams[0] = 3 * 1e18;
        valleyParams[1] = 1 * 1e18;
        valleyParams[2] = 2 * 1e18;

        IIncentivizer.IncentivesConfig memory valleyConfig = IIncentivizer.IncentivesConfig({
            incentiveType: IIncentivizer.IncentiveType.Linear,
            incentiveParametersWAD: valleyParams
        });

        uint256[] memory multipliers = IncentivesMath.getBucketMultipliers(valleyConfig.incentiveParametersWAD, 6);
        assertEq(multipliers.length, 6);
        for (uint256 i = 0; i < multipliers.length; i++) {
            console.log("multiplier", i, multipliers[i]);
        }
    }

    /// @notice Test that getBucketMultipliers output sums to 1e18 (normalization)
    function test_GetBucketMultipliers_SumsToOne() public {
        // Test with various bucket counts
        uint256[] memory bucketCounts = new uint256[](5);
        bucketCounts[0] = 1;
        bucketCounts[1] = 2;
        bucketCounts[2] = 3;
        bucketCounts[3] = 6;
        bucketCounts[4] = 12;

        for (uint256 i = 0; i < bucketCounts.length; i++) {
            uint256[] memory multipliers =
                IncentivesMath.getBucketMultipliers(testConfig.incentiveParametersWAD, bucketCounts[i]);

            uint256 sum = 0;
            for (uint256 j = 0; j < multipliers.length; j++) {
                sum += multipliers[j];
            }

            // Sum should equal 1e18 (100%) - allow for minimal rounding error
            assertApproxEqAbs(sum, 1e18, bucketCounts[i], "Multipliers should sum to ~1e18");
        }
    }

    /// @notice Test getBucketMultipliers with equal config values
    function test_GetBucketMultipliers_EqualValues() public {
        // Setup: All config values equal
        uint256[] memory equalParams = new uint256[](3);
        equalParams[0] = 5;
        equalParams[1] = 5;
        equalParams[2] = 5;

        IIncentivizer.IncentivesConfig memory equalConfig = IIncentivizer.IncentivesConfig({
            incentiveType: IIncentivizer.IncentiveType.Linear,
            incentiveParametersWAD: equalParams
        });

        // Act
        uint256[] memory multipliers = IncentivesMath.getBucketMultipliers(equalConfig.incentiveParametersWAD, 3);

        // Assert: All multipliers should be equal (~1e18 / 3 each)
        assertEq(multipliers.length, 3);
        // Each should be approximately 333333333333333333 (1e18 / 3)
        // Allow for rounding differences
        assertApproxEqAbs(multipliers[0], 333333333333333333, 1);
        assertApproxEqAbs(multipliers[1], 333333333333333333, 1);
        assertApproxEqAbs(multipliers[2], 333333333333333333, 1);
    }
}

/*//////////////////////////////////////////////////////////////
            TEST CONTRACTS FOR INTERNAL FUNCTIONS
//////////////////////////////////////////////////////////////*/

/**
 * @title IncentivesPoolHarnessForTest
 * @notice Wrapper contract that inherits from IncentivesPool to expose internal functions
 * @dev This contract can access internal functions of IncentivesPool
 */
contract IncentivesPoolHarnessForTest is IncentivesPool {
    uint256 constant INCENTIVE_RESOLUTION_LOCAL = 24;

    constructor(address REWARD_TOKEN_) IncentivesPool(REWARD_TOKEN_) {}

    /// @notice Exposes the internal _reduceIncentiveBuckets function
    function exposed_reduceIncentiveBuckets(address board, uint256 initiativeId) external {
        _reduceIncentiveBuckets(_incentiveBucketsByInitiative[board][initiativeId]);
    }

    /// @notice Helper to set buckets for testing
    function setBucketsForTest(
        address board,
        uint256 initiativeId,
        IncentiveBucket[24] memory buckets
    ) external {
        for (uint256 i = 0; i < INCENTIVE_RESOLUTION_LOCAL; i++) {
            _incentiveBucketsByInitiative[board][initiativeId][i] = buckets[i];
        }
    }

    /// @notice Helper to get buckets for assertions
    function getBucketsForTest(address board, uint256 initiativeId)
        external
        view
        returns (IncentiveBucket[24] memory buckets)
    {
        for (uint256 i = 0; i < INCENTIVE_RESOLUTION_LOCAL; i++) {
            buckets[i] = _incentiveBucketsByInitiative[board][initiativeId][i];
        }
    }
}

/**
 * @title IncentivesPoolInternalsTest
 * @notice Tests for IncentivesPool internal functions
 * @dev Uses IncentivesPoolHarnessForTest to access internal functions
 */
contract IncentivesPoolInternalsTest is Test {
    IncentivesPoolHarnessForTest public incentivesPool;
    MockERC20 public rewardToken;
    address public testBoard;
    uint256 constant TEST_INITIATIVE_ID = 1;
    uint256 constant INCENTIVE_RESOLUTION = 24;

    function setUp() public {
        // Deploy reward token
        rewardToken = new MockERC20("Reward", "RWD", 18);

        // Deploy IncentivesPool harness
        incentivesPool = new IncentivesPoolHarnessForTest(address(rewardToken));

        // Use this test contract as the board
        testBoard = address(this);
    }

    /// @notice Test that _reduceIncentiveBuckets correctly combines bucket credits
    function test_ReduceIncentiveBuckets() public {
        // Setup: Create buckets with known values
        // [ 100 ][ 200 ][ 300 ][ 400 ][ 500 ][ 600 ]...
        IncentivesPool.IncentiveBucket[INCENTIVE_RESOLUTION] memory buckets;

        for (uint256 i = 0; i < INCENTIVE_RESOLUTION; i++) {
            buckets[i].bucketTotalIncentiveCredits = uint128((i + 1) * 100);
            buckets[i].endTime = uint128(1000 + i * 100); // 1000, 1100, 1200...
        }

        // Set the buckets in the pool
        incentivesPool.setBucketsForTest(testBoard, TEST_INITIATIVE_ID, buckets);

        // Act: Reduce buckets
        incentivesPool.exposed_reduceIncentiveBuckets(testBoard, TEST_INITIATIVE_ID);

        // Get the reduced buckets
        buckets = incentivesPool.getBucketsForTest(testBoard, TEST_INITIATIVE_ID);

        uint256[] memory expectedBucketTotalIncentiveCredits = new uint256[](24);
        expectedBucketTotalIncentiveCredits[0] = 100 + 200;
        expectedBucketTotalIncentiveCredits[1] = 300 + 400;
        expectedBucketTotalIncentiveCredits[2] = 500 + 600;
        expectedBucketTotalIncentiveCredits[3] = 700 + 800;
        expectedBucketTotalIncentiveCredits[4] = 900 + 1000;
        expectedBucketTotalIncentiveCredits[5] = 1100 + 1200;
        expectedBucketTotalIncentiveCredits[6] = 1300 + 1400;
        expectedBucketTotalIncentiveCredits[7] = 1500 + 1600;
        expectedBucketTotalIncentiveCredits[8] = 1700 + 1800;
        expectedBucketTotalIncentiveCredits[9] = 1900 + 2000;
        expectedBucketTotalIncentiveCredits[10] = 2100 + 2200;
        expectedBucketTotalIncentiveCredits[11] = 2300 + 2400;
        expectedBucketTotalIncentiveCredits[12] = 0;
        expectedBucketTotalIncentiveCredits[13] = 0;
        expectedBucketTotalIncentiveCredits[14] = 0;
        expectedBucketTotalIncentiveCredits[15] = 0;
        expectedBucketTotalIncentiveCredits[16] = 0;
        expectedBucketTotalIncentiveCredits[17] = 0;
        expectedBucketTotalIncentiveCredits[18] = 0;
        expectedBucketTotalIncentiveCredits[19] = 0;
        expectedBucketTotalIncentiveCredits[20] = 0;
        expectedBucketTotalIncentiveCredits[21] = 0;
        expectedBucketTotalIncentiveCredits[22] = 0;
        expectedBucketTotalIncentiveCredits[23] = 0;

        uint256 expectedEndTime = 1100;
        for (uint256 i = 0; i < INCENTIVE_RESOLUTION; i++) {
            assertEq(buckets[i].bucketTotalIncentiveCredits, expectedBucketTotalIncentiveCredits[i]);
            assertEq(buckets[i].endTime, expectedEndTime);
            expectedEndTime += 200;
        }
    }
}

/**
 * @title IncentivesMathInternalsTest
 * @notice Test contract that exposes internal IncentivesMath library functions
 * @dev Wraps internal library functions to make them testable
 */
contract IncentivesMathInternalsTest is Test {
    /// @notice Exposes the internal scaleParameters function
    function exposed_scaleParameters(uint256[] memory config, uint256 numberOfBuckets)
        public
        pure
        returns (uint256[] memory)
    {
        return IncentivesMath.scaleParameters(config, numberOfBuckets);
    }

    function test_InterpolateIncentiveConfigParameters() public {
        uint256[] memory params = new uint256[](3);
        params[0] = 1 * 1e18;
        params[1] = 2 * 1e18;
        params[2] = 3 * 1e18;

        uint256[] memory interpolated = exposed_scaleParameters(params, 6);

        // Assert
        assertEq(interpolated.length, 6);
        assertEq(interpolated[0], 10 * 1e17); //1.0
        assertEq(interpolated[1], 14 * 1e17); //1.4
        assertEq(interpolated[2], 18 * 1e17); //1.8
        assertEq(interpolated[3], 22 * 1e17); //2.2
        assertEq(interpolated[4], 26 * 1e17); //2.6
        assertEq(interpolated[5], 30 * 1e17); //3.0

        params[0] = 3 * 1e18;
        params[1] = 2 * 1e18;
        params[2] = 1 * 1e18;

        interpolated = exposed_scaleParameters(params, 6);
        assertEq(interpolated.length, 6);
        assertEq(interpolated[0], 30 * 1e17); //3.0
        assertEq(interpolated[1], 26 * 1e17); //2.6
        assertEq(interpolated[2], 22 * 1e17); //2.2
        assertEq(interpolated[3], 18 * 1e17); //1.8
        assertEq(interpolated[4], 14 * 1e17); //1.4
        assertEq(interpolated[5], 10 * 1e17); //1.0

        uint256[] memory longParams = new uint256[](7);
        longParams[0] = 1 * 1e18;
        longParams[1] = 2 * 1e18;
        longParams[2] = 3 * 1e18;
        longParams[3] = 4 * 1e18;
        longParams[4] = 5 * 1e18;
        longParams[5] = 6 * 1e18;
        longParams[6] = 7 * 1e18;
        interpolated = exposed_scaleParameters(longParams, 3);
        assertEq(interpolated.length, 3);
        assertApproxEqAbs(interpolated[0], 1 * 1e18, 10); //1.0
        assertApproxEqAbs(interpolated[1], 4 * 1e18, 10); //4.0
        assertApproxEqAbs(interpolated[2], 7 * 1e18, 10); //7.0

        uint256[] memory valleyParams = new uint256[](3);
        valleyParams[0] = 3 * 1e18;
        valleyParams[1] = 1 * 1e18;
        valleyParams[2] = 2 * 1e18;
        interpolated = exposed_scaleParameters(valleyParams, 6);
        assertEq(interpolated.length, 6);
        assertApproxEqAbs(interpolated[0], 30 * 1e17, 10); //3.0
        assertApproxEqAbs(interpolated[1], 22 * 1e17, 10); //1.0
        assertApproxEqAbs(interpolated[2], 14 * 1e17, 10); //2.6
        assertApproxEqAbs(interpolated[3], 12 * 1e17, 10); //1.8
        assertApproxEqAbs(interpolated[4], 16 * 1e17, 10); //1.4
        assertApproxEqAbs(interpolated[5], 20 * 1e17, 10); //1.0
    }
}
