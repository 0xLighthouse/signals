// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {FullMath} from "v4-core/libraries/FullMath.sol";
import {FixedPoint96} from "v4-core/libraries/FixedPoint96.sol";
import {LiquidityAmounts} from "./LiquidityAmounts.sol";

uint256 constant ONE_HUNDRED_PERCENT = 100_0000;

struct BondPoolState {
    // The key of the pool
    PoolKey key;
    // Whether the bond token is the first or second currency
    bool bondTokenIsCurrency0;
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
    /// @notice Record profit being added to the pool. Liquidity is used to update profit share for LPS, 
    /// and bond token amount is used to update fee credit.
    /// @param state The state of the pool
    /// @param profitInBondToken The profit in bond token
    /// @param profitInLiquidity The profit in liquidity
    function addProfit(BondPoolState storage state, uint256 profitInBondToken, uint256 profitInLiquidity) internal {
        // how much profit gets credited to fee reduction
        state.creditForSwapFeesInBondToken += int256(profitInBondToken * state.feeCreditPercentAsPips / ONE_HUNDRED_PERCENT);

        // add profit to pool
        uint256 _totalShares = state.totalSharesAdded;
        state.profitPerShare += profitInLiquidity / _totalShares;
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

    /// @notice Get the liquidity value of a given amount of bond token
    /// @param state The state of the pool
    /// @param poolManager The pool manager
    /// @param amountInBondToken The amount of bond token
    /// @return liquidity The liquidity for the amount in bond token
    function getLiquidityForBondTokenAmount(BondPoolState memory state, IPoolManager poolManager, uint256 amountInBondToken) internal view returns (uint256) {
        // Get the current sqrt price of the pool
        (uint160 sqrtPriceX96,,,) = StateLibrary.getSlot0(poolManager, state.key.toId());

        // Get the liquidity for the amount in bond token
        if (state.bondTokenIsCurrency0) {
           int24 maxTick = TickMath.maxUsableTick(state.key.tickSpacing);
           return LiquidityAmounts.getLiquidityForAmount0(sqrtPriceX96, TickMath.getSqrtPriceAtTick(maxTick), amountInBondToken);
        } else {
           int24 minTick = TickMath.minUsableTick(state.key.tickSpacing);
           return LiquidityAmounts.getLiquidityForAmount1(sqrtPriceX96, TickMath.getSqrtPriceAtTick(minTick), amountInBondToken);
        }
    }

    /// @notice Get the amount of bond token that should be swapped for the other asset in order to convert
    /// the whole into liquidity.
    /// @param state The state of the pool
    /// @param poolManager The pool manager
    /// @return amountInBondToken The amount of bond token that would be swapped for the liquidity
    function getSwapAmountForLiquidityConversion(BondPoolState memory state, IPoolManager poolManager, uint256 amountInBondToken) internal view returns (uint256) {
        // Find the ratio of bond token to other asset at current exchange rate, then use that to figure out
        // how much we should swap

        (uint160 sqrtPriceX96,,,) = StateLibrary.getSlot0(poolManager, state.key.toId());

        // Find the amount of liquidity for our baseline amount at the current rate
        uint256 liquidity = getLiquidityForBondTokenAmount(state, poolManager, ONE_HUNDRED_PERCENT);
        
        uint256 amountInOtherAsset;
        if (state.bondTokenIsCurrency0) {
            int24 maxTick = TickMath.maxUsableTick(state.key.tickSpacing);
            amountInOtherAsset = LiquidityAmounts.getAmount1ForLiquidity(sqrtPriceX96, TickMath.getSqrtPriceAtTick(maxTick), uint128(liquidity));
        } else {
            int24 minTick = TickMath.minUsableTick(state.key.tickSpacing);
            amountInOtherAsset = LiquidityAmounts.getAmount0ForLiquidity(sqrtPriceX96, TickMath.getSqrtPriceAtTick(minTick), uint128(liquidity));
        }

        uint256 otherAsset = FullMath.mulDiv(amountInBondToken, amountInOtherAsset, ONE_HUNDRED_PERCENT);
        return otherAsset;
    }

}