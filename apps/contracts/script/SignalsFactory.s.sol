// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from 'forge-std/Script.sol';
import {SignalsFactory} from '../src/SignalsFactory.sol';

contract SignalsFactoryScript is Script {
  SignalsFactory public factory;

  function setUp() public {}

  function run() public {
    vm.startBroadcast();

    // TODO
    // factory = new SignalsFactory();

    vm.stopBroadcast();
  }
}
