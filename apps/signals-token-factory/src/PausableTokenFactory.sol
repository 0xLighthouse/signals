// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PausableToken
 * @dev ERC20 token with burn and pause capabilities controlled by the owner.
 */
contract PausableToken is ERC20Burnable, ERC20Pausable, Ownable {
    constructor(
        string memory name_,
        string memory symbol_,
        address initialOwner_,
        uint256 initialSupply_
    ) ERC20(name_, symbol_) Ownable(initialOwner_) {
        _mint(initialOwner_, initialSupply_);
    }

    /**
     * @notice Pauses all token transfers, mints, and burns.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Resumes token transfers, mints, and burns.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Resolve multiple inheritance of `_update`.
     */
    function _update(address from, address to, uint256 value) internal virtual override(ERC20, ERC20Pausable) {
        super._update(from, to, value);
    }
}

/**
 * @title PausableTokenFactory
 * @notice Deploys pausable ERC20 tokens with an assignable owner and initial supply.
 */
contract PausableTokenFactory {
    event TokenDeployed(
        address indexed owner,
        address indexed token,
        string name,
        string symbol,
        uint256 initialSupply
    );

    /**
     * @notice Deploy a new PausableToken with the provided configuration.
     * @param name The token name.
     * @param symbol The token symbol.
     * @param initialSupply The initial token supply (18 decimal places by default).
     * @param owner The owner who receives the initial supply and can control pausing.
     *        If zero address is provided, the caller becomes the owner.
     */
    function deployToken(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address owner
    ) external returns (address tokenAddress) {
        address resolvedOwner = owner == address(0) ? msg.sender : owner;
        PausableToken token = new PausableToken(name, symbol, resolvedOwner, initialSupply);
        emit TokenDeployed(resolvedOwner, address(token), name, symbol, initialSupply);
        return address(token);
    }
}
