// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Script.sol';

import {SignalsFactory} from '../src/SignalsFactory.sol';
import {MockERC20} from '../src/__mocks__/MockERC20.m.sol'; // Add this line to import MockERC20;

/**
 * @notice forge script script/Development.s.sol --fork-url $LOCAL_RPC --broadcast --private-key $DEPLOYER_TESTNET_PRIVATE_KEY
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
    // Load the developer seed phrase from the environment variable
    string memory seedPhrase = vm.envString('DEPLOYER_TESTNET_SEED_PHRASE');
    console.log('Seed Phrase:', seedPhrase);

    // Derive addresses for alice, bob, and charlie using the seed phrase and HD paths
    deployer = vm.addr(vm.deriveKey(seedPhrase, 0));

    // Log the test addresses
    console.log('Deployer:', deployer);

    // --- Begin deployment script ---
    // Deploy MockERC20 token and mint 1 million tokens
    vm.startBroadcast();
    token = new MockERC20('CollabTech Hackathon', 'CTH');
    vm.stopBroadcast();

    vm.startBroadcast();
    uint256 initialSupply = 1_000_000 * 1e18;
    token.initialize(initialSupply);
    vm.stopBroadcast();
    console.log('Contract', address(token));

    // Distribute tokens to test addresses
    // vm.startBroadcast();
    // token.faucet(alice);
    // vm.stopBroadcast();
    // token.transfer(bob, 200_000 * 1e18);
    // token.transfer(charlie, 200_000 * 1e18);

    // Deploy SignalsFactory with the Signals implementation
    // factory = new SignalsFactory();

    // Deploy a new Signals contract using the factory
    // instance = factory.create();
  }
}
