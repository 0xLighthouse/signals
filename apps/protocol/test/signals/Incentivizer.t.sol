// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {SignalsHarness} from "../utils/SignalsHarness.sol";
import {SignalsIncentivizer} from "../../src/Incentivizer.sol";

import {ISignals} from "../../src/interfaces/ISignals.sol";
import {IIncentivizer} from "../../src/interfaces/IIncentivizer.sol";
import {Signals} from "../../src/Signals.sol";
import {IncentivesPool} from "../../src/IncentivesPool.sol";
import {MockERC20} from "solady/test/utils/mocks/MockERC20.sol";

/**
 * @title SignalsIncentivizerTest
 * @notice Tests for SignalsIncentivizer internal functions
 * @dev Tests bucket reduction and multiplier calculation logic
 */
contract SignalsIncentivizerTest is Test, SignalsIncentivizer {
    uint256 constant TEST_INITIATIVE_ID = 1;

    function setUp() public {
        // Initialize incentives config for testing
        uint256[] memory params = new uint256[](3);
        params[0] = 1 * 1e18;
        params[1] = 2 * 1e18;
        params[2] = 3 * 1e18;
        _incentivesConfig = IIncentivizer.IncentivesConfig({
            incentiveType: IIncentivizer.IncentiveType.Linear,
            incentiveParametersWAD: params
        });
    }

    /*//////////////////////////////////////////////////////////////
                    REDUCE INCENTIVE BUCKETS TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that _reduceIncentiveBuckets correctly combines bucket credits
    function test_ReduceIncentiveBuckets() public {
        // Setup: Create buckets with known values
        // [ 100 ][ 200 ][ 300 ][ 400 ][ 500 ][ 600 ]...
        IncentiveBucket[INCENTIVE_RESOLUTION] storage buckets =
            _incentiveBucketsByInitiative[TEST_INITIATIVE_ID];

        for (uint256 i = 0; i < INCENTIVE_RESOLUTION; i++) {
            buckets[i].bucketTotalIncentiveCredits = uint128((i + 1) * 100);
            buckets[i].endTime = uint128(1000 + i * 100); // 1000, 1100, 1200...
        }

        // Act: Reduce buckets
        _reduceIncentiveBuckets(buckets);

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

    /*//////////////////////////////////////////////////////////////
                    GET BUCKET MULTIPLIERS TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test _getBucketMultipliers with numberOfBuckets = 1
    function test_GetBucketMultipliers_SingleBucket() public {
        // Act
        uint256[] memory multipliers = _getBucketMultipliers(1);

        // Assert: Should return [1e18] (100%)
        assertEq(multipliers.length, 1);
        assertEq(multipliers[0], 1e18);
    }

    /// @notice Test _getBucketMultipliers with numberOfBuckets = 2
    function test_GetBucketMultipliers_TwoBuckets() public {
        // Config is [1, 2, 3], with 2 buckets should use first and last: [1, 3]
        // Act
        uint256[] memory multipliers = _getBucketMultipliers(2);

        // Assert: Should use outermost config values
        assertEq(multipliers.length, 2);
        assertEq(multipliers[0], 25 * 1e16);
        assertEq(multipliers[1], 75 * 1e16);
    }

    function test_InterpolateIncentiveConfigParameters() public {
        uint256[] memory params = new uint256[](3);
        params[0] = 1 * 1e18;
        params[1] = 2 * 1e18;
        params[2] = 3 * 1e18;

        uint256[] memory interpolated = _scaleIncentiveConfigParameters(params, 6);

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

        interpolated = _scaleIncentiveConfigParameters(params, 6);
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
        interpolated = _scaleIncentiveConfigParameters(longParams, 3);
        assertEq(interpolated.length, 3);
        assertApproxEqAbs(interpolated[0], 1 * 1e18, 10); //1.0
        assertApproxEqAbs(interpolated[1], 4 * 1e18, 10); //4.0
        assertApproxEqAbs(interpolated[2], 7 * 1e18, 10); //7.0
    }

    /// @notice Test that _getBucketMultipliers output sums to 1e18 (normalization)
    function test_GetBucketMultipliers_SumsToOne() public {
        // Test with various bucket counts
        uint256[] memory bucketCounts = new uint256[](5);
        bucketCounts[0] = 1;
        bucketCounts[1] = 2;
        bucketCounts[2] = 3;
        bucketCounts[3] = 6;
        bucketCounts[4] = 12;

        for (uint256 i = 0; i < bucketCounts.length; i++) {
            uint256[] memory multipliers = _getBucketMultipliers(bucketCounts[i]);

            uint256 sum = 0;
            for (uint256 j = 0; j < multipliers.length; j++) {
                sum += multipliers[j];
            }

            // Sum should equal 1e18 (100%) - allow for minimal rounding error
            assertApproxEqAbs(sum, 1e18, bucketCounts[i], "Multipliers should sum to ~1e18");
        }
    }

    /// @notice Test _getBucketMultipliers with equal config values
    function test_GetBucketMultipliers_EqualValues() public {
        // Setup: All config values equal
        uint256[] memory equalParams = new uint256[](3);
        equalParams[0] = 5;
        equalParams[1] = 5;
        equalParams[2] = 5;
        _incentivesConfig.incentiveParametersWAD = equalParams;

        // Act
        uint256[] memory multipliers = _getBucketMultipliers(3);

        // Assert: All multipliers should be equal (~1e18 / 3 each)
        assertEq(multipliers.length, 3);
        // Each should be approximately 333333333333333333 (1e18 / 3)
        // Allow for rounding differences
        assertApproxEqAbs(multipliers[0], 333333333333333333, 1);
        assertApproxEqAbs(multipliers[1], 333333333333333333, 1);
        assertApproxEqAbs(multipliers[2], 333333333333333333, 1);
    }
}
