// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

/**
 * @notice Simple ERC20Votes token for testing
 * @dev Implements ERC20 with voting capabilities and permit functionality
 */
contract MockERC20Votes is ERC20, ERC20Permit, ERC20Votes {
    constructor() ERC20("Governance Token", "vGOV") ERC20Permit("Governance Token") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function _update(address from, address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._update(from, to, amount);
    }

    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
