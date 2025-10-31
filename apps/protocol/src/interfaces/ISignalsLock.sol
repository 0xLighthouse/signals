// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

/**
 * @title ISignalsLock
 * @notice Interface for querying lock position data represented as ERC721 tokens
 * @dev This interface provides a standard way to access lock details for positions
 */
interface ISignalsLock {
    /**
     * @notice Standardized lock data structure
     * @dev Provides essential information about a lock position
     *
     * @param referenceId The ID of the initiative this lock supports
     * @param nominalValue The amount of tokens locked
     * @param expires Timestamp when the lock expires
     * @param created Timestamp when the lock was created
     * @param claimed Whether the lock has been redeemed
     */
    struct LockData {
        uint256 referenceId;
        uint256 nominalValue;
        uint256 expires;
        uint256 created;
        bool claimed;
    }

    /**
     * @notice Get standardized lock data for a token ID
     * @param tokenId The NFT token ID representing the lock position
     * @return LockData struct containing lock details
     */
    function getLockData(uint256 tokenId) external view returns (LockData memory);

    /**
     * @notice Get the address of the underlying ERC20 token
     * @return Address of the token used for locks
     */
    function underlyingToken() external view returns (address);
}
