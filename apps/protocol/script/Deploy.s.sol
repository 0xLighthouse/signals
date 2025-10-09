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
 * @notice forge script script/Deploy.s.sol --fork-url $ARBITRUM_SEPOLIA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY
 * @notice forge script script/Deploy.s.sol --fork-url $ARBITRUM_SEPOLIA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY --verify
 */
contract DevelopmentScript is Script {
    address _deployer;
    address _owner;

    address _instance;

    MockERC20 _token;
    SignalsFactory _factory;
    Bounties _bounties;

    function run() external {
        // Load the private key from the environment
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        uint256 ownerPrivateKey = vm.envUint("OWNER_PRIVATE_KEY");

        _deployer = vm.addr(deployerPrivateKey);
        _owner = vm.addr(ownerPrivateKey);

        // Log the deployer addresses
        console.log("----- Accounts -----");
        console.log("Deployer:", _deployer);
        console.log("Owner:", _owner);

        // Deploy MockERC20 token and mint 1 million tokens
        console.log("----- Contracts -----");
        vm.broadcast(deployerPrivateKey);
        _token = new MockERC20("CollabTech", "SGNL");
        console.log("TokenContract", address(_token));

        uint256 initialSupply = 1_000_000 * 1e18;

        vm.broadcast(deployerPrivateKey);
        _token.initialize(initialSupply);
        console.log("TokenContract", "initialized");

        // Distribute tokens to test addresses
        vm.broadcast(deployerPrivateKey);
        _token.faucet(_owner);

        // Deploy a new SignalsFactory contract
        vm.broadcast(deployerPrivateKey);
        _factory = new SignalsFactory();
        console.log("FactoryContract", address(_factory));

        uint256[] memory params = new uint256[](1);
        params[0] = 11e17; // 1.1

        // Deploy a new Signals contract using the factory
        vm.broadcast(deployerPrivateKey);
        address protocolAddress = _factory.create(
            ISignalsFactory.FactoryDeployment({
                owner: _owner,
                underlyingToken: address(_token),
                acceptanceThreshold: 1_000_000 * 1e18, // 1M _acceptanceThreshold
                maxLockIntervals: 30, // lockDurationCap (30 days)
                proposalCap: 5, // map active initiatives
                lockInterval: 1 days, // decayInterval
                decayCurveType: 0, // decayCurveType, linear
                decayCurveParameters: params, // decayCurveParameters
                proposerRequirements: ISignals.ProposerRequirements({
                    eligibilityType: ISignals.EligibilityType.None,
                    minBalance: 0,
                    minHoldingDuration: 0,
                    threshold: 25_000 * 1e18 // 25k proposalThreshold
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

        console.log("SignalsContract:", address(protocolAddress));
        console.log("->Proposal threshold:", protocol.getProposerRequirements().threshold);
        console.log("-> Acceptance threshold:", protocol.acceptanceThreshold());

        vm.broadcast(deployerPrivateKey);
        MockStable usdc = new MockStable("Mocked USDC", "USDC");

        console.log("USDCContract", address(usdc));

        vm.broadcast(deployerPrivateKey);
        usdc.initialize(1_000_000 * 1e6);

        // Initialize TokenRegistry
        vm.broadcast(deployerPrivateKey);
        TokenRegistry registry = new TokenRegistry();

        console.log("RegistryContract:", address(registry));

        vm.broadcast(deployerPrivateKey);
        registry.allow(address(_token)); // Allow token rewards

        vm.broadcast(deployerPrivateKey);
        registry.allow(address(usdc)); // Allow usdc rewards

        // Create bounties
        uint256[3] memory _allocations = [uint256(5), uint256(20), uint256(75)];
        address[3] memory _receivers = [address(_deployer), address(_owner), address(_owner)];

        vm.broadcast(deployerPrivateKey);
        _bounties = new Bounties(address(protocolAddress), address(registry), _allocations, _receivers);

        console.log("BountiesContract", address(_bounties));

        // Set the Bounties contract in the Signals contract
        vm.broadcast(ownerPrivateKey);
        Signals(protocolAddress).setBounties(address(_bounties));
    }
}
