// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {IBondIssuer} from "../../src/interfaces/IBondIssuer.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract MockIssuer is ERC721Enumerable, IBondIssuer {

    IERC20 public underlyingToken; 

    mapping(uint256 => BondInfo) public bonds;
    uint256 public bondCount;

    constructor(address _underlyingToken) ERC721("Bond", "BOND") {
        underlyingToken = IERC20(_underlyingToken);
    }

    function createBond(uint256 referenceId, uint256 nominalValue, uint256 duration) external returns (uint256) {
        uint256 tokenId = bondCount + 1;
        bonds[tokenId] = BondInfo({
            referenceId: referenceId,
            nominalValue: nominalValue,
            expires: block.timestamp + duration,
            created: block.timestamp,
            claimed: false
        });
        underlyingToken.transferFrom(msg.sender, address(this), nominalValue);
        _safeMint(msg.sender, tokenId);
        return tokenId;
    }

    function redeemBond(uint256 tokenId) external {
        BondInfo memory bond = bonds[tokenId];
        require(bond.expires > block.timestamp, "Bond not matured");
        require(!bond.claimed, "Bond already redeemed");
        underlyingToken.transfer(msg.sender, bond.nominalValue);
        bonds[tokenId].claimed = true;
    }

    function getBondInfo(uint256 tokenId) external view returns (BondInfo memory) {
        return bonds[tokenId];
    }
}
