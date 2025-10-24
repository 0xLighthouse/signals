// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {Signals} from "../../src/Signals.sol";
import {SignalsFactory} from "../../src/SignalsFactory.sol";
import {MockERC20} from "solady/test/utils/mocks/MockERC20.sol";
import {MockERC20Votes} from "../mocks/MockERC20Votes.m.sol";
import {ISignals} from "../../src/interfaces/ISignals.sol";
import {BoardConfigs} from "./BoardConfigs.sol";

contract SignalsHarness is Test {
    address _deployer = address(this);
    address _alice = address(0x1111);
    address _bob = address(0x2222);
    address _charlie = address(0x3333);
    address _liquidityProvider = address(0x4444);

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
        deal(address(token), _liquidityProvider, LIQUIDITY_PROVIDER_BALANCE * 10 ** token.decimals());
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

    function _emptyAttachmentsArray() internal pure returns (ISignals.Attachment[] memory attachments) {
        return new ISignals.Attachment[](0);
    }

    function _singleAttachment(
        string memory uri,
        string memory mimeType,
        string memory description
    ) internal pure returns (ISignals.Attachment[] memory attachments) {
        attachments = new ISignals.Attachment[](1);
        attachments[0] = ISignals.Attachment({uri: uri, mimeType: mimeType, description: description});
    }

    /// @notice Helper to propose initiative with lock and accept it
    /// @return initiativeId The ID of the created initiative
    /// @return tokenId The ID of the lock NFT
    function proposeAndAccept(ISignals signals, address proposer, uint256 amount, uint256 lockDuration)
        internal
        returns (uint256 initiativeId, uint256 tokenId)
    {
        vm.startPrank(proposer);
        _tokenERC20.approve(address(signals), amount);
        tokenId = signals.proposeInitiativeWithLock(
            "Test Initiative",
            "Description",
            amount,
            lockDuration,
            _emptyAttachmentsArray()
        );
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
        tokenId = signals.proposeInitiativeWithLock(
            "Test Initiative",
            "Description",
            amount,
            lockDuration,
            _emptyAttachmentsArray()
        );
        vm.stopPrank();

        initiativeId = 1;
        vm.warp(block.timestamp + 61 days); // Past activity timeout
        vm.prank(_deployer);
        signals.expireInitiative(initiativeId);
    }
}
