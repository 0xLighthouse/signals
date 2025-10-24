// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {Signals} from "../../src/Signals.sol";
import {SignalsFactory} from "../../src/SignalsFactory.sol";
import {IncentivesPool} from "../../src/IncentivesPool.sol";
import {MockERC20} from "solady/test/utils/mocks/MockERC20.sol";
import {MockERC20Votes} from "../mocks/MockERC20Votes.m.sol";
import {ISignals} from "../../src/interfaces/ISignals.sol";
import {IIncentivizer} from "../../src/interfaces/IIncentivizer.sol";
import {BoardConfigs} from "./BoardConfigs.sol";

contract SignalsHarness is Test {
    address _deployer = address(this);
    address _alice = address(0x1111);
    address _bob = address(0x2222);
    address _charlie = address(0x3333);
    address _liquidityProvider = address(0x4444);
    address _poolOwner = address(0x9999);

    uint256 public constant STANDARD_BALANCE = 200_000;
    uint256 public constant LOW_BALANCE = 40_000;
    uint256 public constant LIQUIDITY_PROVIDER_BALANCE = 100_000_000;

    // --- Tokens ---
    // Standard ERC20 token (no checkpoints)
    MockERC20 internal _tokenERC20 = new MockERC20("StandardToken", "STD", 18);

    // ERC20Votes token (with checkpoints for governance)
    MockERC20Votes internal _tokenERC20Votes = new MockERC20Votes("GovernanceToken", "GOV");

    // Incentive tokens
    MockERC20 internal _usdc = new MockERC20("USDC", "USDC", 6);
    MockERC20 internal _dai = new MockERC20("DAI", "DAI", 18);

    // --- Factory ---
    SignalsFactory internal factory = new SignalsFactory();

    ISignals.BoardConfig public defaultConfig =
        BoardConfigs.defaultConfig(_deployer, address(_tokenERC20), block.timestamp);
    ISignals.BoardConfig public erc20VotesConfig =
        BoardConfigs.defaultConfig(_deployer, address(_tokenERC20Votes), block.timestamp);

    function deploySignals(ISignals.BoardConfig memory config) public returns (Signals) {
        address boardAddress = factory.create(config);
        Signals signals = Signals(boardAddress);
        return signals;
    }

    function dealMockTokens() public {
        _dealToken(_tokenERC20);
        _dealToken(_usdc);
        _dealToken(_dai);
    }

    function _dealToken(MockERC20 token) public {
        deal(address(token), _alice, STANDARD_BALANCE * 10 ** token.decimals());
        deal(address(token), _bob, STANDARD_BALANCE * 10 ** token.decimals());
        deal(address(token), _charlie, LOW_BALANCE * 10 ** token.decimals());
        deal(
            address(token), _liquidityProvider, LIQUIDITY_PROVIDER_BALANCE * 10 ** token.decimals()
        );
    }

    /**
     * @notice Deal ERC20Votes tokens and delegate voting power
     * @dev Mints tokens and delegates to self to activate checkpoints
     */
    function _dealAndDelegateERC20Votes() public {
        uint256 decimals = _tokenERC20Votes.decimals();

        // Mint and delegate to activate checkpoints
        _tokenERC20Votes.mint(_alice, STANDARD_BALANCE * 10 ** decimals);
        vm.prank(_alice);
        _tokenERC20Votes.delegate(_alice);

        _tokenERC20Votes.mint(_bob, STANDARD_BALANCE * 10 ** decimals);
        vm.prank(_bob);
        _tokenERC20Votes.delegate(_bob);

        _tokenERC20Votes.mint(_charlie, LOW_BALANCE * 10 ** decimals);
        vm.prank(_charlie);
        _tokenERC20Votes.delegate(_charlie);

        _tokenERC20Votes.mint(_liquidityProvider, LIQUIDITY_PROVIDER_BALANCE * 10 ** decimals);
        vm.prank(_liquidityProvider);
        _tokenERC20Votes.delegate(_liquidityProvider);
    }

    /*//////////////////////////////////////////////////////////////
                    TEST HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _emptyAttachmentsArray()
        internal
        pure
        returns (ISignals.Attachment[] memory attachments)
    {
        return new ISignals.Attachment[](0);
    }

    function _singleAttachment(string memory uri, string memory mimeType, string memory description)
        internal
        pure
        returns (ISignals.Attachment[] memory attachments)
    {
        attachments = new ISignals.Attachment[](1);
        attachments[0] =
            ISignals.Attachment({uri: uri, mimeType: mimeType, description: description});
    }

    /// @notice Helper to propose initiative with lock and accept it
    /// @return initiativeId The ID of the created initiative
    /// @return tokenId The ID of the lock NFT
    function proposeAndAccept(
        ISignals signals,
        address proposer,
        uint256 amount,
        uint256 lockDuration
    ) internal returns (uint256 initiativeId, uint256 tokenId) {
        vm.startPrank(proposer);
        _tokenERC20.approve(address(signals), amount);
        (initiativeId, tokenId) = signals.proposeInitiativeWithLock(
            "Test Initiative", "Description", amount, lockDuration, _emptyAttachmentsArray()
        );
        vm.stopPrank();

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
    function proposeAndExpire(
        ISignals signals,
        address proposer,
        uint256 amount,
        uint256 lockDuration
    ) internal returns (uint256 initiativeId, uint256 tokenId) {
        vm.startPrank(proposer);
        _tokenERC20.approve(address(signals), amount);
        (initiativeId, tokenId) = signals.proposeInitiativeWithLock(
            "Test Initiative", "Description", amount, lockDuration, _emptyAttachmentsArray()
        );
        vm.stopPrank();

        vm.warp(block.timestamp + 61 days); // Past activity timeout
        vm.prank(_deployer);
        signals.expireInitiative(initiativeId);
    }

    /*//////////////////////////////////////////////////////////////
                    INCENTIVES POOL HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploy and fund an IncentivesPool with reward tokens
    /// @param fundAmount Amount of reward tokens to add to the pool (in USDC units - 6 decimals)
    /// @return pool The deployed IncentivesPool contract
    /// @return poolOwner The address that owns the pool
    function deployAndFundIncentivesPool(uint256 fundAmount)
        internal
        returns (IncentivesPool pool, address poolOwner)
    {
        // Use existing USDC token as reward token
        // Deploy pool owned by _poolOwner
        vm.prank(_poolOwner);
        pool = new IncentivesPool(address(_usdc));

        // Mint and fund the pool
        deal(address(_usdc), _poolOwner, fundAmount);
        vm.startPrank(_poolOwner);
        _usdc.approve(address(pool), fundAmount);
        pool.addFundsToPool(fundAmount);
        vm.stopPrank();

        return (pool, _poolOwner);
    }

    /// @notice Deploy and fund an IncentivesPool with default 1M USDC
    /// @return pool The deployed IncentivesPool contract
    /// @return poolOwner The address that owns the pool
    function deployAndFundIncentivesPool()
        internal
        returns (IncentivesPool pool, address poolOwner)
    {
        return deployAndFundIncentivesPool(1_000_000 * 1e6); // USDC has 6 decimals
    }

    /// @notice Attach an IncentivesPool to a Signals board
    /// @dev MUST be called before the board opens (contract enforced)
    /// @param signals The Signals board to attach the pool to
    /// @param pool The IncentivesPool to attach
    /// @param boardBudget Total budget allocated to this board from the pool
    /// @param maxRewardPerInitiative Maximum reward that can be distributed per initiative
    function attachIncentivesPoolToBoard(
        ISignals signals,
        IncentivesPool pool,
        uint256 boardBudget,
        uint256 maxRewardPerInitiative
    ) internal {
        // Approve the board on the pool (must be done by pool owner)
        vm.startPrank(_poolOwner);
        pool.approveBoard(address(signals), boardBudget, maxRewardPerInitiative);
        vm.stopPrank();

        // Create incentives config with linear curve parameters [3, 1, 2]
        uint256[] memory incentiveParams = new uint256[](3);
        incentiveParams[0] = 3 * 1e18;
        incentiveParams[1] = 1 * 1e18;
        incentiveParams[2] = 2 * 1e18;

        IIncentivizer.IncentivesConfig memory incentivesConfig = IIncentivizer.IncentivesConfig({
            incentiveType: IIncentivizer.IncentiveType.Linear,
            incentiveParametersWAD: incentiveParams
        });

        // Set the pool on the board (must be done by deployer before board opens)
        vm.prank(_deployer);
        signals.setIncentivesPool(address(pool), incentivesConfig);
    }

    /// @notice Attach an IncentivesPool with default parameters (100k budget, 10k max reward)
    /// @param signals The Signals board to attach the pool to
    /// @param pool The IncentivesPool to attach
    function attachIncentivesPoolToBoard(ISignals signals, IncentivesPool pool) internal {
        attachIncentivesPoolToBoard(signals, pool, 100_000 * 1e18, 10_000 * 1e18);
    }

    /// @notice Deploy a Signals board with IncentivesPool already attached
    /// @dev Convenience wrapper that combines board deployment, pool deployment, and attachment
    /// @param config The board configuration
    /// @param boardBudget Total budget allocated to this board from the pool (in USDC - 6 decimals)
    /// @param maxRewardPerInitiative Maximum reward that can be distributed per initiative (in USDC - 6 decimals)
    /// @return signals The deployed Signals board
    /// @return pool The deployed and attached IncentivesPool (using _usdc as reward token)
    function deploySignalsWithIncentivesPool(
        ISignals.BoardConfig memory config,
        uint256 boardBudget,
        uint256 maxRewardPerInitiative
    ) internal returns (Signals signals, IncentivesPool pool) {
        // Deploy board
        signals = deploySignals(config);

        // Deploy and fund pool (uses _usdc internally)
        (pool,) = deployAndFundIncentivesPool();

        // Attach pool to board
        attachIncentivesPoolToBoard(
            ISignals(address(signals)), pool, boardBudget, maxRewardPerInitiative
        );

        return (signals, pool);
    }

    /// @notice Deploy a Signals board with IncentivesPool using default parameters
    /// @param config The board configuration
    /// @return signals The deployed Signals board
    /// @return pool The deployed and attached IncentivesPool (using _usdc as reward token)
    function deploySignalsWithIncentivesPool(ISignals.BoardConfig memory config)
        internal
        returns (Signals signals, IncentivesPool pool)
    {
        return deploySignalsWithIncentivesPool(config, 100_000 * 1e6, 10_000 * 1e6); // USDC has 6 decimals
    }
}
