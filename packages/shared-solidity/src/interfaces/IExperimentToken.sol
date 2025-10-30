// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IExperimentToken {
    struct BatchMintRequest {
        address to;
        uint256 amount;
    }

    function batchMint(BatchMintRequest[] calldata mints, string calldata reason) external;

    function transfer(address to, uint256 amount) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function symbol() external view returns (string memory);
}
