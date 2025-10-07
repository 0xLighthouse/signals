// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

interface IBondIssuer {
    struct BondInfo {
        uint256 referenceId;
        uint256 nominalValue;
        uint256 expires;
        uint256 created;
        bool claimed;
    }

    function getBondInfo(uint256 tokenId) external view returns (BondInfo memory);
    function getUnderlyingToken() external view returns (address);
}
