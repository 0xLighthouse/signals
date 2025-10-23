// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {MockERC20} from "../test/mocks/MockERC20.m.sol";
import {Signals} from "../src/Signals.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * Seeds three initiatives with a lock of 12 months from Alice, Bob and Charlie
 *
 * @notice forge script script/TestnetData.s.sol --fork-url $TESTNET_RPC --broadcast
 */
contract TestnetDataScript is Script {
// address _deployer;
// address _alice;
// address _bob;
// address _charlie;

// MockERC20 token;
// Signals board;

// string[] private titles = [
//     "Implement Governance Updates",
//     "Treasury Allocation Proposal",
//     "Community Development Fund",
//     "Protocol Upgrade Initiative",
//     "Partnership Program Launch"
// ];

// string[] private descriptions = [
//     "This proposal aims to improve the current governance structure...",
//     "A strategic allocation of treasury funds for sustainable growth...",
//     "Creating a dedicated fund for community-driven development...",
//     "Critical protocol upgrades to enhance security and efficiency...",
//     "Establishing strategic partnerships to expand ecosystem..."
// ];

// function _faucet(address _to, uint256 _amount) internal {
//     vm.startBroadcast(_deployer);
//     payable(_to).transfer(_amount);
//     vm.stopBroadcast();
// }

// function _createInitiativeData(uint256 index) internal view returns (string memory title, string memory body) {
//     // Use modulo to cycle through predefined content if index exceeds array length
//     uint256 i = index % titles.length;
//     title = string.concat(titles[i], " #", Strings.toString(index));
//     body = string.concat(
//         descriptions[i], "\n\nProposal ID: ", Strings.toString(index), "\nSubmitted as part of the test dataset"
//     );
// }

// function _proposeInitiative(uint256 _proposerKey, uint256 amountToLock, uint256 index) internal {
//     vm.startBroadcast(_proposerKey);
//     (string memory title, string memory body) = _createInitiativeData(index);
//     token.approve(address(board), amountToLock);
//     board.proposeInitiativeWithLock(title, body, amountToLock, 12);
//     vm.stopBroadcast();
// }

// function run() external {
//     // Load the private keys from the seed phrase
//     string memory seedPhrase = vm.envString("TESTNET_SEED_PHRASE");
//     address bondIssuer = vm.envAddress("TESTNET_BOND_ISSUER");

//     uint256 deployerKey = vm.deriveKey(seedPhrase, 0);
//     uint256 aliceKey = vm.deriveKey(seedPhrase, 1);
//     uint256 bobKey = vm.deriveKey(seedPhrase, 2);
//     uint256 charlieKey = vm.deriveKey(seedPhrase, 3);

//     address deployerAddress = vm.addr(deployerKey);

//     // DUMP ETH BALANCE
//     console.log("Deployer Address:", deployerAddress);
//     console.log("Deployer (ETH) Balance:", deployerAddress.balance);

//     // Get the addresses from the private keys
//     _deployer = vm.addr(deployerKey);
//     _alice = vm.addr(aliceKey);
//     _bob = vm.addr(bobKey);
//     _charlie = vm.addr(charlieKey);

//     // Load the Signals contract instance
//     board = Signals(bondIssuer);
//     token = MockERC20(board.token());
//     string memory tokenSymbol = token.symbol();

//     console.log("Deployer (%s) Balance:", tokenSymbol, token.balanceOf(deployerAddress));

//     // Log the deployer addresses
//     console.log("----- Accounts -----");
//     console.log("Deployer:", _deployer);
//     console.log("Alice:", _alice);
//     console.log("Bob:", _bob);
//     console.log("Charlie:", _charlie);

//     // Create array of private keys instead of addresses
//     uint256[3] memory proposerKeys = [aliceKey, bobKey, charlieKey];
//     address[3] memory proposers = [_alice, _bob, _charlie];

//     // If the proposer has no balance, top up their balance from the deployer
//     for (uint256 i = 0; i < proposers.length; i++) {
//         if (proposers[i].balance == 0) {
//             console.log("topping up address:", proposers[i], "with", 0.1 ether);
//             _faucet(proposers[i], 0.1 ether);
//         }
//     }

//     // Get threshold
//     uint256 proposalThreshold = board.getProposerRequirements().minBalance;
//     console.log("Proposal Threshold:", proposalThreshold);

//     for (uint256 i = 0; i < proposers.length; i++) {
//         // Send min tokens to proposers so they can propose initiatives
//         uint256 balanceBefore = token.balanceOf(proposers[i]);

//         uint256 balanceNeeded = balanceBefore > proposalThreshold ? 0 : proposalThreshold - balanceBefore;

//         if (balanceNeeded > 0) {
//             // Top up balance from deployer
//             vm.startBroadcast(deployerKey);
//             console.log("topping up address:", proposers[i], "with", balanceNeeded);
//             require(token.transfer(proposers[i], balanceNeeded), "Transfer failed");
//             vm.stopBroadcast();
//         }

//         // Propose initiative using the correct private key
//         uint256 amountToLock = proposalThreshold / 5;

//         _proposeInitiative(proposerKeys[i], amountToLock, i);
//     }

//     console.log("Initiative Count:", board.initiativeCount());
// }
}
