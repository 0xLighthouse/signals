// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {MockIssuer} from "./MockIssuer.m.sol";

import {Currency} from "v4-core/types/Currency.sol";
import {SortTokens} from "@uniswap/v4-core/test/utils/SortTokens.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {BondHook, DesiredCurrency, LiquidityData, BondHookOptions, SwapData} from "../../src/BondHook.sol";
import {IBondIssuer} from "../../src/interfaces/IBondIssuer.sol";
import {IBondPricing} from "../../src/interfaces/IBondPricing.sol";
import {ExampleLinearPricing} from "../../src/pricing/ExampleLinearPricing.sol";
import {PipsLib} from "./PipsLib.sol";

contract BondHookHarness is Test, Deployers {
    address _deployer = address(this);
    address _alice = address(0x1111);
    address _bob = address(0x2222);
    address _charlie = address(0x3333);
    address _liquidityProvider = address(0x4444);

    // --- Tokens ---
    MockERC20 internal _token = new MockERC20("SomeGovToken", "GOV", 18);
    MockERC20 internal _dai = new MockERC20("DAI", "DAI", 18);
    MockERC20 internal _usdc = new MockERC20("USDC", "USDC", 6);

    BondHook public bondhook;

    MockIssuer public bondIssuer = new MockIssuer(address(_token));

    IBondPricing public pricingContract = new ExampleLinearPricing(PipsLib.percentToPips(10), PipsLib.percentToPips(10));

    // --- Pool Config ---
    uint24 public constant POOL_FEE = 3000; // 0.3% fee

    PoolKey poolA; // USDC/GOV
    bool poolAIsGovZero;

    PoolKey poolB; // DAI/GOV
    bool poolBIsGovZero;

    function dealMockTokens() public {
        _dealToken(_token);
        _dealToken(_usdc);
        _dealToken(_dai);

        vm.startPrank(_alice);
        _token.approve(address(bondIssuer), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(_liquidityProvider);
        _dai.approve(address(bondhook), type(uint256).max);
        _token.approve(address(bondhook), type(uint256).max);
        vm.stopPrank();
    }

    function _dealToken(MockERC20 token) public {
        deal(address(token), _alice, 200_000 * 10 ** token.decimals());
        deal(address(token), _bob, 200_000 * 10 ** token.decimals());
        deal(address(token), _charlie, 40_000 * 10 ** token.decimals());
        deal(address(token), _liquidityProvider, 100_000_000 * 10 ** token.decimals());
    }

    function deployHookAndPools() public {
        deployHookWithFeesAndPools(0, 0, 0);
    }

    function deployHookWithFeesAndPools(uint256 ownerFeeAsPips, uint256 profitShareRatioAsPips, uint256 swapFeeDiscountAsPips) public {
        // Deploy hook with correct flags
        address _hookAddress = address(uint160(
            Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG
                | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG
        ));

        bytes memory args = abi.encode(BondHookOptions({
            poolManager: IPoolManager(manager),
            bondIssuer: address(bondIssuer),
            bondPricing: address(pricingContract),
            ownerFeeAsPips: ownerFeeAsPips,
            profitShareRatioAsPips: profitShareRatioAsPips,
            swapFeeDiscountAsPips: swapFeeDiscountAsPips
        }));

        deployCodeTo("BondHook.sol", args, _hookAddress);
        bondhook = BondHook(_hookAddress);

        // Deploy the pools
        poolA = _deployPool(_dai, _token); // DAI/GOV
        poolAIsGovZero = Currency.unwrap(poolA.currency0) == address(_token);

        poolB = _deployPool(_usdc, _token); // USDC/GOV
        poolBIsGovZero = Currency.unwrap(poolB.currency0) == address(_token);
    }

    function modifyLiquidityFromProvider(PoolKey memory _key, int128 _liquidityDelta) public {
        MockERC20 currency0 = MockERC20(Currency.unwrap(_key.currency0));
        MockERC20 currency1 = MockERC20(Currency.unwrap(_key.currency1));

        vm.startPrank(_liquidityProvider);
        currency0.approve(address(bondhook), type(uint256).max);
        currency1.approve(address(bondhook), type(uint256).max);

        bondhook.modifyLiquidity(LiquidityData({
            poolKey: _key,
            liquidityDelta: _liquidityDelta,
            desiredCurrency: DesiredCurrency.Mixed,
            swapPriceLimit: 0
        }));
        vm.stopPrank();
    }

    function _deployPool(MockERC20 currencyA, MockERC20 currencyB) public returns (PoolKey memory _key) {
        (Currency _currency0, Currency _currency1) = SortTokens.sort(currencyA, currencyB);
        (_key,) = initPool(_currency0, _currency1, bondhook, POOL_FEE, SQRT_PRICE_1_1);
        return _key;
    }

    function createBond(address _user, uint256 _amount, uint256 _duration)
        public
        returns (uint256 tokenId)
    {
        vm.startPrank(_user);
        _token.approve(address(bondIssuer), _amount);
        tokenId = bondIssuer.createBond(1, _amount, _duration);
        vm.stopPrank();
    }

    // Create bond using the specified abmoutn of lockup. Wait time is a percent (e.g. 50 = 50% of duration)
    function aliceCreateBondAndWaits(uint256 _amount, uint256 _waitTimeAsPercentOfDuration) public returns (uint256 _tokenId) {
        vm.startPrank(_alice);
        _tokenId = bondIssuer.createBond(1, _amount, 365 days);
        vm.stopPrank();

        // Jump ahead to when bond is worth 50%
        vm.warp(block.timestamp + 365 days * _waitTimeAsPercentOfDuration / 100);
    }

    // Alice sells the bond for mixed currency
    function aliceSellBond(uint256 _tokenId, uint256 _bondPriceLimit) public {

        vm.startPrank(_alice);
        bondIssuer.approve(address(bondhook), _tokenId);
        bondhook.swapBond(
            SwapData({
                poolKey: poolA,
                tokenId: _tokenId,
                bondPriceLimit: _bondPriceLimit,
                swapPriceLimit: poolAIsGovZero ? TickMath.MAX_SQRT_PRICE - 1 : TickMath.MIN_SQRT_PRICE + 1,
                desiredCurrency: DesiredCurrency.Mixed
            })
        );
        vm.stopPrank();
    }

    // Bob buys the bond for mixed currency
    function bobBuyBond(uint256 _tokenId, uint256 _bondPriceLimit) public {
        if (_bondPriceLimit == 0) {
            _bondPriceLimit = type(uint256).max;
        }

        vm.startPrank(_bob);
        _token.approve(address(bondhook), type(uint256).max);
        _dai.approve(address(bondhook), type(uint256).max);

        bondhook.swapBond(
            SwapData({
                poolKey: poolA,
                tokenId: _tokenId,
                bondPriceLimit: _bondPriceLimit,
                swapPriceLimit: poolAIsGovZero ? TickMath.MAX_SQRT_PRICE - 1 : TickMath.MIN_SQRT_PRICE + 1,
                desiredCurrency: DesiredCurrency.Mixed
            })
        );
        vm.stopPrank();
    }

    function printPoolInfo() public view {
        console.log("Address and decimals: ");
        console.log("GOV: ", address(_token), _token.decimals());
        console.log("DAI: ", address(_dai), _dai.decimals());
        console.log("USDC: ", address(_usdc), _usdc.decimals());
        console.log("Pool currencies (0 and 1): ");
        MockERC20 a0 = MockERC20(Currency.unwrap(poolA.currency0));
        MockERC20 a1 = MockERC20(Currency.unwrap(poolA.currency1));
        console.log("Pool A: ", a0.symbol(), a1.symbol());
        MockERC20 b0 = MockERC20(Currency.unwrap(poolB.currency0));
        MockERC20 b1 = MockERC20(Currency.unwrap(poolB.currency1));
        console.log("Pool B: ", b0.symbol(), b1.symbol());
    }
}