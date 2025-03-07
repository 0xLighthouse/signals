// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseHook } from "v4-periphery/utils/BaseHook.sol";

// temporary:
import { ERC20 } from "solmate/tokens/ERC20.sol";
import "forge-std/console.sol";

import { CurrencyLibrary, Currency } from "v4-core/types/Currency.sol";
import { PoolKey } from "v4-core/types/PoolKey.sol";
import { PoolId } from "v4-core/types/PoolId.sol";
import { Position } from "v4-core/libraries/Position.sol";
import { BalanceDeltaLibrary, BalanceDelta } from "v4-core/types/BalanceDelta.sol";
import { toBeforeSwapDelta, BeforeSwapDelta, BeforeSwapDeltaLibrary } from "v4-core/types/BeforeSwapDelta.sol";
import { IPoolManager } from "v4-core/interfaces/IPoolManager.sol";
import { Hooks } from "v4-core/libraries/Hooks.sol";
import { TickMath } from "v4-core/libraries/TickMath.sol";
import { StateLibrary } from "v4-core/libraries/StateLibrary.sol";
import { SafeCallback } from "v4-periphery/base/SafeCallback.sol";
import { ImmutableState } from "v4-periphery/base/ImmutableState.sol";
import { IBondIssuer } from "./interfaces/IBondIssuer.sol";
import { IBondPricing } from "./interfaces/IBondPricing.sol";

import "./PipsLib.sol";

struct BondPoolState {
    // The liquidity position id of the pool
    bytes32 positionId;
    // If the underlying currency is currency0 or currency1.
    bool bondTokenIsCurrency0;
    // The total liquidity provided by LPs
    uint256 totalSharesAdded;
    // The profit generated per 1e18 of liquidity provided to the pool
    uint256 profitPerShare;
}

struct CallbackData {
    Action action;
    address sender;
    bytes data;
}

// Which action is being taken in the callback
enum Action {
    Liquidity,
    Swap
}

// Data needed to add or remove liquidity
struct LiquidityData {
    PoolKey poolKey;
    int128 liquidityDelta;
    uint160 swapPriceLimit;
    DesiredCurrency desiredCurrency;
}

// Data needed to swap for an NFT
struct SwapData {
    PoolKey poolKey;
    uint256 tokenId;
    uint256 bondPriceLimit;
    uint160 swapPriceLimit;
    DesiredCurrency desiredCurrency;
}

// Which currency the user wants to pay or receive when swapping for an NFT
enum DesiredCurrency {
    Currency0,
    Currency1,
    Mixed
}

struct LiquidityPosition {
    // Total amount of liquidity currently provided
    uint256 amount;
    // Total profit debt so far (can be negative if rewards were earned and not claimed)
    int256 profitDebt;
}

/**
 * - LPs provide need to provide single sided liquidity to a pool
 * - Bonds can be sold into the pool
 *    - revert when not enough liquidity is provided
 * - Bonds can be purchased from the pool
 * - Bonds can be redeemed for the underlying asset into the pool
 *    - revert when bond is not mature
 */
