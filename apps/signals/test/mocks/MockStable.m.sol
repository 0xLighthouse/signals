// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockStable is ERC20 {
    // Track the number of claims per address
    mapping(address => uint256) private _claimCount;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function initialize(uint256 totalSupply) public {
        // Mint initial supply to the deployer
        _mint(msg.sender, totalSupply);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    // Mints 50k tokens to the specified address, limited to 10 claims
    function faucet(address to) public payable {
        require(_claimCount[to] < 10, "Address has already claimed 10 times");
        _mint(to, 50_000 * 1e6);
        _claimCount[to]++;
    }
}
