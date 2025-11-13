/**
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
pragma solidity ^0.8.24;

/**
 * @title IncentivesMath
 * @notice Externalized math helpers for SignalsIncentivizer to reduce Signals runtime size
 * @dev These functions are pure and can be called via DELEGATECALL through the library,
 *      moving heavy code out of the main contract's runtime.
 */
library IncentivesMath {
    /**
     * @notice Perform geometric linear interpolation between two points
     * @param x Desired x position
     * @param x1 Known x1 position
     * @param y1 Known y1 value
     * @param x2 Known x2 position
     * @param y2 Known y2 value
     * @return Interpolated y value at x
     */
    function geometricLinearInterpolation(uint256 x, uint256 x1, uint256 y1, uint256 x2, uint256 y2)
        public
        pure
        returns (uint256)
    {
        return uint256(
            int256(y1)
                + ((int256(x) - int256(x1)) * (int256(y2) - int256(y1))) / (int256(x2) - int256(x1))
        );
    }

    /**
     * @notice Scale incentive config parameters to a desired number of buckets using linear interpolation
     * @param config The original incentive configuration values (WAD)
     * @param numberOfBuckets The desired number of buckets to interpolate to
     * @return interpolated The interpolated values (not normalized)
     */
    function scaleParameters(uint256[] memory config, uint256 numberOfBuckets)
        internal
        pure
        returns (uint256[] memory interpolated)
    {
        interpolated = new uint256[](numberOfBuckets);
        // If there is only one bucket, we just use a value of 1e18
        if (numberOfBuckets == 1) {
            interpolated[0] = 1e18;
            return interpolated;
        }

        if (numberOfBuckets == config.length) {
            // Return the config directly if the scales match
            return config;
        } else {
            // The first and the last buckets don't change, so we can just set them to the first and last config values.
            interpolated[0] = config[0];
            interpolated[interpolated.length - 1] = config[config.length - 1];
        }

        if (numberOfBuckets > 2) {
            // We will think of index/value as an X/Y coordinate. We can then convert the X coordinates to match the scale of the
            // number of buckets, and use linear interpolation to find Y values for each bucket..

            // Convert indexes into WAD
            uint256[] memory indexes = new uint256[](config.length);
            for (uint256 i = 0; i < config.length; i++) {
                indexes[i] = i * 1e18;
            }

            // Find the multiplier, based on the scale difference between the two (0-index).
            // Multiplying the index of the last config by this number should give the index of the last bucket.
            uint256 multiplier = ((numberOfBuckets - 1) * 1e18) / (config.length - 1);

            // Scale the config indexes to match the number of buckets.
            for (uint256 i = 0; i < indexes.length; i++) {
                indexes[i] = (indexes[i] * multiplier) / 1e18;
            }

            // Thinking of it like XY coordinates, use linear interpolation to find the Y coordinate (value)
            // for the X coordinate (index) of each bucket.
            // We can make the lookup efficient by keeping track of the last config index and using it to find the next config index (since we know the bucket index is always increasing).
            uint256 lastConfigIndex = 0;

            for (uint256 i = 1; i < numberOfBuckets - 1; i++) {
                uint256 desiredX = i * 1e18;
                while (indexes[lastConfigIndex + 1] < desiredX) {
                    unchecked {
                        lastConfigIndex++;
                    }
                }

                interpolated[i] = geometricLinearInterpolation(
                    desiredX,
                    indexes[lastConfigIndex],
                    config[lastConfigIndex],
                    indexes[lastConfigIndex + 1],
                    config[lastConfigIndex + 1]
                );
            }
        }
        return interpolated;
    }

    /**
     * @notice Generate normalized bucket multipliers (percentages in WAD) for a given config and bucket count
     * @param parametersWAD The incentive configuration values (WAD)
     * @param numberOfBuckets Number of buckets to generate
     * @return multipliers Normalized multipliers per bucket (sum ~= 1e18)
     */
    function getBucketMultipliers(uint256[] memory parametersWAD, uint256 numberOfBuckets)
        public
        pure
        returns (uint256[] memory multipliers)
    {
        multipliers = scaleParameters(parametersWAD, numberOfBuckets);

        uint256 totalInterpolatedValues = 0;

        // Sum all interpolated values
        for (uint256 i = 0; i < multipliers.length; i++) {
            totalInterpolatedValues += multipliers[i];
        }

        // Replace each value with its percentage of the whole
        for (uint256 i = 0; i < multipliers.length; i++) {
            multipliers[i] = (multipliers[i] * 1e18) / totalInterpolatedValues;
        }

        return multipliers;
    }
}
