// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {SignalsFactory} from "../src/SignalsFactory.sol";
import {Signals} from "../src/Signals.sol";
import {ISignalsFactory} from "../src/interfaces/ISignalsFactory.sol";
import {ISignals} from "../src/interfaces/ISignals.sol";
import {MockERC20} from "../test/mocks/MockERC20.m.sol";
import {MockStable} from "../test/mocks/MockStable.m.sol";
import {TokenRegistry} from "../src/TokenRegistry.sol";
import {Bounties} from "../src/Bounties.sol";

/**
 * This script is used to deploy the Signals contracts to testnet.
 *
 * It will deploy:
 * - a MockERC20 token
 * - a SignalsFactory
 * - a Signals contract
 * - a TokenRegistry
 * - an Bounties contract
 *
 * @notice forge script script/Testnet.s.sol --fork-url $TESTNET_RPC --broadcast
 */
contract TestnetScript is Script {
    address _deployer;
    address _instance;

    address _alice;
    address _bob;
    address _charlie;

    MockERC20 _token;
    SignalsFactory _factory;
    Bounties _bounties;

    function run() external {
        // Load the private key from the environment
        string memory seedPhrase = vm.envString("TESTNET_SEED_PHRASE");
        _deployer = vm.addr(vm.deriveKey(seedPhrase, 0));
        _alice = vm.addr(vm.deriveKey(seedPhrase, 1));
        _bob = vm.addr(vm.deriveKey(seedPhrase, 2));
        _charlie = vm.addr(vm.deriveKey(seedPhrase, 3));

        // Log the deployer addresses
        console.log("----- Accounts -----");
        console.log("Deployer:", _deployer);
        console.log("Alice:", _alice);
        console.log("Bob:", _bob);
        console.log("Charlie:", _charlie);

        // Deploy MockERC20 token and mint 1 million tokens
        console.log("----- Contracts -----");
        vm.broadcast(_deployer);
        _token = new MockERC20("UniswapHookathon", "UHI");
        console.log("TokenContract", address(_token));

        uint256 initialSupply = 1_000_000 * 1e18;

        vm.broadcast(_deployer);
        _token.initialize(initialSupply);

        // Distribute tokens to test addresses
        vm.broadcast(_deployer);
        _token.faucet(_alice);

        vm.broadcast(_deployer);
        _token.faucet(_bob);

        vm.broadcast(_deployer);
        _token.faucet(_charlie);

        // Deploy a new SignalsFactory contract
        vm.broadcast(_deployer);
        _factory = new SignalsFactory();
        console.log("FactoryContract", address(_factory));

        uint256[] memory params = new uint256[](1);
        params[0] = 9e17;

        // Deploy a new Signals contract using the factory
        vm.broadcast(_deployer);
        address protocolAddress = _factory.create(
            ISignalsFactory.FactoryDeployment({
                owner: _alice,
                underlyingToken: address(_token),
                acceptanceThreshold: 200_000 * 1e18, // 200k _acceptanceThreshold
                maxLockIntervals: 365, // Lock for a maximum of 365 days
                proposalCap: 10, // Maximum number of proposals per user
                lockInterval: 1 days, // 1 day
                decayCurveType: 0, // decayCurveType, linear
                decayCurveParameters: params, // decayCurveParameters
                proposerRequirements: ISignals.ProposerRequirements({
                    eligibilityType: ISignals.EligibilityType.None,
                    minBalance: 0,
                    minHoldingDuration: 0,
                    threshold: 50_000 * 1e18 // 50k proposalThreshold
                }),
                participantRequirements: ISignals.ParticipantRequirements({
                    eligibilityType: ISignals.EligibilityType.None,
                    minBalance: 0,
                    minHoldingDuration: 0
                }),
                releaseLockDuration: 0, // Immediate release on acceptance
                boardOpensAt: 0, // Open immediately
                boardIncentives: ISignals.BoardIncentives({
                    enabled: false,
                    curveType: 0,
                    curveParameters: new uint256[](0)
                })
            })
        );

        Signals protocol = Signals(protocolAddress);

        console.log("SignalsContract", address(protocolAddress));
        console.log("Total proposals", protocol.totalInitiatives());
        console.log("Proposal threshold", protocol.getProposerRequirements().threshold);
        console.log("Acceptance threshold", protocol.acceptanceThreshold());

        vm.broadcast(_deployer);
        MockStable usdc = new MockStable("Mocked USDC", "USDC");
        console.log("USDC contract", address(usdc));

        vm.broadcast(_deployer);
        usdc.initialize(1_000_000 * 1e6);

        // Initialize TokenRegistry
        vm.broadcast(_deployer);
        TokenRegistry registry = new TokenRegistry();

        console.log("RegistryContract", address(registry));

        vm.broadcast(_deployer);
        registry.allow(address(_token)); // Allow token rewards

        vm.broadcast(_deployer);
        registry.allow(address(usdc)); // Allow usdc rewards

        // Create bounties
        uint256[3] memory _allocations = [uint256(5), uint256(20), uint256(75)];
        address[3] memory _receivers = [address(_alice), address(_bob), address(_charlie)];

        // TODO: Move this to the Factory deployment
        vm.broadcast(_deployer);
        _bounties = new Bounties(address(protocolAddress), address(registry), _allocations, _receivers);

        console.log("BountiesContract", address(_bounties));

        // Set the Bounties contract in the Signals contract
        uint256 alicePrivateKey = vm.deriveKey(seedPhrase, 1);
        vm.broadcast(alicePrivateKey);
        Signals(protocolAddress).setBounties(address(_bounties));
    }
}
