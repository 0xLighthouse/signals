// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";

// temporary:
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import "forge-std/console.sol";

import {CurrencyLibrary, Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {Position} from "v4-core/libraries/Position.sol";
import {BalanceDeltaLibrary, BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {toBeforeSwapDelta, BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {SafeCallback} from "v4-periphery/src/base/SafeCallback.sol";
import {ImmutableState} from "v4-periphery/src/base/ImmutableState.sol";
import {Signals} from "./Signals.sol";
import {IBondIssuer} from "./interfaces/IBondIssuer.sol";
import {IBondPricing} from "./interfaces/IBondPricing.sol";
import "./PipsLib.sol";

struct BondPoolState {
    // The liquidity position id of the pool
    bytes32 positionId;
    // If the underlying currency is currency0 or currency1.
    bool bondTokenIsCurrency0;
    // The balance of the bond token which belongs to this pool outside of liquidity
    uint256 balanceOfBondToken;
    // The balance of the other token which belongs to this pool outside of liquidity
    uint256 balanceOfOtherToken;
    // The total liquidity provided by LPs
    uint256 totalLiquidityAdded;
}

struct CallbackData {
    Action action;
    bytes data;
}

// Which action is being taken in the callback
enum Action {
    Deposit,
    Swap
}

// Data needed to add or remove liquidity
struct DepositData {
    PoolKey poolKey;
    address sender;
    int128 liquidityDelta;
}

// Data needed to swap for an NFT
struct SwapData {
    PoolKey poolKey;
    address sender;
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

    Signals public immutable signals;
    IBondPricing public bondPricing;

    address public immutable owner;
    // The address of the token that is contained in the bonds
    Currency public immutable bondToken;

    // Record whether the bond token is currency 0 or 1 for each pool
    mapping(PoolId => BondPoolState) internal bondPools;

    // Record who owns how much of each pool
    mapping(PoolId => mapping(address => uint256)) internal liquidityProviders;

    // Record which pool each bond belongs to
    mapping(uint256 => PoolId) public bondBelongsTo;

    // Errors
    error PoolNotInitialized();
    error InvalidPool();
    error InvalidAction();
    error InsufficientLiquidity();
    // Events
    event PoolAdded(PoolId indexed poolId);
    event BondSold(PoolId indexed poolId, uint256 indexed tokenId, address indexed buyer, uint256 amount);
    event BondPurchased(PoolId indexed poolId, uint256 indexed tokenId, address indexed seller, uint256 amount);
    event LiquidityAdded(PoolId indexed poolId, address indexed provider, uint256 amount);
    event LiquidityRemoved(PoolId indexed poolId, address indexed provider, uint256 amount);

    constructor(IPoolManager _poolManager, address _signals, address _bondPricing) BaseHook(_poolManager) {
        signals = Signals(_signals);
        bondToken = Currency.wrap(signals.underlyingToken());
        bondPricing = IBondPricing(_bondPricing);
        owner = msg.sender;
    }

    // We receive an int128, to leave room for casting negative values to uint
    function modifyLiquidity(PoolKey calldata key, int128 liquidityDelta) external {
        if (bondPools[key.toId()].positionId == bytes32(0)) {
            revert PoolNotInitialized();
        }

        // This can be called directly by an EOA, so msg.sender is the owner of the tokens
        poolManager.unlock(
            abi.encode(
                CallbackData({
                    action: Action.Deposit, 
                    data: abi.encode(
                        DepositData({
                            poolKey: key,
                            sender: msg.sender,
                            liquidityDelta: liquidityDelta
                        })
                    )
                })
            )
        );
    }

    function swapBond(PoolKey calldata key, uint256 tokenId, uint256 bondPriceLimit, uint160 swapPriceLimit, DesiredCurrency desiredCurrency) external {
        if (bondPools[key.toId()].positionId == bytes32(0)) {
            revert PoolNotInitialized();
        }

        poolManager.unlock(
            abi.encode(
                CallbackData({
                    action: Action.Swap,
                    data: abi.encode(SwapData({
                        poolKey: key,
                        sender: msg.sender,
                        tokenId: tokenId,
                        bondPriceLimit: bondPriceLimit,
                        swapPriceLimit: swapPriceLimit,
                        desiredCurrency: desiredCurrency
                    })
                    )
                })
            )
        );
    }

    // poolManager.unlock will call back to here, so we need to figure out which action we are taking
    function unlockCallback(bytes calldata data) external onlyPoolManager() returns (bytes memory) {
        CallbackData memory callbackData = abi.decode(data, (CallbackData));
        if (callbackData.action > Action.Swap) {
            revert InvalidAction();
        }

        if (callbackData.action == Action.Deposit) {
            DepositData memory depositData = abi.decode(callbackData.data, (DepositData));
            if (depositData.liquidityDelta > 0) {
                // Add liquidity
                _addLiquidity(depositData);
            } else {
                // Remove liquidity
                _removeLiquidity(depositData);
            }
        } else {
            SwapData memory swapData = abi.decode(callbackData.data, (SwapData));
            if (PoolId.unwrap(bondBelongsTo[swapData.tokenId]) == 0) {
                // Sell bond to us
                _sellBond(swapData);
            } else {
                // Buy bond from us
                _buyBond(swapData);
            }
        }

        return abi.encode("");
    }

    function _addLiquidity(DepositData memory data) internal {
        PoolKey memory key = data.poolKey;

        // Add liquidity to pool, credited to our hook
        (BalanceDelta delta, ) = poolManager.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: TickMath.minUsableTick(key.tickSpacing),
                tickUpper: TickMath.maxUsableTick(key.tickSpacing),
                liquidityDelta: int256(data.liquidityDelta),
                salt: bytes32(0)
            }),
            ""
        );
        // TODO: Support native currency too
        // Based on how much of each currency is set to be deposited, take those funds from the user and add to our hook

        // Add liquidity to the pool
        poolManager.sync(key.currency0);
        ERC20(Currency.unwrap(key.currency0)).transferFrom(data.sender, address(poolManager), uint256(uint128(-delta.amount0())));
        poolManager.settle();

        poolManager.sync(key.currency1);
        ERC20(Currency.unwrap(key.currency1)).transferFrom(data.sender, address(poolManager), uint256(uint128(-delta.amount1())));
        poolManager.settle();

        // Credit the user with having added liquidity -- we know the delta is positive
        liquidityProviders[key.toId()][data.sender] += uint256(uint128(data.liquidityDelta));
        bondPools[key.toId()].totalLiquidityAdded += uint256(uint128(data.liquidityDelta));

        emit LiquidityAdded(key.toId(), data.sender, uint256(uint128(data.liquidityDelta)));

        // Get liquidity of our position
        // uint256 totalLiquidity = StateLibrary.getPositionLiquidity(poolManager, key.toId(), data.sender);
     }

    function _removeLiquidity(DepositData memory data) internal {
        //to implement
        if (uint256(uint128(-data.liquidityDelta)) > liquidityProviders[data.poolKey.toId()][data.sender]) {
            revert InsufficientLiquidity();
        }

    }

    function _sellBond(SwapData memory data) internal {
        // The user is selling to us
        uint256 price = getPoolBuyPrice(data.tokenId);
        require(price >= data.bondPriceLimit, "BondHook: Desired price not met");
        // Take bond and record who now owns it
        signals.transferFrom(data.sender, address(this), data.tokenId);
        bondBelongsTo[data.tokenId] = data.poolKey.toId();

        PoolKey memory key = data.poolKey;

        // Withdraw liquidity from pool to pay user:
        // We specify 50% of the price as the amount of liquidity to withdraw, as we will then 
        // get 50% as one currency and 50% as the other, totaling 100%.
        (BalanceDelta delta, ) = poolManager.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: TickMath.minUsableTick(key.tickSpacing),
                tickUpper: TickMath.maxUsableTick(key.tickSpacing),
                liquidityDelta: -int256(price/2),
                salt: bytes32(0)
            }),
            ""
        );

        if (data.desiredCurrency != DesiredCurrency.Mixed) {
            bool zeroForOne = data.desiredCurrency == DesiredCurrency.Currency1;

            BalanceDelta swapDelta = poolManager.swap(
                key,
                IPoolManager.SwapParams({
                    zeroForOne: zeroForOne,
                    amountSpecified: zeroForOne ? -delta.amount0() : -delta.amount1(),
                    // minimum price limit for now
                    sqrtPriceLimitX96: data.swapPriceLimit
                }),
                ""
            );

            delta = delta + swapDelta;
        }

        if (delta.amount0() > 0) {
            poolManager.take(key.currency0, data.sender, uint256(uint128(delta.amount0())));
        }
        if (delta.amount1() > 0) {
            poolManager.take(key.currency1, data.sender, uint256(uint128(delta.amount1())));
        }

        emit BondSold(key.toId(), data.tokenId, data.sender, uint256(uint128(price)));
    }

    function _buyBond(SwapData memory data) internal {
        // Only allow to buy from the pool that the bond belongs to
        if (PoolId.unwrap(bondBelongsTo[data.tokenId]) != PoolId.unwrap(data.poolKey.toId())) {
            revert InvalidPool();
        }

        // The user is buying from us
        uint256 price = getPoolSellPrice(data.tokenId);
        require(price <= data.bondPriceLimit, "BondHook: Desired price exceeded");
        
        PoolKey memory key = data.poolKey;
        // Add liquidity first, to see what balances we need to make up
        (BalanceDelta delta, ) = poolManager.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: TickMath.minUsableTick(key.tickSpacing),
                tickUpper: TickMath.maxUsableTick(key.tickSpacing),
                liquidityDelta: int256(price/2),
                salt: bytes32(0)
            }),
            ""
        );

        // Do a swap if we want to pay in a single currency
        if (data.desiredCurrency != DesiredCurrency.Mixed) {
            bool zeroForOne = data.desiredCurrency == DesiredCurrency.Currency0;

             BalanceDelta swapDelta = poolManager.swap(
                key,
                IPoolManager.SwapParams({
                    zeroForOne: zeroForOne,
                    amountSpecified: zeroForOne ? -delta.amount1() : -delta.amount0(),
                    sqrtPriceLimitX96: data.swapPriceLimit
                }),
                ""
            );

            delta = delta + swapDelta;
        }

        // Take the funds from the user
        if (delta.amount0() < 0) {
            poolManager.sync(key.currency0);
            ERC20(Currency.unwrap(key.currency0)).transferFrom(data.sender, address(poolManager), uint256(uint128(-delta.amount0())));
            poolManager.settle();
        }
        if (delta.amount1() < 0) {
            poolManager.sync(key.currency1);
            ERC20(Currency.unwrap(key.currency1)).transferFrom(data.sender, address(poolManager), uint256(uint128(-delta.amount1())));
            poolManager.settle();
        }

        // Transfer the bond to the user
        signals.transferFrom(address(this), data.sender, data.tokenId);
        bondBelongsTo[data.tokenId] = PoolId.wrap(0);
        
        emit BondPurchased(key.toId(), data.tokenId, data.sender, uint256(uint128(price)));
    }

        /**
     * @notice Get the balance of the liquidity a user has provided to a pool
     * @param id The ID of the pool
     * @param user The address of the user
     * @return balance The balance of the user
     */
    function balanceOf(PoolId id, address user) public view returns (uint256) {
        return liquidityProviders[id][user];
    }

    /**
     * @notice Get the total liquidity added to a pool
     * @param id The ID of the pool
     * @return totalLiquidity The total liquidity added to the pool
     */
    function totalLiquidity(PoolId id) public view returns (uint256) {
        return bondPools[id].totalLiquidityAdded;
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
 
        bondPools[key.toId()] = BondPoolState({
            positionId: Position.calculatePositionKey({
                owner: address(this),
                tickLower: TickMath.minUsableTick(key.tickSpacing),
                tickUpper: TickMath.maxUsableTick(key.tickSpacing),
                salt: bytes32(0)
            }),
            bondTokenIsCurrency0: key.currency0 == bondToken,
            balanceOfBondToken: 0,
            balanceOfOtherToken: 0,
            totalLiquidityAdded: 0
        });

        emit PoolAdded(key.toId());
        return this.beforeInitialize.selector;
    }

    function _beforeAddLiquidity(address, PoolKey calldata, IPoolManager.ModifyLiquidityParams calldata, bytes calldata) internal override returns (bytes4) {
    // TODO: Block usage through uniswap interface? (only allow direct call)
        return this.beforeAddLiquidity.selector;
    }

    function _beforeSwap(
        address,
        PoolKey calldata,
        IPoolManager.SwapParams calldata,
        bytes calldata
    ) internal override returns (bytes4, BeforeSwapDelta, uint24) {
        return (this.beforeSwap.selector, toBeforeSwapDelta(0, 0), uint24(0));
    }

    function _afterSwap(
        address,
        PoolKey calldata,
        IPoolManager.SwapParams calldata,
        BalanceDelta,
        bytes calldata
    ) internal override returns (bytes4, int128) {
        return (this.afterSwap.selector, int128(0));
    }
}
