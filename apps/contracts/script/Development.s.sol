// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Script.sol';

import {SignalsFactory} from '../src/SignalsFactory.sol';
import {MockERC20} from '../src/__mocks__/MockERC20.m.sol'; // Add this line to import MockERC20;

/**
 * @notice forge script script/Development.s.sol --fork-url $LOCAL_RPC --broadcast
 */
contract DevelopmentScript is Script {
  address deployer;
  address instance;

  address alice;
  address bob;
  address charlie;

  MockERC20 token;
  SignalsFactory factory;

  function run() external {
    deployer = msg.sender;

    // Load the developer seed phrase from the environment variable
    string memory seedPhrase = vm.envString('DEPLOYER_TESTNET_SEED_PHRASE');
    console.log('Seed Phrase:', seedPhrase);

    // Derive addresses for alice, bob, and charlie using the seed phrase and HD paths
    alice = vm.addr(vm.deriveKey(seedPhrase, 0));
    bob = vm.addr(vm.deriveKey(seedPhrase, 1));
    charlie = vm.addr(vm.deriveKey(seedPhrase, 2));

    // Log the test addresses
    console.log('Deployer:', deployer);
    console.log('Alice:', alice);
    console.log('Bob:', bob);
    console.log('Charlie:', charlie);

    // --- Begin deployment script ---
    vm.startPrank(deployer);

    // Deploy MockERC20 token and mint 1 million tokens
    uint256 initialSupply = 1_000_000 * 1e18;
    token = new MockERC20('CollabTech Hackathon', 'CTH');
    token.initialize(initialSupply);
    console.log('Contract', address(token));

    // Distribute tokens to test addresses
    token.transfer(alice, 200_000 * 1e18);
    token.transfer(bob, 200_000 * 1e18);
    token.transfer(charlie, 200_000 * 1e18);

    // Deploy SignalsFactory with the Signals implementation
    // factory = new SignalsFactory();

    // Deploy a new Signals contract using the factory
    // instance = factory.create();

    vm.stopPrank();
  }
}
