// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {SignalsFactory} from "../src/SignalsFactory.sol";
import {Signals} from "../src/Signals.sol";
import {ISignals} from "../src/interfaces/ISignals.sol";
import {ISignalsFactory} from "../src/interfaces/ISignalsFactory.sol";
import {MockERC20} from "../test/mocks/MockERC20.m.sol";
import {MockStable} from "../test/mocks/MockStable.m.sol";
import {TokenRegistry} from "../src/TokenRegistry.sol";
import {Incentives} from "../src/Incentives.sol";

/**
 * This script is used to deploy the Signals contracts on a local development network.
 *
 * It will deploy:
 * - a MockERC20 token
 * - a SignalsFactory
 * - a Signals contract
 * - a TokenRegistry
 * - an Incentives contract
 *
 *
 * @notice forge script script/Development.s.sol --fork-url $LOCAL_RPC --broadcast
 */
contract DevelopmentScript is Script {
    address _deployer;
    address _instance;

    address _alice;
    address _bob;
    address _charlie;

    MockERC20 _token;
    SignalsFactory _factory;
    Incentives _incentives;

    function run() external {
        // Load the private key from the environment
        string memory seedPhrase = vm.envString("DEVELOPMENT_SEED_PHRASE");
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
        _token = new MockERC20("CollabTech", "SGNL");
        console.log("TokenContract", address(_token));

        uint256 initialSupply = 1_000_000 * 1e18;

        vm.broadcast(_deployer);
        _token.initialize(initialSupply);
        console.log("TokenContract", "initialized");

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
                proposalThreshold: 50_000 * 1e18, // 50k _proposalThreshold
                acceptanceThreshold: 200_000 * 1e18, // 200k _acceptanceThreshold
                maxLockIntervals: 12, // lockDurationCap
                proposalCap: 5, // map active initiatives
                lockInterval: 1 hours, // decayInterval
                decayCurveType: 0, // decayCurveType, linear
                decayCurveParameters: params // decayCurveParameters
            })
        );

        Signals protocol = Signals(protocolAddress);

        console.log("SignalsContract", address(protocolAddress));
        console.log("Total proposals", protocol.totalInitiatives());
        console.log("Proposal threshold", protocol.proposalThreshold());
        console.log("Acceptance threshold", protocol.acceptanceThreshold());

        vm.broadcast(_deployer);
        MockStable usdc = new MockStable("Mocked USDC", "USDC");

        console.log("USDCContract", address(usdc));

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

        // Create incentives
        uint256[3] memory _allocations = [uint256(5), uint256(20), uint256(75)];
        address[3] memory _receivers = [address(_alice), address(_bob), address(_charlie)];

        vm.broadcast(_deployer);
        _incentives = new Incentives(address(protocolAddress), address(registry), _allocations, _receivers);

        console.log("IncentivesContract", address(_incentives));

        // Set the Incentives contract in the Signals contract
        uint256 alicePrivateKey = vm.deriveKey(seedPhrase, 1);
        vm.broadcast(alicePrivateKey);
        Signals(protocolAddress).setIncentives(address(_incentives));
    }
}
