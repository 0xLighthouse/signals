// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/console.sol";
import {SharedScriptBase} from "@shared/SharedScriptBase.sol";
import {SignalsFactory} from "../src/SignalsFactory.sol";
import {Signals} from "../src/Signals.sol";
import {ISignalsFactory} from "../src/interfaces/ISignalsFactory.sol";
import {ISignals} from "../src/interfaces/ISignals.sol";
import {IAuthorizer} from "../src/interfaces/IAuthorizer.sol";
import {IExperimentToken} from "@shared/interfaces/IExperimentToken.sol";

/**
 * This script is used to create a Signals board with some default parameters for the Edge Experiment
 */
contract CreateBoard is SharedScriptBase {
    address _deployer;
    address _instance;

    address _alice;
    address _bob;
    address _charlie;

    SignalsFactory _factory;
    IExperimentToken _token;

    uint256 private constant PROPOSER_MIN_BALANCE = 10_000 ether;
    uint256 private constant PROPOSER_MIN_LOCK = 20_000 ether;
    uint256 private constant SUPPORTER_MIN_BALANCE = 10_000 ether;
    uint256 private constant SUPPORTER_MIN_LOCK = 5_000 ether;

    /**
     * @param network The network to deploy the contracts to
     * @param factoryAddress The address of the deployed SignalsFactory
     * @param underlyingToken The address of the underlying token
     */
    function run(string memory network, address factoryAddress, address underlyingToken) external {
        if (!isSupportedNetwork(network)) {
            revert(string.concat("Unsupported network [", network, "] provided"));
        }

        (uint256 deployerPrivateKey, address deployerAddress) = _loadDeployer(network);

        console.log("DeployerAddress", deployerAddress);

        // Get factory reference
        _factory = SignalsFactory(factoryAddress);
        _token = IExperimentToken(underlyingToken);

        // Derive example participant accounts from the seed phrase when on anvil
        if (keccak256(abi.encodePacked(network)) != keccak256(abi.encodePacked("anvil"))) {
            revert(string.concat("Only anvil network is supported for local deployment"));
        }

        string memory seedPhrase = vm.envString("ANVIL_SEED_PHRASE");
        _alice = vm.addr(vm.deriveKey(seedPhrase, 1));
        _bob = vm.addr(vm.deriveKey(seedPhrase, 2));
        _charlie = vm.addr(vm.deriveKey(seedPhrase, 3));

        console.log("=== Board Creation ===");
        console.log("Deployer:", deployerAddress);
        console.log("Factory:", factoryAddress);
        console.log("Alice:", _alice);
        console.log("Bob:", _bob);
        console.log("Charlie:", _charlie);

        _seedParticipants(deployerPrivateKey);

        // decayCurveParameters for decayCurveType = 1 (exponential)
        // params[0]: per-interval multiplier in 18-decimal fixed-point.
        // With lockInterval = 3 days and maxLockIntervals = 7, the effective
        // time-weight over t intervals is: weight = nominalAmount * (0.92^t).
        // Example: at 7 intervals (21 days), multiplier ≈ 0.92^7 ≈ 0.558.
        uint256[] memory params = new uint256[](1);
        params[0] = 92e16; // 0.92e18 per-interval exponential multiplier

        // Create a Signals instance via factory
        vm.startBroadcast(deployerPrivateKey);
        address protocolAddress = _factory.create(
            ISignals.BoardConfig({
                version: _factory.version(),
                owner: _alice,
                underlyingToken: underlyingToken,
                acceptanceThreshold: 45_000_000 ether, // 45M tokens
                maxLockIntervals: 7, // 21 days
                proposalCap: 5, // 30 proposals
                lockInterval: 3 days, // 3 days
                decayCurveType: 1, // exponential
                decayCurveParameters: params,
                inactivityTimeout: 10 days, // 10 days
                proposerRequirements: IAuthorizer.ParticipantRequirements({
                    eligibilityType: IAuthorizer.EligibilityType.MinBalance,
                    minBalance: PROPOSER_MIN_BALANCE, // 10k tokens
                    minHoldingDuration: 0,
                    minLockAmount: PROPOSER_MIN_LOCK // 20k tokens
                }),
                supporterRequirements: IAuthorizer.ParticipantRequirements({
                    eligibilityType: IAuthorizer.EligibilityType.MinBalance,
                    minBalance: SUPPORTER_MIN_BALANCE,
                    minHoldingDuration: 0,
                    minLockAmount: SUPPORTER_MIN_LOCK
                }),
                releaseLockDuration: 0,
                boardOpenAt: block.timestamp + 1 hours,
                boardClosedAt: (block.timestamp + 1 hours) + 30 days // ~30 days after opening (end of experiment)
            })
        );
        vm.stopBroadcast();

        Signals protocol = Signals(protocolAddress);
        console.log("SignalsContract", protocolAddress);
        console.log("Total proposals", protocol.totalInitiatives());
        console.log("Proposal threshold", protocol.getProposerRequirements().minBalance);
        console.log("Acceptance threshold", protocol.acceptanceThreshold());

        // // Deploy a mock USDC and initialize
        // vm.startBroadcast(deployerPrivateKey);
        // MockStable usdc = new MockStable("Mocked USDC", "USDC");
        // usdc.initialize(1_000_000 * 1e6);
        // vm.stopBroadcast();
        // console.log("USDCContract", address(usdc));

        // // Initialize and configure a TokenRegistry
        // vm.startBroadcast(deployerPrivateKey);
        // TokenRegistry registry = new TokenRegistry();
        // registry.allow(address(_token));
        // registry.allow(address(usdc));
        // vm.stopBroadcast();
        // console.log("RegistryContract", address(registry));

        // // Create bounties and wire into protocol
        // uint256[3] memory _allocations = [uint256(5), uint256(20), uint256(75)];
        // address[3] memory _receivers = [address(_alice), address(_bob), address(_charlie)];

        // vm.startBroadcast(deployerPrivateKey);
        // _bounties = new Bounties(address(protocolAddress), address(registry), _allocations, _receivers);
        // Signals(protocolAddress).setBounties(address(_bounties));
        // vm.stopBroadcast();
        // console.log("BountiesContract", address(_bounties));
    }

    function _seedParticipants(uint256 deployerPrivateKey) internal {
        IExperimentToken.BatchMintRequest[] memory mints =
            new IExperimentToken.BatchMintRequest[](3);
        mints[0] = IExperimentToken.BatchMintRequest({to: _alice, amount: PROPOSER_MIN_BALANCE * 3});
        mints[1] = IExperimentToken.BatchMintRequest({to: _bob, amount: PROPOSER_MIN_BALANCE * 2});
        mints[2] = IExperimentToken.BatchMintRequest({to: _charlie, amount: SUPPORTER_MIN_LOCK * 5});

        vm.startBroadcast(deployerPrivateKey);
        _token.batchMint(mints, "Seed Signals experiment participants");
        vm.stopBroadcast();
    }
}
