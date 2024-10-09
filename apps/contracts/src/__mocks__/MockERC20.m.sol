// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import 'lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol';

contract MockERC20 is ERC20 {
  constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

  function initialize(uint256 totalSupply) public {
    // Mint initial supply to the deployer
    _mint(msg.sender, totalSupply * 1e18);
  }

  // Mints 50k tokens to the specified address
  function faucet(address to) public {
    _mint(to, 50_000 * 1e18);
  }
}
