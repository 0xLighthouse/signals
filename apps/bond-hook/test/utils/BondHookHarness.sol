// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

import {Currency} from "v4-core/types/Currency.sol";
import {SortTokens} from "@uniswap/v4-core/test/utils/SortTokens.sol";

import {BondHook, DesiredCurrency, LiquidityData} from "../../src/BondHook.sol";
import {IBondIssuer} from "../../src/interfaces/IBondIssuer.sol";
import {IBondPricing} from "../../src/interfaces/IBondPricing.sol";
import {ExampleLinearPricing} from "../../src/pricing/ExampleLinearPricing.sol";
import {PipsLib} from "../../src/PipsLib.sol";

contract BondHookHarness is Test {
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

    MockIssuer public bondIssuer;

    // --- Pool Config ---
    uint24 public constant POOL_FEE = 3000; // 0.3% fee

    PoolKey poolA; // USDC/GOV
    bool poolAIsGovZero;

    PoolKey poolB; // DAI/GOV
    bool poolBIsGovZero;

    MockIssuer public mockIssuer;

    function deployMockIssuer() public returns (MockIssuer) {
        bondIssuer = new MockIssuer(address(_token));
        return bondIssuer;
    }

    function dealMockTokens() public {
        _dealToken(_token);
        _dealToken(_usdc);
        _dealToken(_dai);
    }

    function _dealToken(MockERC20 token) public {
        deal(address(token), _alice, 200_000 * 10 ** token.decimals());
        deal(address(token), _bob, 200_000 * 10 ** token.decimals());
        deal(address(token), _charlie, 40_000 * 10 ** token.decimals());
        deal(address(token), _liquidityProvider, 100_000_000 * 10 ** token.decimals());
    }

    // function _approveAll(address user, MockERC20 token) internal returns (Currency currency) {
    //     address[9] memory toApprove = [
    //         address(swapRouter),
    //         address(swapRouterNoChecks),
    //         address(modifyLiquidityRouter),
    //         address(modifyLiquidityNoChecks),
    //         address(donateRouter),
    //         address(takeRouter),
    //         address(claimsRouter),
    //         address(nestedActionRouter.executor()),
    //         address(actionsRouter)
    //     ];

    //     vm.startPrank(user);
    //     for (uint256 i = 0; i < toApprove.length; i++) {
    //         token.approve(toApprove[i], Constants.MAX_UINT256);
    //     }
    //     vm.stopPrank();
    //     return Currency.wrap(address(token));
    // }

    function deployHookAndPools(IBondIssuer _issuer) public {
        // Deploy pricing contract
        IBondPricing _pricing = new ExampleLinearPricing(PipsLib.percentToPips(10), PipsLib.percentToPips(10));

        // Deploy hook with correct flags
        uint160 flags = uint160(
            Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG
                | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG
        );

        deployCodeTo("BondHook.sol", abi.encode(manager, address(_issuer), address(_pricing)), address(flags));
        bondhook = BondHook(address(flags));

        // Deploy the pools
        poolA = _deployPool(_dai, _token); // DAI/GOV
        poolAIsGovZero = poolA.currency0 == Currency.wrap(_token);

        poolB = _deployPool(_usdc, _token); // USDC/GOV
        poolBIsGovZero = poolB.currency0 == Currency.wrap(_token);
    }

    function addLiquidity(PoolKey memory _key) public {
        Currency currency0 = _key.currency0;
        Currency currency1 = _key.currency1;

        vm.startPrank(_liquidityProvider);
        currency0.approve(address(bondhook), type(uint256).max);
        currency1.approve(address(bondhook), type(uint256).max);

        bondhook.modifyLiquidity(LiquidityData({
            poolKey: _key,
            liquidityDelta: 1_000_000 ether,
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
        _token.approve(address(mockIssuer), _amount);
        tokenId = mockIssuer.createBond(1, _amount, _duration);
        vm.stopPrank();
    }

    function printPoolInfo() public view {
        console.log("Address and decimals: ");
        console.log("GOV: ", address(_token), _token.decimals());
        console.log("DAI: ", address(_dai), _dai.decimals());
        console.log("USDC: ", address(_usdc), _usdc.decimals());
        console.log("Pool currencies (0 and 1): ");
        MockERC20 a0 = MockERC20(Currency.unwrap(_keyA.currency0));
        MockERC20 a1 = MockERC20(Currency.unwrap(_keyA.currency1));
        console.log("Pool A: ", a0.symbol(), a1.symbol());
        MockERC20 b0 = MockERC20(Currency.unwrap(_keyB.currency0));
        MockERC20 b1 = MockERC20(Currency.unwrap(_keyB.currency1));
        console.log("Pool B: ", b0.symbol(), b1.symbol());
    }
}