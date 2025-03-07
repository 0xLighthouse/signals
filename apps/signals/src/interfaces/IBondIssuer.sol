// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IBondIssuer {
    /**
     * @notice Struct to store bond information
     *
     * @param referenceId The reference ID of the bond
     * @param nominalValue The nominal value of the bond
     * @param expires The expiration date of the bond
     * @param created The creation date of the bond
     * @param claimed Whether the underlying assets have been claimed from a matured bond
     */ 
    struct BondInfo {
      uint256 referenceId;
      uint256 nominalValue;
      uint256 expires;
      uint256 created;
      bool claimed;
    }
   
    /**
     * @notice Get the bond information for a given token ID
     * @param tokenId The ID of the token to get the bond information for
     * @return bondInfo The bond information for the given token ID
     */
    function getBondInfo(uint256 tokenId) external view returns (BondInfo memory);
}