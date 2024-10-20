// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.28;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import './Incentives.sol';

contract TokenRegistry is Ownable {
    using SafeERC20 for IERC20;
 
    mapping(address => bool) public registry;

    event TokenAdded(address indexed token);
    event TokenRemoved(address indexed token);
    
    function allow(address _token) external onlyOwner {
        require(!registry[_token], "Token already registered");
        registry[_token] = true;
        emit TokenAdded(_token);
    }

    function deny(address _token) external onlyOwner {
        require(registry[_token], "Token not approved");
        registry[_token] = false;
        emit TokenRemoved(_token);
    }

    function isAllowed(address _token) external view returns (bool) {
        return registry[_token];
    }
}

