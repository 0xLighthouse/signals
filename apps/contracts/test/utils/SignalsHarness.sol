// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol"; 

import {Signals} from "../../src/Signals.sol";
import {SignalsFactory} from "../../src/SignalsFactory.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {MockStable} from "../../test/mocks/MockStable.m.sol";
import {TokenRegistry} from "../../src/TokenRegistry.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {BondHook} from "../../src/BondHook.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {SortTokens} from "@uniswap/v4-core/test/utils/SortTokens.sol";
import {Constants} from "@uniswap/v4-core/test/utils/Constants.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";

import {ExampleSimplePricing} from "../../src/pricing/ExampleSimplePricing.sol";
import {IBondPricing} from "../../src/interfaces/IBondPricing.sol";
import {PipsLib} from "../../src/PipsLib.sol";

contract SignalsHarness is Test, Deployers {
    address _deployer = address(this);
    address _alice = address(0x1111);
    address _bob = address(0x2222);
    address _charlie = address(0x3333);
    address _liquidityProvider = address(0x4444);
    // --- Tokens ---
    MockERC20 internal _token = new MockERC20("SomeGovToken", "GOV", 18);
    MockERC20 internal _usdc = new MockERC20("USDC", "USDC", 6);
    MockERC20 internal _dai = new MockERC20("DAI", "DAI", 18);

    // tokens expressed as Currency
    Currency tokenCurrency;
    Currency usdcCurrency;
    Currency daiCurrency;

    BondHook public bondhook;

    // --- Pool Config ---
    uint24 public constant POOL_FEE = 3000; // 0.3% fee

    PoolKey _keyA; // USDC/GOV
    bool _keyAIsGovZero;    
    
    PoolKey _keyB; // DAI/GOV
    bool _keyBIsGovZero;

    Signals.SignalsConfig public defaultConfig = Signals.SignalsConfig({
        owner: _deployer,
        underlyingToken: address(_token),
        proposalThreshold: 50_000 * 1e18, // 50k
        acceptanceThreshold: 100_000 * 1e18, // 100k
        maxLockIntervals: 365 days, // 1 year
        proposalCap: 100, // 100 proposals
        lockInterval: 1 days, // 1 day
        decayCurveType: 0, // Linear
        decayCurveParameters: new uint256[](1)
    });

    function deploySignals(bool _dealTokens) public returns (Signals) {
        Signals signals = new Signals();
        signals.initialize(defaultConfig);
        if (_dealTokens) {
            _dealDefaultTokens();
        }
        return signals;
    }

    function deploySignalsWithFactory(bool _dealTokens) public returns (SignalsFactory factory, Signals signals) {
        factory = new SignalsFactory();
        signals = Signals(factory.create(defaultConfig));
        if (_dealTokens) {
            _dealDefaultTokens();
        }
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

    function _dealDefaultTokens() public {
        // --- Issue governance tokens to participants ---
        // Alice has 50k
        deal(address(_token), _alice, defaultConfig.proposalThreshold);
        // Bob has 100k
        deal(address(_token), _bob, defaultConfig.acceptanceThreshold);
        // Charlie has 25k
        deal(address(_token), _charlie, defaultConfig.proposalThreshold / 2);
        // Liquidity provider has 1M
        deal(address(_token), _liquidityProvider, 100_000_000 * 1e18);
    }

    function _uniswapApprovals(MockERC20 token) internal returns (Currency currency) {
        address[9] memory toApprove = [
            address(swapRouter),
            address(swapRouterNoChecks),
            address(modifyLiquidityRouter),
            address(modifyLiquidityNoChecks),
            address(donateRouter),
            address(takeRouter),
            address(claimsRouter),
            address(nestedActionRouter.executor()),
            address(actionsRouter)
        ];

        for (uint256 i = 0; i < toApprove.length; i++) {
            token.approve(toApprove[i], Constants.MAX_UINT256);
        }
        return Currency.wrap(address(token));
    }

    
    function deployHookWithLiquidity(Signals _signals) public {
        // Set up uniswap approvals
        usdcCurrency = _uniswapApprovals(_usdc);
        tokenCurrency = _uniswapApprovals(_token);
        daiCurrency = _uniswapApprovals(_dai);

        deal(address(_token), _deployer, 1_000_000 * 1e18);
        deal(address(_usdc), _deployer, 1_000_000 * 1e6);
        deal(address(_dai), _deployer, 1_000_000 * 1e18);

        // Deploy pricing contract
        IBondPricing pricing = new ExampleSimplePricing(PipsLib.percentToPips(10), PipsLib.percentToPips(10));

        // Deploy hook with correct flags
        uint160 flags = uint160(
            Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG
        );

        deployCodeTo("BondHook.sol", abi.encode(manager, address(_signals), address(pricing)), address(flags));
        bondhook = BondHook(address(flags));

        // Deploy the pools
        _keyA = _deployPoolWithHook(usdcCurrency, tokenCurrency); // USDC/GOV
        _keyAIsGovZero = _keyA.currency0 == tokenCurrency;

        _keyB = _deployPoolWithHook(daiCurrency, tokenCurrency); // DAI/GOV
        _keyBIsGovZero = _keyB.currency0 == tokenCurrency;
    }

    // Gotcha: currencies are sorted by address
    function _deployPoolWithHook(Currency currencyA, Currency currencyB) public returns (PoolKey memory _key) {
        Currency _currency0;
        Currency _currency1;
        (_currency0, _currency1) =
            SortTokens.sort(MockERC20(Currency.unwrap(currencyA)), MockERC20(Currency.unwrap(currencyB)));

        (_key,) = initPool(_currency0, _currency1, bondhook, POOL_FEE, SQRT_PRICE_1_1);

        uint256 amount0 = 100_000 * (10 ** MockERC20(Currency.unwrap(_currency0)).decimals());
        uint256 amount1 = 100_000 * (10 ** MockERC20(Currency.unwrap(_currency1)).decimals());

        seedMoreLiquidity(_key, amount0, amount1);

        return _key;
    }

    function lockTokensAndIssueBond(Signals _signals, address _user, uint256 _amount, uint256 _duration)
        public
        returns (uint256 tokenId)
    {
        vm.startPrank(_user);
        _token.approve(address(_signals), _amount);
        (tokenId) = _signals.proposeInitiativeWithLock("Some Initiative", "Some Description", _amount, _duration);
        vm.stopPrank();
    }

    // function deployAllowedTokens() public returns (TokenRegistry registry, MockERC20 _mToken, MockStable _mUSDC) {
    //     // Create some tokens
        
    //     address[] memory _tokens = new address[](2);
    //     _tokens[0] = address(_mToken);
    //     _tokens[1] = address(_mUSDC);

    //     // Configure the registry
    //     registry = _configureRegistry(_tokens);

    //     return (registry, _mToken, _mUSDC);
    // }

    // function _configureRegistry(address[] memory _tokens) public returns (TokenRegistry registry) {
    //     registry = new TokenRegistry();
    //     for (uint256 i = 0; i < _tokens.length; i++) {
    //         registry.allow(_tokens[i]);
    //     }
    // }

    function printPoolInfo() public view {
        console.log("Address and decimals: ");
        console.log("GOV: ", address(_token), _token.decimals());
        console.log("DAI: ", address(_dai), _dai.decimals());
        console.log("USDC: ", address(_usdc), _usdc.decimals());
        console.log("Pool currencies (0 and 1): ");
        MockERC20 a0 = MockERC20(Currency.unwrap(_keyA.currency0));
        MockERC20 a1 = MockERC20(Currency.unwrap(_keyA.currency1));
        console.log("Pool A: ",  a0.symbol()    , a1.symbol());
        MockERC20 b0 = MockERC20(Currency.unwrap(_keyB.currency0));
        MockERC20 b1 = MockERC20(Currency.unwrap(_keyB.currency1));
        console.log("Pool B: ",  b0.symbol(), b1.symbol());
    }
}
