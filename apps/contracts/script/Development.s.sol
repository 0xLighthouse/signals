// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Script.sol';

import {SignalsFactory} from '../src/SignalsFactory.sol';
import {Signals} from '../src/Signals.sol';
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
    // Load the private key from the environment
    string memory seedPhrase = vm.envString('DEPLOYER_TESTNET_SEED_PHRASE');
    deployer = vm.addr(vm.deriveKey(seedPhrase, 0));
    alice = vm.addr(vm.deriveKey(seedPhrase, 1));
    bob = vm.addr(vm.deriveKey(seedPhrase, 2));
    charlie = vm.addr(vm.deriveKey(seedPhrase, 3));

    // Log the deployer addresses
    console.log('----- Accounts -----');
    console.log('Deployer:', deployer);
    console.log('Alice:', alice);
    console.log('Bob:', bob);
    console.log('Charlie:', charlie);

    // Deploy MockERC20 token and mint 1 million tokens
    console.log('----- Contracts -----');
    vm.broadcast(deployer);
    token = new MockERC20('CollabTech', 'SGNL');
    console.log('TokenContract', address(token));

    uint256 initialSupply = 1_000_000 * 1e18;

    vm.broadcast(deployer);
    token.initialize(initialSupply);
    console.log('TokenContract', 'initialized');

    // Distribute tokens to test addresses
    vm.broadcast(deployer);
    token.faucet(alice);

    vm.broadcast(deployer);
    token.faucet(bob);

    vm.broadcast(deployer);
    token.faucet(charlie);

    // Deploy a new SignalsFactory contract
    vm.broadcast(deployer);
    factory = new SignalsFactory();
    console.log('FactoryContract', address(factory));

    // Deploy a new Signals contract using the factory
    vm.broadcast(deployer);
    address protocolAddress = factory.create(
      alice,
      address(token),
      50_000 * 1e18, // 50k _proposalThreshold
      200_000 * 1e18, // 200k _acceptanceThreshold
      12, // lockDurationCap
      5, // map active initiatives
      1 hours, // decayInterval
      0 // decayCurveType, linear
    );

    Signals protocol = Signals(protocolAddress);

    console.log('SignalsContract', address(protocolAddress));
    console.log('Total proposals', protocol.count());
    console.log('Proposal threshold', protocol.proposalThreshold());
    console.log('Acceptance threshold', protocol.acceptanceThreshold());
  }
}
