// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {FullMath} from "v4-core/libraries/FullMath.sol";
import {FixedPoint96} from "v4-core/libraries/FixedPoint96.sol";
import {LiquidityAmounts} from "./LiquidityAmounts.sol";

import {console} from "forge-std/console.sol";

uint256 constant ONE_HUNDRED_PERCENT = 100_0000;

struct BondPoolState {
    // The key of the pool
    PoolKey key;
    // Whether the bond token is the first or second currency
    bool underlyingIsCurrency0;
    // The liquidity position id of the pool
    bytes32 positionId;
    // The normal swap fee
    uint24 normalSwapFee;
    // The swap fee when credit is available
    uint24 reducedSwapFee;
    // The total liquidity provided by LPs
    uint256 totalSharesAdded;
    // The profit generated per 1e18 of liquidity provided to the pool
    uint256 profitPerShare;
    // When profit is generated, how much goes to reducing the fees of swappers
    uint256 feeCreditPercentAsPips;
    // Amount of credit for reducing fees
    int256 creditForSwapFeesInBondToken;
}

library BondPoolLibrary {
    function getPriceX96(BondPoolState memory state, IPoolManager manager) internal view returns (uint160) {
        (uint160 sqrtPriceX96,,,) = StateLibrary.getSlot0(manager, state.key.toId());
        return sqrtPriceX96;
    }

    /// @notice Record profit being added to the pool. Liquidity is used to update profit share for LPS,
    /// and bond token amount is used to update fee credit. Negative numbers are supported, in case of losses.
    /// @param state The state of the pool
    /// @param profitInLiquidity The profit in liquidity
    function addProfit(BondPoolState storage state, int256 profitInLiquidity, uint160 sqrtPriceX96) internal {
        int256 profitInUnderlying = getUnderlyingAmountForLiquidity(state, profitInLiquidity, sqrtPriceX96);

        // how much profit gets credited to fee reduction
        int256 profitForFeeReduction =
            profitInUnderlying * int256(state.feeCreditPercentAsPips) / int256(ONE_HUNDRED_PERCENT);
        state.creditForSwapFeesInBondToken += profitForFeeReduction;

        // add profit to pool
        uint256 _totalShares = state.totalSharesAdded;
        int256 _profitPerShare = profitInLiquidity / int256(_totalShares);
        if (profitInLiquidity < 0) {
            state.profitPerShare =
                int256(state.profitPerShare) > _profitPerShare ? state.profitPerShare - uint256(-_profitPerShare) : 0;
        } else {
            state.profitPerShare += uint256(_profitPerShare);
        }
    }

    /// @notice Calculate the fee rate for a trade. If there is no fee credit, the normal fee is used.
    /// Otherwise, the reduced fee is used and the fee credit is reduced by the amount of fees collected.
    /// @param state The state of the pool
    /// @param tradeAmountInBondToken The amount of bond token being traded
    /// @return feeRate The fee rate for the trade
    function feeRateForTrade(BondPoolState storage state, uint256 tradeAmountInBondToken) internal returns (uint24) {
        if (state.creditForSwapFeesInBondToken <= 0) {
            // There is no credit available, so we use the normal fee
            return state.normalSwapFee;
        } else {
            // Use available fee credit
            int256 usedCredit = int256(tradeAmountInBondToken * state.reducedSwapFee / ONE_HUNDRED_PERCENT);
            // To keep computation simple, we don't calculate exact fees when a trade's fees would only be
            // partially covered by the credit. If a trade is too big, we just give the user the reduced
            // rate for the full trade and record the deficit to be made up later. This could be swapped
            // in the future to work differently.
            state.creditForSwapFeesInBondToken -= usedCredit;
            return state.reducedSwapFee;
        }
    }

    /// @notice Get the available fee credit for the pool
    /// @param state The state of the pool
    /// @return feeCredit The available fee credit for the pool
    function getFeeCredit(BondPoolState memory state) internal pure returns (int256) {
        return state.creditForSwapFeesInBondToken;
    }

    /// @notice Get the liquidity value of a given amount of underlying token
    /// @param state The state of the pool
    /// @param amountInUnderlying The amount of underlying token
    /// @return liquidity The liquidity for the amount in underlying token
    function getLiquidityForUnderlyingAmount(
        BondPoolState memory state,
        int256 amountInUnderlying,
        uint160 sqrtPriceX96
    ) internal pure returns (int256) {
        uint256 _amountInUnderlying =
            amountInUnderlying < 0 ? uint256(-amountInUnderlying) : uint256(amountInUnderlying);
        // Get the liquidity for the amount in bond token
        uint256 liquidity;
        if (state.underlyingIsCurrency0) {
            int24 maxTick = TickMath.maxUsableTick(state.key.tickSpacing);
            liquidity = LiquidityAmounts.getLiquidityForAmount0(
                sqrtPriceX96, TickMath.getSqrtPriceAtTick(maxTick), _amountInUnderlying
            );
        } else {
            int24 minTick = TickMath.minUsableTick(state.key.tickSpacing);
            liquidity = LiquidityAmounts.getLiquidityForAmount1(
                sqrtPriceX96, TickMath.getSqrtPriceAtTick(minTick), _amountInUnderlying
            );
        }

        if (amountInUnderlying < 0) {
            return -int256(liquidity / 2);
        } else {
            return int256(liquidity / 2);
        }
    }

    function getUnderlyingAmountForLiquidity(BondPoolState memory state, int256 liquidity, uint160 sqrtPriceX96)
        internal
        pure
        returns (int256)
    {
        uint256 _liquidity = liquidity < 0 ? uint256(-liquidity) : uint256(liquidity);

        int24 maxTick = TickMath.maxUsableTick(state.key.tickSpacing);
        int24 minTick = TickMath.minUsableTick(state.key.tickSpacing);

        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(minTick),
            TickMath.getSqrtPriceAtTick(maxTick),
            uint128(_liquidity)
        );

        if (state.underlyingIsCurrency0) {
            return liquidity < 0 ? int256(amount0 * 2) : -int256(amount0 * 2);
        } else {
            return liquidity < 0 ? -int256(amount1 * 2) : int256(amount1 * 2);
        }
    }

    /// @notice Given an amount of bond token, how much should we swap to the other asset
    /// in order to be able to deposit all as liquidity
    /// @param state The state of the pool
    /// @return amountInBondToken The amount of bond token that would be swapped for the liquidity
    function getSwapAmountForConvertBondTokenToLiquidity(
        BondPoolState memory state,
        uint256 amountInBondToken,
        uint160 sqrtPriceX96
    ) internal pure returns (uint256) {
        int24 maxTick = TickMath.maxUsableTick(state.key.tickSpacing);
        int24 minTick = TickMath.minUsableTick(state.key.tickSpacing);

        return _calculateSwapAmountForLiquidityConversion(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(maxTick),
            TickMath.getSqrtPriceAtTick(minTick),
            amountInBondToken,
            state.underlyingIsCurrency0
        );
    }

    function _calculateSwapAmountForLiquidityConversion(
        uint160 priceX96,
        uint160 maxPriceX96,
        uint160 minPriceX96,
        uint256 amountInBondToken,
        bool underlyingIsCurrency0
    ) public pure returns (uint256) {
        uint160 liquidity;

        if (underlyingIsCurrency0) {
            liquidity = LiquidityAmounts.getLiquidityForAmount0(priceX96, maxPriceX96, amountInBondToken);
        } else {
            liquidity = LiquidityAmounts.getLiquidityForAmount1(priceX96, minPriceX96, amountInBondToken);
        }

        (uint256 amount0, uint256 amount1) =
            LiquidityAmounts.getAmountsForLiquidity(priceX96, minPriceX96, maxPriceX96, uint128(liquidity / 2));

        if (underlyingIsCurrency0) {
            return amount1;
        } else {
            return amount0;
        }
    }
}
