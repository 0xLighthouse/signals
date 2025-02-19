// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/console.sol";

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";

// temporary:
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";


import {CurrencyLibrary, Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {BalanceDeltaLibrary, BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {toBeforeSwapDelta, BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";

import {Signals} from "./Signals.sol";
import {ISignals} from "./interfaces/ISignals.sol";
import {IBondPricing} from "./interfaces/IBondPricing.sol";

import "./PipsLib.sol";

struct BondPoolState {
    // If the underlying currency is currency 1 in the pool, set to 1.
    // If it is currency 0, set to 2. 
    // If it is set to 0, the pool is not initialized.
    uint256 bondTokenCurrency;
    // The balance of the bond token which belongs to this pool outside of liquidity
    uint256 balanceOfBondToken;
    // The balance of the other token which belongs to this pool outside of liquidity
    uint256 balanceOfOtherToken;
    // The total liquidity provided by LPs
    uint256 totalLiquidity;
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

    // Add events
    event Buyer(bytes32 indexed poolId, address indexed liquidityProvider);

    constructor(IPoolManager _poolManager, address _signals, address _bondPricing) BaseHook(_poolManager) {
        signals = Signals(_signals);
        bondToken = Currency.wrap(signals.underlyingToken());
        bondPricing = IBondPricing(_bondPricing);
        owner = msg.sender;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: true,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function _beforeInitialize(address, PoolKey calldata key, uint160) internal override returns (bytes4) {
        if (!(key.currency0 == bondToken) && !(key.currency1 == bondToken)) {
            revert("BondHook: Pool does not contain bond token");
        }
        bondPools[key.toId()] = BondPoolState({
            bondTokenCurrency: key.currency1 == bondToken ? 1 : 2,
            balanceOfBondToken: 0,
            balanceOfOtherToken: 0,
            totalLiquidity: 0
        });

        return this.beforeInitialize.selector;
    }

    function addLiquidity(PoolKey calldata key, IPoolManager.ModifyLiquidityParams calldata params) public {
        if (bondPools[key.toId()].bondTokenCurrency == 0) {
        revert("BondHook: Pool is not initialized");
        }
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
        address ,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata swapParams,
        bytes calldata hookData
    ) internal override returns (bytes4, BeforeSwapDelta, uint24) {
        if (hookData.length == 0) {
            return (this.beforeSwap.selector, BeforeSwapDelta.wrap(0), uint24(0));
        }

        bool bondTokenZero = bondPools[key.toId()].bondTokenCurrency == 2;

        (bool isBuy, uint256 tokenId, uint256 desiredPrice, bytes memory signature) = _parseHookData(hookData);
        address user = _verifySignature(signature);
        uint256 price;
        if (isBuy) {
            console.log("BEFORESWAP: Buying bond");
            // The user is selling to us
            price = getPoolBuyPrice(tokenId);
            console.log(price, desiredPrice);
            require(desiredPrice <= price, "BondHook: Desired price exceeds buy price");
        } else {
            console.log("BEFORESWAP: Selling bond");
            // We are selling the bon   d to the user
            price = getPoolSellPrice(tokenId);
            console.log(price, desiredPrice);
            require(desiredPrice >= price, "BondHook: Desired price below sell price");
        }

        if (isBuy) {
            // The user is selling to us
            signals.transferFrom(user, address(this), tokenId);
            // TODO: set up balanceDelta so the user doesn't pay anything to the pool
        } else {
            // We are selling to the user
            signals.transferFrom(address(this), user, tokenId);
            // TODO: set up balanceDelta so the user doesn't receive anything from the pool
        }
 
        // NOTE: WIP
        // Currency specified;
        BeforeSwapDelta delta = toBeforeSwapDelta(int128(-100), int128(100));
        // if (bondTokenZero) {
        //     specified = key.currency0;
        //  delta = toBeforeSwapDelta(int128(uint128(price)), 0);
        // } else {
        //     specified = key.currency1;
        //  delta = toBeforeSwapDelta(0, int128(uint128(price)));
        // }
        // console.log("SPECIFIED:", MockERC20(Currency.unwrap(specified)).symbol());
        // console.log("SPECIFIED balance:", specified.balanceOf(user));

        // poolManager.take(specified, user, price);
        // return (this.beforeSwap.selector, delta, uint24(0));
        


        
        return (this.beforeSwap.selector, delta, uint24(0));

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

        // bool bondTokenZero = bondTokenIsZero[key.toId()];

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
        // if (swapParams.zeroForOne == bondTokenZero) {}

       
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
