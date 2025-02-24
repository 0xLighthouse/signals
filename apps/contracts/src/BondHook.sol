// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/console.sol";

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";

// temporary:
import {ERC20} from "solmate/src/tokens/ERC20.sol";


import {CurrencyLibrary, Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {BalanceDeltaLibrary, BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {toBeforeSwapDelta, BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {SafeCallback} from "v4-periphery/src/base/SafeCallback.sol";
import {ImmutableState} from "v4-periphery/src/base/ImmutableState.sol";
import {Signals} from "./Signals.sol";
import {ISignals} from "./interfaces/ISignals.sol";
import {IBondPricing} from "./interfaces/IBondPricing.sol";

import {PoolTestBase} from "v4-core/test/PoolTestBase.sol";


import "./PipsLib.sol";

struct BondPoolState {
    // If the pool is initialized
    bool initialized;
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
    uint256 desiredPrice;
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

    // Add events
    event Buyer(bytes32 indexed poolId, address indexed liquidityProvider);

    constructor(IPoolManager _poolManager, address _signals, address _bondPricing) BaseHook(_poolManager) {
        signals = Signals(_signals);
        bondToken = Currency.wrap(signals.underlyingToken());
        bondPricing = IBondPricing(_bondPricing);
        owner = msg.sender;
    }

    // We receive an int128, to leave room for casting negative values to uint
    function modifyLiquidity(PoolKey calldata key, int128 liquidityDelta) external {
        if (!bondPools[key.toId()].initialized) {
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

    function swapBond(PoolKey calldata key, uint256 tokenId, uint256 desiredPrice, DesiredCurrency desiredCurrency) external {
        if (!bondPools[key.toId()].initialized) {
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
                        desiredPrice: desiredPrice,
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
        ERC20(Currency.unwrap(key.currency0)).transferFrom(data.sender, address(this), uint256(uint128(-delta.amount0())));
        ERC20(Currency.unwrap(key.currency1)).transferFrom(data.sender, address(this), uint256(uint128(-delta.amount1())));

        // Add liquidity to the pool
        poolManager.sync(key.currency0);
        ERC20(Currency.unwrap(key.currency0)).transfer(address(poolManager), uint256(uint128(-delta.amount0())));
        poolManager.settle();

        poolManager.sync(key.currency1);
        ERC20(Currency.unwrap(key.currency1)).transfer(address(poolManager), uint256(uint128(-delta.amount1())));
        poolManager.settle();

        // Credit the user with having added liquidity -- we know the delta is positive
        liquidityProviders[key.toId()][data.sender] += uint256(uint128(data.liquidityDelta));
        bondPools[key.toId()].totalLiquidityAdded += uint256(uint128(data.liquidityDelta));
    }

    function _removeLiquidity(DepositData memory data) internal {
        //TODO: Implement
    }

    function _sellBond(SwapData memory data) internal {
        // The user is selling to us
        uint256 price = getPoolBuyPrice(data.tokenId);
        require(data.desiredPrice >= price, "BondHook: Desired price not met");
        signals.transferFrom(data.sender, address(this), data.tokenId);

        PoolKey memory key = data.poolKey;

        // Withdraw liquidity from pool -- delta should always be positive
        (BalanceDelta delta, ) = poolManager.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: TickMath.minUsableTick(key.tickSpacing),
                tickUpper: TickMath.maxUsableTick(key.tickSpacing),
                liquidityDelta: -int256(price / 2),
                salt: bytes32(0)
            }),
            ""
        );

        if (data.desiredCurrency == DesiredCurrency.Mixed) {
            console.log("Pay out mixed currency");
            poolManager.take(key.currency0, data.sender, uint256(uint128(delta.amount0())));
            poolManager.take(key.currency1, data.sender, uint256(uint128(delta.amount1())));
        } else {
            console.log("Pay out single currency");
            // TODO: Implement
        }
    }

    function _buyBond(SwapData memory data) internal {
        //TODO: Implement
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
            initialized: true,
            bondTokenIsCurrency0: key.currency0 == bondToken,
            balanceOfBondToken: 0,
            balanceOfOtherToken: 0,
            totalLiquidityAdded: 0
        });

        return this.beforeInitialize.selector;
    }

    function _beforeAddLiquidity(address, PoolKey calldata, IPoolManager.ModifyLiquidityParams calldata, bytes calldata) internal override returns (bytes4) {
    // TODO: Block usage through uniswap interface? (only allow direct call)
        return this.beforeAddLiquidity.selector;
    }

    


    // /**
    //  * @notice The nominal value of the bond is the amount of tokens that will be
    //  * received when the bond is redeemed.
    //  * @param tokenId The ID of the bond token.
    //  * @return value The nominal value of the bond.
    //  */
    // function nominalValue(uint256 tokenId) external view returns (uint256) {
    //     ISignals.LockInfo memory lock = signals.getTokenMetadata(tokenId);
    //     return lock.tokenAmount;
    // }

    /**
     * @notice Get the balance of the liquidity a user has provided to a pool
     * @param id The ID of the pool
     * @param user The address of the user
     * @return balance The balance of the user
     */
    function getBalance(PoolId id, address user) public view returns (uint256) {
        return liquidityProviders[id][user];
    }

    function getTotalLiquidity(PoolId id) public view returns (uint256) {
        return bondPools[id].totalLiquidityAdded;
    }

    /**
     * @notice The current value of the bond is a custom calculation based on
     * the current time.
     *
     * @param tokenId The ID of the bond token.
     * @return value The current value of the bond.
     */
    function getPoolBuyPrice(uint256 tokenId) public view returns (uint256) {
        ISignals.LockInfo memory lock = signals.getTokenMetadata(tokenId);
        // TODO: The interval should be exposed from the Signals contract.
        uint256 interval = 30 days;

        return bondPricing.getBuyPrice({
            principal: lock.tokenAmount,
            startTime: lock.created,
            duration: lock.lockDuration * interval,
            currentTime: block.timestamp,
            bondMetadata: abi.encode(tokenId)
        });
    }

    function getPoolSellPrice(uint256 tokenId) public view returns (uint256) {
        ISignals.LockInfo memory lock = signals.getTokenMetadata(tokenId);
        uint256 interval = 30 days;

        return bondPricing.getSellPrice({
            principal: lock.tokenAmount,
            startTime: lock.created,
            duration: lock.lockDuration * interval,
            currentTime: block.timestamp,
            bondMetadata: abi.encode(tokenId)
        });
    }

    function _beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata swapParams,
        bytes calldata hookData
    ) internal override returns (bytes4, BeforeSwapDelta, uint24) {
       
            return (this.beforeSwap.selector, toBeforeSwapDelta(0, 0), uint24(0));
        // end test



        // if (hookData.length == 0) {
        //      return (this.beforeSwap.selector, toBeforeSwapDelta(-5 * 1e11, 0), uint24(0));
        // }

        // bool isZero = bondPools[key.toId()].bondTokenIsCurrency0;

        // (bool isBuy, uint256 tokenId, uint256 desiredPrice, bytes memory signature) = _parseHookData(hookData);
        // address user = _verifySignature(signature);
        // uint256 price;
        // if (isBuy) {
        //     console.log("BEFORESWAP: Buying bond");
        //     // The user is selling to us
        //     price = getPoolBuyPrice(tokenId);
        //     console.log(price, desiredPrice);
        //     require(desiredPrice <= price, "BondHook: Desired price exceeds buy price");
        // } else {
        //     console.log("BEFORESWAP: Selling bond");
        //     // We are selling the bon   d to the user
        //     price = getPoolSellPrice(tokenId);
        //     console.log(price, desiredPrice);
        //     require(desiredPrice >= price, "BondHook: Desired price below sell price");
        // }

        // if (isBuy) {
        //     // The user is selling to us
        //     signals.transferFrom(user, address(this), tokenId);
        //     // TODO: set up balanceDelta so the user doesn't pay anything to the pool
        // } else {
        //     // We are selling to the user
        //     signals.transferFrom(address(this), user, tokenId);
        //     // TODO: set up balanceDelta so the user doesn't receive anything from the pool
        // }
 
        // // NOTE: WIP
        // // Currency specified;
        // BeforeSwapDelta delta = toBeforeSwapDelta(int128(-100), int128(100));
        // // if (isZero) {
        // //     specified = key.currency0;
        // //  delta = toBeforeSwapDelta(int128(uint128(price)), 0);
        // // } else {
        // //     specified = key.currency1;
        // //  delta = toBeforeSwapDelta(0, int128(uint128(price)));
        // // }
        // // console.log("SPECIFIED:", MockERC20(Currency.unwrap(specified)).symbol());
        // // console.log("SPECIFIED balance:", specified.balanceOf(user));

        // // poolManager.take(specified, user, price);
        // // return (this.beforeSwap.selector, delta, uint24(0));
        


        
        // return (this.beforeSwap.selector, 0, uint24(0));

    }

    function _parseHookData(bytes calldata data)
        internal
        returns (bool isBuy, uint256 tokenId, uint256 desiredPrice, bytes memory signature)
    {
        (tokenId, desiredPrice, signature) = abi.decode(data, (uint256, uint256, bytes));
        // if we own the bond, the pool is not buying
        if (PoolId.unwrap(bondBelongsTo[tokenId]) != bytes32(0)) {
            isBuy = false;
        } else {
            isBuy = true;
        }
        return (isBuy, tokenId, desiredPrice, signature);
    }

    function _afterSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata swapParams,
        BalanceDelta delta,
        bytes calldata hookData
    ) internal override returns (bytes4, int128) {


        if (hookData.length == 0) {
            return (this.afterSwap.selector, int128(0));
        }

        // bool isZero = bondTokenIsZero[key.toId()];

        (bool isBuy, uint256 tokenId, uint256 desiredPrice, bytes memory signature) = _parseHookData(hookData);
        address user = _verifySignature(signature);

        // uint256 price;
        // if (isBuy) {
        //     console.log("SWAP: Buying bond");
        //     // The user is selling to us
        //     price = getPoolBuyPrice(tokenId);
        //     console.log(price, desiredPrice);
        //     require(desiredPrice <= price, "BondHook: Desired price exceeds buy price");
        // } else {
        //     console.log("SWAP: Selling bond");
        //     // We are selling the bon   d to the user
        //     price = getPoolSellPrice(tokenId);
        //     console.log(price, desiredPrice);
        //     require(desiredPrice >= price, "BondHook: Desired price below sell price");
        // }

        // // set the balanceDelta to represent the underlying tokens we are buying or selling for
        // if (swapParams.zeroForOne == isZero) {}

       
        // if (isBuy) {
        //     // The user is selling to us
        //     signals.transferFrom(user, address(this), tokenId);
        //     // TODO: set up balanceDelta so the user doesn't pay anything to the pool
        // } else {
        //     // We are selling to the user
        //     signals.transferFrom(address(this), user, tokenId);
        //     // TODO: set up balanceDelta so the user doesn't receive anything from the pool
        // }


        // Currency specified;
        // if (swapParams.zeroForOne) {
        //     specified = key.currency1;
        // } else {
        //     specified = key.currency0;
        // }

        console.log("DELTA0:", BalanceDeltaLibrary.amount0(delta));
        console.log("DELTA1:", BalanceDeltaLibrary.amount1(delta));

        return (this.afterSwap.selector, int128(0));
    }

    function _verifySignature(bytes memory signature) internal pure returns (address) {
        // Later: signature should include the data we need to find the user's address,
        // for now we just include the user's address as the signature
        return abi.decode(signature, (address));
    }
}
