// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {Signals} from "../../src/Signals.sol";
import {SignalsFactory} from "../../src/SignalsFactory.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {MockERC20Votes} from "../mocks/MockERC20Votes.m.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {Constants} from "@uniswap/v4-core/test/utils/Constants.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {ISignals} from "../../src/interfaces/ISignals.sol";
import {ISignalsFactory} from "../../src/interfaces/ISignalsFactory.sol";

contract SignalsHarness is Test, Deployers {
    address _deployer = address(this);
    address _alice = address(0x1111);
    address _bob = address(0x2222);
    address _charlie = address(0x3333);
    address _liquidityProvider = address(0x4444);

    // --- Tokens ---
    // Standard ERC20 token (no checkpoints)
    MockERC20 internal _tokenERC20 = new MockERC20("StandardToken", "STD", 18);

    // ERC20Votes token (with checkpoints for governance)
    MockERC20Votes internal _tokenERC20Votes = new MockERC20Votes();

    // Incentive tokens
    MockERC20 internal _usdc = new MockERC20("USDC", "USDC", 6);
    MockERC20 internal _dai = new MockERC20("DAI", "DAI", 18);


    // --- Factory ---
    SignalsFactory internal factory = new SignalsFactory();

    // tokens expressed as Currency
    Currency tokenCurrency;
    Currency usdcCurrency;
    Currency daiCurrency;

    // --- Pool Config ---
    uint24 public constant POOL_FEE = 3000; // 0.3% fee

    PoolKey _keyA; // USDC/GOV
    bool _keyAIsGovZero;

    PoolKey _keyB; // DAI/GOV
    bool _keyBIsGovZero;

    ISignals.BoardConfig public defaultConfig = ISignals.BoardConfig({
        version: factory.version(),
        owner: _deployer,
        underlyingToken: address(_tokenERC20),
        acceptanceThreshold: 100_000 * 1e18, // 100k
        maxLockIntervals: 365 days, // 1 year
        proposalCap: 100, // 100 proposals
        lockInterval: 1 days, // 1 day
        decayCurveType: 0, // Linear
        decayCurveParameters: new uint256[](1),
        proposerRequirements: ISignals.ProposerRequirements({
            eligibilityType: ISignals.EligibilityType.None,
            minBalance: 0,
            minHoldingDuration: 0,
            threshold: 50_000 * 1e18 // 50k tokens to propose
        }),
        participantRequirements: ISignals.ParticipantRequirements({
            eligibilityType: ISignals.EligibilityType.None,
            minBalance: 0,
            minHoldingDuration: 0
        }),
        releaseLockDuration: 0
    });

    function deploySignals(bool _dealTokens) public returns (Signals) {
        Signals signals = new Signals();
        signals.initialize(defaultConfig);
        if (_dealTokens) {
            _dealDefaultTokens();
        }
        return signals;
    }

    function deploySignalsWithFactory(bool _dealTokens) public returns (SignalsFactory _factory, Signals signals) {
        _factory = new SignalsFactory();
        address _instance = _factory.create(_toFactoryDeployment(defaultConfig));
        signals = Signals(_instance);
        if (_dealTokens) {
            _dealDefaultTokens();
        }
    }

    function dealMockTokens() public {
        _dealToken(_tokenERC20);
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
        // --- Issue standard ERC20 tokens to participants ---
        // Alice has 50k
        deal(address(_tokenERC20), _alice, defaultConfig.proposerRequirements.threshold);
        // Bob has 100k
        deal(address(_tokenERC20), _bob, defaultConfig.acceptanceThreshold);
        // Charlie has 25k
        deal(address(_tokenERC20), _charlie, defaultConfig.proposerRequirements.threshold / 2);
        // Liquidity provider has 1M
        deal(address(_tokenERC20), _liquidityProvider, 100_000_000 * 1e18);
    }

    /**
     * @notice Deal ERC20Votes tokens and delegate voting power
     * @dev Mints tokens and delegates to self to activate checkpoints
     */
    function _dealAndDelegateERC20Votes() public {
        // Mint and delegate to activate checkpoints
        _tokenERC20Votes.mint(_alice, defaultConfig.proposerRequirements.threshold);
        vm.prank(_alice);
        _tokenERC20Votes.delegate(_alice);

        _tokenERC20Votes.mint(_bob, defaultConfig.acceptanceThreshold);
        vm.prank(_bob);
        _tokenERC20Votes.delegate(_bob);

        _tokenERC20Votes.mint(_charlie, defaultConfig.proposerRequirements.threshold / 2);
        vm.prank(_charlie);
        _tokenERC20Votes.delegate(_charlie);

        _tokenERC20Votes.mint(_liquidityProvider, 100_000_000 * 1e18);
        vm.prank(_liquidityProvider);
        _tokenERC20Votes.delegate(_liquidityProvider);
    }

    /**
     * @notice Create a Signals config using the ERC20Votes token
     * @return Configuration using _tokenERC20Votes as underlying
     */
    function getERC20VotesConfig() public view returns (ISignals.BoardConfig memory) {
        return ISignals.BoardConfig({
            version: factory.version(),
            owner: _deployer,
            underlyingToken: address(_tokenERC20Votes),
            acceptanceThreshold: 100_000 * 1e18,
            maxLockIntervals: 365 days,
            proposalCap: 100,
            lockInterval: 1 days,
            decayCurveType: 0,
            decayCurveParameters: new uint256[](1),
            proposerRequirements: ISignals.ProposerRequirements({
                eligibilityType: ISignals.EligibilityType.None,
                minBalance: 0,
                minHoldingDuration: 0,
                threshold: 50_000 * 1e18
            }),
            participantRequirements: ISignals.ParticipantRequirements({
                eligibilityType: ISignals.EligibilityType.None,
                minBalance: 0,
                minHoldingDuration: 0
            }),
            releaseLockDuration: 0
        });
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

    function lockTokensAndIssueBond(Signals _signals, address _user, uint256 _amount, uint256 _duration)
        public
        returns (uint256 tokenId)
    {
        vm.startPrank(_user);
        _tokenERC20.approve(address(_signals), _amount);
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
        console.log("GOV: ", address(_tokenERC20), _tokenERC20.decimals());
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

    function _toFactoryDeployment(ISignals.BoardConfig storage config)
        internal
        view
        returns (ISignalsFactory.FactoryDeployment memory)
    {
        return ISignalsFactory.FactoryDeployment({
            owner: config.owner,
            underlyingToken: config.underlyingToken,
            acceptanceThreshold: config.acceptanceThreshold,
            maxLockIntervals: config.maxLockIntervals,
            proposalCap: config.proposalCap,
            lockInterval: config.lockInterval,
            decayCurveType: config.decayCurveType,
            decayCurveParameters: config.decayCurveParameters,
            proposerRequirements: config.proposerRequirements,
            participantRequirements: config.participantRequirements,
            releaseLockDuration: config.releaseLockDuration
        });
    }

    /*//////////////////////////////////////////////////////////////
                    TEST HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Helper to propose initiative with lock and accept it
    /// @return initiativeId The ID of the created initiative
    /// @return tokenId The ID of the lock NFT
    function proposeAndAccept(ISignals signals, address proposer, uint256 amount, uint256 lockDuration)
        internal
        returns (uint256 initiativeId, uint256 tokenId)
    {
        vm.startPrank(proposer);
        _tokenERC20.approve(address(signals), amount);
        tokenId = signals.proposeInitiativeWithLock("Test Initiative", "Description", amount, lockDuration);
        vm.stopPrank();

        initiativeId = 1; // First initiative
        vm.prank(_deployer);
        signals.acceptInitiative(initiativeId);
    }

    /// @notice Helper to propose, accept, and time travel
    /// @return initiativeId The ID of the created initiative
    /// @return tokenId The ID of the lock NFT
    function proposeAcceptAndWarp(
        ISignals signals,
        address proposer,
        uint256 amount,
        uint256 lockDuration,
        uint256 warpTime
    ) internal returns (uint256 initiativeId, uint256 tokenId) {
        (initiativeId, tokenId) = proposeAndAccept(signals, proposer, amount, lockDuration);
        vm.warp(block.timestamp + warpTime);
    }

    /// @notice Helper to propose initiative and expire it
    /// @return initiativeId The ID of the created initiative
    /// @return tokenId The ID of the lock NFT
    function proposeAndExpire(ISignals signals, address proposer, uint256 amount, uint256 lockDuration)
        internal
        returns (uint256 initiativeId, uint256 tokenId)
    {
        vm.startPrank(proposer);
        _tokenERC20.approve(address(signals), amount);
        tokenId = signals.proposeInitiativeWithLock("Test Initiative", "Description", amount, lockDuration);
        vm.stopPrank();

        initiativeId = 1;
        vm.warp(block.timestamp + 61 days); // Past activity timeout
        vm.prank(_deployer);
        signals.expireInitiative(initiativeId);
    }
}
