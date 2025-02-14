// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/console.sol";

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";

import {CurrencyLibrary, Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {BalanceDeltaLibrary, BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";

import {Signals} from "./Signals.sol";
import {ISignals} from "./interfaces/ISignals.sol";
import {IBondPricing} from "./interfaces/IBondPricing.sol";

import "./PipsLib.sol";

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
    mapping(PoolId => bool) internal bondTokenIsZero;

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
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function beforeInitialize(address, PoolKey calldata key, uint160) external override returns (bytes4) {
        if (key.currency0 == bondToken) {
            bondTokenIsZero[key.toId()] = true;
        } else if (key.currency1 == bondToken) {
            bondTokenIsZero[key.toId()] = false;
        } else {
            revert("BondHook: Pool does not contain bond token");
        }
        return this.beforeInitialize.selector;
    }

    /**
     * @notice The nominal value of the bond is the amount of tokens that will be
     * received when the bond is redeemed.
     * @param tokenId The ID of the bond token.
     * @return value The nominal value of the bond.
     */
    function nominalValue(uint256 tokenId) external view returns (uint256) {
        ISignals.LockInfo memory lock = signals.getTokenMetadata(tokenId);
        return lock.tokenAmount;
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

    function beforeSwap(address, PoolKey calldata, IPoolManager.SwapParams calldata, bytes calldata hookData)
        external
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        if (hookData.length == 0) {
            return (this.beforeSwap.selector, BeforeSwapDelta.wrap(0), uint24(0));
        }

        (bool isBuy, uint256 tokenId, uint256 desiredPrice,) = _parseHookData(hookData);
        if (isBuy) {
            // The user is selling to us
            uint256 price = getPoolBuyPrice(tokenId);
            require(desiredPrice <= price, "BondHook: Desired price exceeds buy price");

            // TODO: set up balanceDelta so the user can receive the currency they want
        } else {
            // We are selling the bond to the user
            uint256 price = getPoolSellPrice(tokenId);
            require(desiredPrice >= price, "BondHook: Desired price below sell price");

            // TODO: set up balanceDelta so the user can receive the currency they want
        }

        return (this.beforeSwap.selector, BeforeSwapDelta.wrap(0), uint24(0));
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

    function afterSwap(
        address,
        PoolKey calldata,
        IPoolManager.SwapParams calldata,
        BalanceDelta,
        bytes calldata hookData
    ) external override returns (bytes4, int128) {
        if (hookData.length == 0) {
            return (this.afterSwap.selector, int128(0));
        }

        (bool isBuy, uint256 tokenId, uint256 desiredPrice, bytes memory signature) = _parseHookData(hookData);
        address user = _verifySignature(signature);
        if (isBuy) {
            // The user is selling to us
            signals.transferFrom(user, address(this), tokenId);
            // TODO: set up balanceDelta so the user doesn't pay anything to the pool
        } else {
            // We are selling to the user
            signals.transferFrom(address(this), user, tokenId);
            // TODO: set up balanceDelta so the user doesn't receive anything from the pool
        }

        return (this.afterSwap.selector, int128(0));
    }

    function _verifySignature(bytes memory signature) internal pure returns (address) {
        // Later: signature should include the data we need to find the user's address,
        // for now we just include the user's address as the signature
        return abi.decode(signature, (address));
    }

    /**
     * @notice Internal function to process a bond swap.
     * @dev Decodes the tokenId from `data`, verifies ownership,
     *      retrieves bond metadata, fetches the underlying price,
     *      applies the discount, and checks the swap price limit.
     */
    // function _handleBondSwap(
    //   address user,
    //   PoolKey calldata key,
    //   IPoolManager.SwapParams calldata params,
    //   bytes calldata data
    // ) internal {
    //   // Decode the bond tokenId from the calldata.
    //   uint256 tokenId = abi.decode(data, (uint256));
    //   require(signals.ownerOf(tokenId) == user, 'BondHook: Not bond owner');

    //   // Retrieve bond metadata (e.g., lock duration, token amount, etc.)
    //   ISignals.LockInfo memory metadata = signals.getTokenMetadata(tokenId);
    //   console.log('lockDuration', metadata.lockDuration);

    //   // Get the current price of the underlying asset.
    //   // CurrencyLibrary.unwrap converts the currency type into its address form.
    //   // uint256 currentPrice = _getUnderlyingPrice(CurrencyLibrary.unwrap(key.currency0));
    //   uint256 currentPrice = 1e18;

    //   // For this example, apply a fixed discount of 20% (i.e. 2000 basis points out of 10000)
    //   uint256 discountRate = 2000; // 20%
    //   uint256 discountedPrice = (currentPrice * (10000 - discountRate)) / 10000;

    //   // Enforce that the swap's price limit aligns with the discounted price.
    //   // Depending on swap direction (zeroForOne), the sqrt price limit must be
    //   // either at or below (for zeroForOne) or at or above (for oneForZero) the discounted price.
    //   if (params.zeroForOne) {
    //     require(
    //       params.sqrtPriceLimitX96 <= _priceToSqrtX96(discountedPrice),
    //       'BondHook: Price exceeds bond discount'
    //     );
    //   } else {
    //     require(
    //       params.sqrtPriceLimitX96 >= _priceToSqrtX96(discountedPrice),
    //       'BondHook: Price exceeds bond discount'
    //     );
    //   }

    //   // Emit an event indicating that this pool (identified by poolId) has processed a bond swap.
    //   bytes32 poolId = keccak256(abi.encode(key));
    //   emit Buyer(poolId, user);
    // }

    // // Lazy implementation
    function _priceToSqrtX96(uint256 price) internal pure returns (uint160) {
        return uint160(_sqrt((price << 192) / 1e18));
    }

    // // Lazy implementation
    function _sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
