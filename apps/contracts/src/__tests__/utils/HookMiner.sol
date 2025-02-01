// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Hooks} from '@v4-core/libraries/Hooks.sol';
import {IHooks} from '@v4-core/interfaces/IHooks.sol';

library HookMiner {
  // Computes the required flags from hook permissions
  function computeRequiredFlags(
    Hooks.Permissions memory permissions
  ) internal pure returns (uint160) {
    uint160 flags;
    if (permissions.beforeInitialize) flags |= Hooks.BEFORE_INITIALIZE_FLAG;
    if (permissions.afterInitialize) flags |= Hooks.AFTER_INITIALIZE_FLAG;
    if (permissions.beforeAddLiquidity) flags |= Hooks.BEFORE_ADD_LIQUIDITY_FLAG;
    if (permissions.afterAddLiquidity) flags |= Hooks.AFTER_ADD_LIQUIDITY_FLAG;
    if (permissions.beforeRemoveLiquidity) flags |= Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG;
    if (permissions.afterRemoveLiquidity) flags |= Hooks.AFTER_REMOVE_LIQUIDITY_FLAG;
    if (permissions.beforeSwap) flags |= Hooks.BEFORE_SWAP_FLAG;
    if (permissions.afterSwap) flags |= Hooks.AFTER_SWAP_FLAG;
    if (permissions.beforeDonate) flags |= Hooks.BEFORE_DONATE_FLAG;
    if (permissions.afterDonate) flags |= Hooks.AFTER_DONATE_FLAG;
    if (permissions.beforeSwapReturnDelta) flags |= Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG;
    if (permissions.afterSwapReturnDelta) flags |= Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG;
    if (permissions.afterAddLiquidityReturnDelta)
      flags |= Hooks.AFTER_ADD_LIQUIDITY_RETURNS_DELTA_FLAG;
    if (permissions.afterRemoveLiquidityReturnDelta)
      flags |= Hooks.AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG;
    return flags;
  }

  // Returns the address of the hook with the correct flags
  function deploy(
    bytes memory creationCode,
    bytes memory constructorArgs,
    Hooks.Permissions memory permissions
  ) internal returns (address hook) {
    uint160 flags = computeRequiredFlags(permissions);
    bytes memory bytecode = abi.encodePacked(creationCode, constructorArgs);
    uint256 salt = 0;

    while (true) {
      bytes32 salt_bytes = bytes32(salt);
      hook = _getAddress(bytecode, salt_bytes);

      // Check if the last bits of the address match the required flags
      if ((uint160(hook) & Hooks.ALL_HOOK_MASK) == flags) {
        hook = _deploy(bytecode, salt_bytes);
        break;
      }
      salt++;
    }
  }

  // Internal helper to get address before deployment
  function _getAddress(bytes memory bytecode, bytes32 salt) internal view returns (address) {
    bytes32 hash = keccak256(
      abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode))
    );
    return address(uint160(uint256(hash)));
  }

  // Internal helper to deploy with create2
  function _deploy(bytes memory bytecode, bytes32 salt) internal returns (address addr) {
    assembly {
      addr := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
    }
    require(addr != address(0), 'Deploy failed');
  }
}
