pragma solidity ^0.8.24;

interface IVotes {
    function getPastVotes(address account, uint256 blockNumber) external view returns (uint256);
}
