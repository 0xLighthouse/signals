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
contract DeploySignalsBoardFromFactory is SharedScriptBase {
    address _deployer;
    address _instance;

    address _alice;
    address _bob;
    address _charlie;

    SignalsFactory _factory;
    IExperimentToken _token;

    uint256 private constant PROPOSER_MIN_BALANCE = 20_000 ether;
    uint256 private constant PROPOSER_MIN_LOCK = 20_000 ether;
    uint256 private constant SUPPORTER_MIN_BALANCE = 10_000 ether;
    uint256 private constant SUPPORTER_MIN_LOCK = 5_000 ether;
    uint256 private constant MIN_THRESHOLD = 1_000_000 ether;
    uint256 private constant THRESHOLD_PERCENT_WAD = 10e16; // 10%

    /**
     *
     * @notice Usage:
     * forge script script/DeploySignalsBoardFromFactory.s.sol:DeploySignalsBoardFromFactory \
     *     --rpc-url "$ANVIL_RPC" \
     *     --broadcast \
     *     -s "run(string,address,address)" \
     *     "anvil" \
     *     "$signals_factory_address" \
     *     "$token_address"
     *
     * @param network The network to deploy the contracts to
     * @param factoryAddress The address of the deployed SignalsFactory
     * @param underlyingToken The address of the underlying token
     */
    function run(string memory network, address factoryAddress, address underlyingToken) external {
        if (!isSupportedNetwork(network)) {
            revert(string.concat("Unsupported network [", network, "] provided"));
        }

        (uint256 deployerPrivateKey, address deployerAddress) = _loadPrivateKey(network, "deployer");

        // Get factory reference
        _factory = SignalsFactory(factoryAddress);
        _token = IExperimentToken(underlyingToken);

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
                boardMetadata: ISignals.Metadata({
                    title: "Default Board",
                    body: "Default board deployed via script.",
                    attachments: new ISignals.Attachment[](0)
                }),
                owner: deployerAddress,
                underlyingToken: underlyingToken,
                acceptanceCriteria: ISignals.AcceptanceCriteria({
                    permissions: ISignals.AcceptancePermissions.OnlyOwner,
                    thresholdOverride: ISignals.ThresholdOverride.OnlyOwner,
                    thresholdPercentTotalSupplyWAD: THRESHOLD_PERCENT_WAD,
                    minThreshold: MIN_THRESHOLD
                }),
                lockInterval: 1 days,
                maxLockIntervals: 7,
                decayCurveType: 1, // exponential
                decayCurveParameters: params,
                inactivityTimeout: 3 days, // 3 days
                proposerRequirements: IAuthorizer.ParticipantRequirements({
                    minBalance: PROPOSER_MIN_BALANCE, // 20k tokens
                    minHoldingDuration: 0, // Balance-only requirement
                    minLockAmount: PROPOSER_MIN_LOCK // 20k tokens
                }),
                supporterRequirements: IAuthorizer.ParticipantRequirements({
                    minBalance: SUPPORTER_MIN_BALANCE,
                    minHoldingDuration: 0, // Balance-only requirement
                    minLockAmount: SUPPORTER_MIN_LOCK
                }),
                releaseLockDuration: 0,
                boardOpenAt: block.timestamp - 1 days,
                boardClosedAt: block.timestamp + 90 days
            })
        );

        vm.stopBroadcast();
        Signals protocol = Signals(protocolAddress);

        console.log("=== Signals Board Deployment ===");
        console.log("Deployer: ", protocol.owner());
        console.log("Underlying Token: ", protocol.underlyingToken());
        console.log("Signals Contract Address: ", protocolAddress);

        console.log("ScriptOutput:", protocolAddress);
    }
}
