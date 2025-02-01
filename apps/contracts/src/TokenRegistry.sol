// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.26;

import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/**
 * @title TokenRegistry
 * @author 1a35e1.eth <arnold@lighthouse.cx>
 * @notice A simple registry for determining which tokens can be used for Incentives.
 */
contract TokenRegistry is AccessControl {
  mapping(address => bool) public registry;

  bytes32 public constant TOKEN_MANAGER_ROLE = keccak256('TOKEN_MANAGER_ROLE');

  event TokenAdded(address indexed token);
  event TokenRemoved(address indexed token);

  constructor() {
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setupRole(TOKEN_MANAGER_ROLE, msg.sender);
  }

  function allow(address _token) external onlyRole(TOKEN_MANAGER_ROLE) {
    require(_token != address(0), 'Invalid token address');
    require(!registry[_token], 'Token already registered');
    require(_supportsERC20(_token), 'Token is not ERC20');
    registry[_token] = true;
    emit TokenAdded(_token);
  }

  function deny(address _token) external onlyRole(TOKEN_MANAGER_ROLE) {
    require(_token != address(0), 'Invalid token address');
    require(registry[_token], 'Token not approved');
    registry[_token] = false;
    emit TokenRemoved(_token);
  }

  function isAllowed(address _token) external view returns (bool) {
    return registry[_token];
  }

  function _supportsERC20(address _token) private view returns (bool) {
    (bool hasTotalSupply, ) = _token.staticcall(
      abi.encodeWithSelector(bytes4(keccak256('totalSupply()')))
    );
    (bool hasDecimals, ) = _token.staticcall(
      abi.encodeWithSelector(bytes4(keccak256('decimals()')))
    );
    (bool hasBalanceOf, ) = _token.staticcall(
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(this))
    );
    return hasTotalSupply && hasDecimals && hasBalanceOf;
  }
}
