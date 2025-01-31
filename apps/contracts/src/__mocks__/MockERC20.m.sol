// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.28;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract MockERC20 is ERC20 {
  // Track the number of claims per address
  mapping(address => uint256) private claimCount;

  constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

  function initialize(uint256 totalSupply) public {
    // Mint initial supply to the deployer
    _mint(msg.sender, totalSupply);
  }

  // Mints 10k tokens to the specified address, limited to 10 claims
  function faucet(address to) public payable {
    require(claimCount[to] < 10, 'Address has already claimed 10 times');
    _mint(to, 10_000 * 1e18);
    claimCount[to]++;
  }
}