contract BondHook is BaseHook {
    using CurrencyLibrary for Currency;
    using BeforeSwapDeltaLibrary for BeforeSwapDelta;
    using PipsLib for uint256;

    IBondIssuer public immutable signals;
    IBondPricing public bondPricing;

    address public immutable owner;
    // The address of the token that is contained in the bonds
    Currency public immutable bondToken;

    // Record whether the bond token is currency 0 or 1 for each pool
    mapping(PoolId => BondPoolState) internal bondPools;

    // Modify the mapping
    mapping(PoolId => mapping(address => LiquidityPosition)) internal liquidityProviders;

    // Record which pool each bond belongs to
    mapping(uint256 => PoolId) public bondBelongsTo;

    // Record the amount paid out for each bond
    mapping(uint256 => uint256) internal amountPaidOutFor;

    // Errors
    error PoolNotInitialized();
    error InvalidPool();
    error InvalidAction();
    error InsufficientLiquidity();
    error InvalidLiquidityDelta();
    // Events

    event PoolAdded(PoolId indexed poolId);
    event BondSold(PoolId indexed poolId, uint256 indexed tokenId, address indexed buyer, uint256 amount);
    event BondPurchased(PoolId indexed poolId, uint256 indexed tokenId, address indexed seller, uint256 amount);
    event LiquidityAdded(PoolId indexed poolId, address indexed provider, uint256 amount);
    event LiquidityRemoved(PoolId indexed poolId, address indexed provider, uint256 amount);
    event RewardsClaimed(PoolId indexed poolId, address indexed provider, int256 profit);

    constructor(IPoolManager _poolManager, address _signals, address _bondPricing) BaseHook(_poolManager) {
        signals = IBondIssuer(_signals);
        bondToken = Currency.wrap(address(_signals));
        bondPricing = IBondPricing(_bondPricing);
        owner = msg.sender;
    }

    // We receive an int128, to leave room for casting negative values to uint
    function modifyLiquidity(LiquidityData calldata data) external {
        if (bondPools[data.poolKey.toId()].positionId == bytes32(0)) {
            revert PoolNotInitialized();
        }

        // This can be called directly by an EOA, so msg.sender is the owner of the tokens
        poolManager.unlock(
            abi.encode(CallbackData({ action: Action.Liquidity, sender: msg.sender, data: abi.encode(data) }))
        );
    }

    function swapBond(SwapData calldata data) external {
        if (bondPools[data.poolKey.toId()].positionId == bytes32(0)) {
            revert PoolNotInitialized();
        }

        poolManager.unlock(
            abi.encode(CallbackData({ action: Action.Swap, sender: msg.sender, data: abi.encode(data) }))
        );
    }

    // poolManager.unlock will call back to here, so we need to figure out which action we are taking
    function unlockCallback(bytes calldata data) external onlyPoolManager returns (bytes memory empty) {
        CallbackData memory callbackData = abi.decode(data, (CallbackData));
        if (callbackData.action > Action.Swap) {
            revert InvalidAction();
        }

        if (callbackData.action == Action.Liquidity) {
            LiquidityData memory liquidityData = abi.decode(callbackData.data, (LiquidityData));
            if (liquidityData.liquidityDelta == 0) {
                revert InvalidLiquidityDelta();
            } else if (liquidityData.liquidityDelta > 0) {
                // Add liquidity
                _addLiquidity(callbackData.sender, liquidityData);
            } else {
                // Remove liquidity
                _removeLiquidity(callbackData.sender, liquidityData);
            }
        } else {
            SwapData memory swapData = abi.decode(callbackData.data, (SwapData));
            if (PoolId.unwrap(bondBelongsTo[swapData.tokenId]) == 0) {
                // Sell bond to us
                _sellBond(callbackData.sender, swapData);
            } else {
                // Buy bond from us
                _buyBond(callbackData.sender, swapData);
            }
        }
    }

    function _addLiquidity(address sender, LiquidityData memory data) internal {
        _modifyLiquidity({
            key: data.poolKey,
            sender: sender,
            liquidityDelta: data.liquidityDelta,
            desiredCurrency: data.desiredCurrency,
            swapPriceLimit: data.swapPriceLimit
        });

        // Credit the user with having added liquidity -- we know the delta is positive
        liquidityProviders[data.poolKey.toId()][sender].amount += uint256(uint128(data.liquidityDelta));

        // Calculate how many shares of liquidity they are adding, and how much existing profit they should
        // miss out on
        uint256 shares = _getSharesFromLiquidity(uint256(uint128(data.liquidityDelta)));
        liquidityProviders[data.poolKey.toId()][sender].profitDebt +=
            int256(shares * bondPools[data.poolKey.toId()].profitPerShare);

        bondPools[data.poolKey.toId()].totalSharesAdded += shares;

        emit LiquidityAdded(data.poolKey.toId(), sender, uint256(uint128(data.liquidityDelta)));
    }

    function _removeLiquidity(address sender, LiquidityData memory data) internal {
        //to implement
        if (uint256(uint128(-data.liquidityDelta)) > liquidityProviders[data.poolKey.toId()][sender].amount) {
            revert InsufficientLiquidity();
        }

        _modifyLiquidity({
            key: data.poolKey,
            sender: sender,
            liquidityDelta: data.liquidityDelta,
            desiredCurrency: data.desiredCurrency,
            swapPriceLimit: data.swapPriceLimit
        });

        liquidityProviders[data.poolKey.toId()][sender].amount -= uint256(uint128(-data.liquidityDelta));

        // Calculate how many shares of liquidity they are removing, and how much profit they should
        // be owed
        uint256 shares = _getSharesFromLiquidity(uint256(uint128(-data.liquidityDelta)));
        liquidityProviders[data.poolKey.toId()][sender].profitDebt -=
            int256(shares * bondPools[data.poolKey.toId()].profitPerShare);

        bondPools[data.poolKey.toId()].totalSharesAdded -= shares;
    }

    // function _updateLiquidityCheckpoint(PoolId id, address user, int256 liquidityDelta) internal {
    //     LiquidityPosition memory previous = liquidityProviders[id][user];
    // }

    function _sellBond(address sender, SwapData memory data) internal {
        // The user is selling to us
        uint256 price = getPoolBuyPrice(data.tokenId);
        require(price >= data.bondPriceLimit, "BondHook: Desired price not met");
        // Take bond and record who now owns it
        signals.transferFrom(sender, address(this), data.tokenId);
        bondBelongsTo[data.tokenId] = data.poolKey.toId();

        // Record how much liquidity was spent on it
        amountPaidOutFor[data.tokenId] = price / 2;

        _modifyLiquidity({
            key: data.poolKey,
            sender: sender,
            liquidityDelta: -int256(price / 2),
            desiredCurrency: data.desiredCurrency,
            swapPriceLimit: data.swapPriceLimit
        });

        emit BondSold(data.poolKey.toId(), data.tokenId, sender, uint256(uint128(price)));
    }

    function _buyBond(address sender, SwapData memory data) internal {
        // Only allow to buy from the pool that the bond belongs to
        if (PoolId.unwrap(bondBelongsTo[data.tokenId]) != PoolId.unwrap(data.poolKey.toId())) {
            revert InvalidPool();
        }

        // The user is buying from us
        uint256 price = getPoolSellPrice(data.tokenId);
        require(price <= data.bondPriceLimit, "BondHook: Desired price exceeded");

        // record how much profit was generated
        uint256 profit = price / 2 - amountPaidOutFor[data.tokenId];
        uint256 totalShares = bondPools[data.poolKey.toId()].totalSharesAdded;
        bondPools[data.poolKey.toId()].profitPerShare += profit / totalShares;

        _modifyLiquidity({
            key: data.poolKey,
            sender: sender,
            liquidityDelta: int256(price / 2),
            desiredCurrency: data.desiredCurrency,
            swapPriceLimit: data.swapPriceLimit
        });

        // Transfer the bond to the user
        signals.transferFrom(address(this), sender, data.tokenId);
        bondBelongsTo[data.tokenId] = PoolId.wrap(0);

        emit BondPurchased(data.poolKey.toId(), data.tokenId, sender, uint256(uint128(price)));
    }

    /**
     * @notice Internal function to add or remove liquidity, and optionally swap the unwanted currency
     * @param key The key of the pool
     * @param sender The address of the sender
     * @param liquidityDelta The liquidity delta to modify
     * @param desiredCurrency The desired currency to spend or receive
     * @param swapPriceLimit The price limit for the swap
     */
    function _modifyLiquidity(
        PoolKey memory key,
        address sender,
        int256 liquidityDelta,
        DesiredCurrency desiredCurrency,
        uint160 swapPriceLimit
    ) internal {
        // Add liquidity first, to see what balances we need to make up
        (BalanceDelta delta,) = poolManager.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: TickMath.minUsableTick(key.tickSpacing),
                tickUpper: TickMath.maxUsableTick(key.tickSpacing),
                liquidityDelta: liquidityDelta,
                salt: bytes32(0)
            }),
            ""
        );

        if (desiredCurrency != DesiredCurrency.Mixed) {
            bool zeroForOne;
            int128 amountSpecified;

            if (liquidityDelta > 0) {
                // we are paying in, so desired currency is what we want to spend
                zeroForOne = desiredCurrency == DesiredCurrency.Currency0;
                // Amounts will be negative (since we are paying in), and
                // we need to buy the exact amount of the currency we don't have
                amountSpecified = zeroForOne ? -delta.amount1() : -delta.amount0();
            } else {
                // we are taking out, so desired currency is what we want to receive
                zeroForOne = desiredCurrency == DesiredCurrency.Currency1;
                // Amounts will be positive (since we are taking out), and
                // we need to sell the exact amount of the currency we don't want
                amountSpecified = zeroForOne ? -delta.amount0() : -delta.amount1();
            }

            BalanceDelta swapDelta = poolManager.swap(
                key,
                IPoolManager.SwapParams({
                    zeroForOne: zeroForOne,
                    amountSpecified: amountSpecified,
                    sqrtPriceLimitX96: swapPriceLimit
                }),
                ""
            );

            delta = delta + swapDelta;
        }

        // settle remaining balances with sender
        // If an amount is positive, we "take" from pool to user. If it is negative, we "sync" from user to pool
        if (delta.amount0() > 0) {
            poolManager.take(key.currency0, sender, uint256(uint128(delta.amount0())));
        } else if (delta.amount0() < 0) {
            poolManager.sync(key.currency0);
            ERC20(Currency.unwrap(key.currency0)).transferFrom(
                sender, address(poolManager), uint256(uint128(-delta.amount0()))
            );
            poolManager.settle();
        }
        if (delta.amount1() > 0) {
            poolManager.take(key.currency1, sender, uint256(uint128(delta.amount1())));
        } else if (delta.amount1() < 0) {
            poolManager.sync(key.currency1);
            ERC20(Currency.unwrap(key.currency1)).transferFrom(
                sender, address(poolManager), uint256(uint128(-delta.amount1()))
            );
            poolManager.settle();
        }
    }

    function claimRewards(PoolKey calldata key, DesiredCurrency desiredCurrency, uint160 swapPriceLimit) public {
        // Get user's supplied liquidity, equivalent shares, and profit per share
        LiquidityPosition memory position = liquidityProviders[key.toId()][msg.sender];
        uint256 shares = _getSharesFromLiquidity(position.amount);
        uint256 pps = bondPools[key.toId()].profitPerShare;

        // Calculate profit value of user's shares
        int256 profit = int256(shares * pps);
        int256 liquidityOwed = profit - position.profitDebt;
        // Reset debt
        liquidityProviders[key.toId()][msg.sender].profitDebt = profit;

        // Transfer profit to user
        _modifyLiquidity({
            key: key,
            sender: msg.sender,
            liquidityDelta: -liquidityOwed,
            desiredCurrency: desiredCurrency,
            swapPriceLimit: swapPriceLimit
        });

        emit RewardsClaimed(key.toId(), msg.sender, profit);
    }

    /**
     * @notice Get the balance of the liquidity a user has provided to a pool
     * @param id The ID of the pool
     * @param user The address of the user
     * @return balance The balance of the user
     */
    function balanceOf(PoolId id, address user) public view returns (uint256) {
        return liquidityProviders[id][user].amount;
    }

    /**
     * @notice Get the total liquidity added to a pool, quoted as shares of profit-sharing
     * @param id The ID of the pool
     * @return totalShares The total number of shares added to the pool
     */
    function totalShares(PoolId id) public view returns (uint256) {
        return bondPools[id].totalSharesAdded;
    }

    /**
     * @notice The price the pool would pay for the bond.
     *
     * @param tokenId The ID of the bond token.
     * @return value The current value of the bond.
     */
    function getPoolBuyPrice(uint256 tokenId) public view returns (uint256) {
        IBondIssuer.BondInfo memory bondInfo = signals.getBondInfo(tokenId);
        return bondPricing.getBuyPrice({
            principal: bondInfo.nominalValue,
            startTime: bondInfo.created,
            duration: bondInfo.expires - bondInfo.created,
            currentTime: block.timestamp,
            referenceId: abi.encode(bondInfo.referenceId)
        });
    }

    /**
     * @notice The price the pool would request for the bond.
     *
     * @param tokenId The ID of the bond token.
     * @return value The current value of the bond.
     */
    function getPoolSellPrice(uint256 tokenId) public view returns (uint256) {
        IBondIssuer.BondInfo memory bondInfo = signals.getBondInfo(tokenId);
        return bondPricing.getSellPrice({
            principal: bondInfo.nominalValue,
            startTime: bondInfo.created,
            duration: bondInfo.expires - bondInfo.created,
            currentTime: block.timestamp,
            referenceId: abi.encode(bondInfo.referenceId)
        });
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: true,
            afterSwapReturnDelta: true,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function _beforeInitialize(address, PoolKey calldata key, uint160) internal override returns (bytes4) {
        if (!(key.currency0 == bondToken) && !(key.currency1 == bondToken)) {
            revert InvalidPool();
        }

        // We don't currently support native currency
        if (key.currency0 == Currency.wrap(address(0))) {
            revert InvalidPool();
        }

        bondPools[key.toId()] = BondPoolState({
            positionId: Position.calculatePositionKey({
                owner: address(this),
                tickLower: TickMath.minUsableTick(key.tickSpacing),
                tickUpper: TickMath.maxUsableTick(key.tickSpacing),
                salt: bytes32(0)
            }),
            bondTokenIsCurrency0: key.currency0 == bondToken,
            totalSharesAdded: 0,
            profitPerShare: 0
        });

        emit PoolAdded(key.toId());
        return this.beforeInitialize.selector;
    }

    function _beforeAddLiquidity(address, PoolKey calldata, IPoolManager.ModifyLiquidityParams calldata, bytes calldata)
        internal
        override
        returns (bytes4)
    {
        // TODO: Block usage through uniswap interface? (only allow direct call)
        return this.beforeAddLiquidity.selector;
    }

    function _beforeSwap(address, PoolKey calldata, IPoolManager.SwapParams calldata, bytes calldata)
        internal
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        return (this.beforeSwap.selector, toBeforeSwapDelta(0, 0), uint24(0));
    }

    function _afterSwap(address, PoolKey calldata, IPoolManager.SwapParams calldata, BalanceDelta, bytes calldata)
        internal
        override
        returns (bytes4, int128)
    {
        return (this.afterSwap.selector, int128(0));
    }

    // Calculate how many shares of profit sharing an amount of liquidity is worth
    function _getSharesFromLiquidity(uint256 liquidity) internal pure returns (uint256) {
        return liquidity / 1e6;
    }
}
