// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/console.sol";
import {SharedScriptBase} from "@shared/SharedScriptBase.sol";
import {ISignals} from "../src/interfaces/ISignals.sol";
import {IAuthorizer} from "../src/interfaces/IAuthorizer.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IExperimentToken} from "@shared/interfaces/IExperimentToken.sol";

/**
 * Seeds a Signals board with example initiatives and token locks for local testing.
 *
 * @notice forge script script/TestnetData.s.sol --rpc-url $ANVIL_RPC_URL --broadcast --sig "run(string,address)" anvil <boardAddress>
 */
contract SeedInitiativesScript is SharedScriptBase {
    IExperimentToken private token;
    ISignals private board;

    address private _deployer;
    address private _alice;
    address private _bob;
    address private _charlie;

    string[] private titles = [
        "Accelerating Local Coordination Networks",
        "Ethical Acceleration Charter",
        "AI-Augmented Collective Reasoning Pilot"
    ];

    string[] private descriptions = [
        "Establish funding and shared tools for neighborhood-scale coordination experiments.",
        "Draft and ratify a shared framework for ethical acceleration across decentralized systems.",
        "Experiment with AI-assisted deliberation tools that summarize arguments and surface consensus."
    ];

    function run(string memory network, address boardAddress) external {
        if (!isSupportedNetwork(network)) {
            revert(string.concat("Unsupported network [", network, "] provided"));
        }

        // This script is intended for local testing where faucet mechanics are available.
        if (keccak256(abi.encodePacked(network)) != keccak256(abi.encodePacked("anvil"))) {
            revert("SeedInitiativesScript only supports the anvil network");
        }

        (uint256 deployerKey, address deployerAddress) = _loadDeployer(network);
        console.log("=== Seeds: Initiatives ===");
        console.log(string.concat("Network: ", network));
        console.log("Deployer:", deployerAddress);

        string memory seedPhrase = vm.envString("ANVIL_SEED_PHRASE");

        uint256 aliceKey = vm.deriveKey(seedPhrase, 1);
        uint256 bobKey = vm.deriveKey(seedPhrase, 2);
        uint256 charlieKey = vm.deriveKey(seedPhrase, 3);

        _deployer = deployerAddress;
        _alice = vm.addr(aliceKey);
        _bob = vm.addr(bobKey);
        _charlie = vm.addr(charlieKey);

        board = ISignals(boardAddress);
        token = IExperimentToken(board.token());

        console.log("Signals board:", boardAddress);
        console.log("Token:", address(token));
        console.log(string.concat("Token symbol: ", token.symbol()));

        uint256[3] memory proposerKeys = [aliceKey, bobKey, charlieKey];
        address[3] memory proposers = [_alice, _bob, _charlie];

        _ensureEthBalances(proposers);
        _seedTokenBalances(deployerKey, proposers);

        _ensureBoardOpen();

        IAuthorizer.ParticipantRequirements memory proposerReq = board.getProposerRequirements();
        uint256 proposalThreshold = proposerReq.minBalance;
        console.log("Proposal threshold:", proposalThreshold);
        uint256 lockRequirement = proposerReq.minLockAmount;
        if (lockRequirement == 0) {
            lockRequirement = proposalThreshold > 0 ? proposalThreshold : 1 ether;
        }
        for (uint256 i = 0; i < proposers.length; i++) {
            _proposeInitiative(proposerKeys[i], lockRequirement, i);
        }

        console.log("Final initiative count:", board.initiativeCount());
    }

    function _ensureBoardOpen() internal {
        uint256 openAt = board.boardOpenAt();
        if (openAt > block.timestamp) {
            console.log("Warping chain to open board at:", openAt);
            vm.warp(openAt + 1);
        }
    }

    function _ensureEthBalances(address[3] memory accounts) internal {
        for (uint256 i = 0; i < accounts.length; i++) {
            if (accounts[i].balance == 0) {
                console.log("Topping up ETH for:", accounts[i]);
                vm.deal(accounts[i], 0.1 ether);
            }
        }
    }

    function _seedTokenBalances(uint256 deployerKey, address[3] memory proposers) internal {
        uint256 proposalThreshold = board.getProposerRequirements().minBalance;
        vm.startBroadcast(deployerKey);
        for (uint256 i = 0; i < proposers.length; i++) {
            uint256 balance = token.balanceOf(proposers[i]);
            uint256 requiredBalance = proposalThreshold > balance ? proposalThreshold - balance : 0;
            if (requiredBalance > 0) {
                console.log("Transferring tokens to:", proposers[i]);
                bool success = token.transfer(proposers[i], requiredBalance);
                require(success, "token transfer failed");
            }
        }
        vm.stopBroadcast();
    }

    function _createInitiativeData(uint256 index)
        internal
        view
        returns (string memory title, string memory body)
    {
        uint256 i = index % titles.length;
        title = string.concat(titles[i], " #", Strings.toString(index + 1));
        body = string.concat(
            descriptions[i],
            "\n\nProposal ID: ",
            Strings.toString(index + 1),
            "\nSubmitted as part of the test dataset"
        );
    }

    function _proposeInitiative(uint256 proposerKey, uint256 amountToLock, uint256 index) internal {
        vm.startBroadcast(proposerKey);
        (string memory title, string memory body) = _createInitiativeData(index);
        token.approve(address(board), amountToLock);
        ISignals.Attachment[] memory attachments = new ISignals.Attachment[](0);
        board.proposeInitiativeWithLock(title, body, attachments, amountToLock, 12);
        vm.stopBroadcast();
        console.log(string.concat("Submitted initiative: ", title));
    }
}
