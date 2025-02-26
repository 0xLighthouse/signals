// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

struct BondInfo {
  uint256 referenceId;
  uint256 nominalValue;
  uint256 expires;
  uint256 created;
  bool claimed;
}

interface IBondIssuer {
    function getBondInfo(uint256 tokenId) external view returns (BondInfo memory);
}