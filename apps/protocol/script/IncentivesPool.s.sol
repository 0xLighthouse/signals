// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/console.sol";
import {SharedScriptBase} from "@shared/SharedScriptBase.sol";
import {IncentivesPool} from "../src/IncentivesPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * Deployment and management script for IncentivesPool
 *
 * Usage:
 * Deploy:
 *   forge script script/IncentivesPool.s.sol --sig "deploy(string,address)" base-sepolia <rewardToken> --broadcast
 *
 * Update Balance:
 *   forge script script/IncentivesPool.s.sol --sig "updateBalance(string,address,uint256)" base-sepolia <pool> <newBalance> --broadcast
 *
 * Approve Board:
 *   forge script script/IncentivesPool.s.sol --sig "approveBoard(string,address,address,uint256,uint256)" base-sepolia <pool> <board> <budget> <perInitiative> --broadcast
 */
contract IncentivesPoolScript is SharedScriptBase {
    /**
     * Deploy a new IncentivesPool
     * @param network The network to deploy to (base-sepolia or anvil)
     * @param rewardToken The ERC20 token address to use for rewards
     */
    function deploy(string memory network, address rewardToken) external {
        if (!isSupportedNetwork(network)) {
            revert(string.concat("Unsupported network [", network, "] provided"));
        }

        (uint256 deployerPrivateKey, address deployerAddress) = _loadPrivateKey(network, "deployer");

        vm.startBroadcast(deployerPrivateKey);
        IncentivesPool pool = new IncentivesPool(rewardToken);
        vm.stopBroadcast();

        console.log("=== IncentivesPool Deployment ===");
        console.log("Deployer:", deployerAddress);
        console.log("Reward Token:", pool.REWARD_TOKEN());
        console.log("Pool Owner:", pool.owner());
        console.log("Pool Address:", address(pool));

        console.log("ScriptOutput:", address(pool));
    }

    /**
     * Fund the incentives pool
     * @param network The network to interact with
     * @param tokenAddress The token contract address
     * @param from The address to transfer tokens from
     * @param to The address to transfer tokens to
     * @param amount The amount of tokens to fund the pool with
     */
    function transferTokens(
        string memory network,
        address tokenAddress,
        string memory from,
        address to,
        uint256 amount
    ) external {
        if (!isSupportedNetwork(network)) {
            revert(string.concat("Unsupported network [", network, "] provided"));
        }

        (uint256 fromPrivateKey,) = _loadPrivateKey(network, from);
        vm.startBroadcast(fromPrivateKey);
        IERC20(tokenAddress).transfer(to, amount);
        vm.stopBroadcast();

        console.log("=== Incentives Pool Funded ===");
        console.log("Token Address:", tokenAddress);
        console.log("From Label:", from);
        console.log("Recipient:", to);
        console.log("Amount:", amount);

        console.log("ScriptOutput:", amount);
    }

    /**
     * Update the available rewards balance in the pool
     * Used when tokens are transferred directly to the pool contract
     * @param network The network to interact with
     * @param poolAddress The IncentivesPool contract address
     * @param newBalance The new available rewards balance
     */
    function updateBalance(string memory network, address poolAddress, uint256 newBalance)
        external
    {
        if (!isSupportedNetwork(network)) {
            revert(string.concat("Unsupported network [", network, "] provided"));
        }

        (uint256 deployerPrivateKey, address deployerAddress) = _loadPrivateKey(network, "deployer");
        IncentivesPool pool = IncentivesPool(poolAddress);

        uint256 oldBalance = pool.availableRewards();

        vm.startBroadcast(deployerPrivateKey);
        pool.updateAvailableRewards(newBalance);
        vm.stopBroadcast();

        console.log("=== Available Rewards Updated ===");
        console.log("Pool Address:", address(pool));
        console.log("Updated By:", deployerAddress);
        console.log("Old Balance:", oldBalance);
        console.log("New Balance:", newBalance);

        console.log("ScriptOutput:", newBalance);
    }

    /**
     * Approve a board to use the incentives pool
     * @param network The network to interact with
     * @param poolAddress The IncentivesPool contract address
     * @param boardAddress The board contract address to approve
     * @param boardBudget The maximum budget allocated to this board
     * @param rewardPerInitiative The maximum reward amount per initiative
     */
    function approveBoard(
        string memory network,
        address poolAddress,
        address boardAddress,
        uint256 boardBudget,
        uint256 rewardPerInitiative
    ) external {
        if (!isSupportedNetwork(network)) {
            revert(string.concat("Unsupported network [", network, "] provided"));
        }

        (uint256 deployerPrivateKey, address deployerAddress) = _loadPrivateKey(network, "deployer");
        IncentivesPool pool = IncentivesPool(poolAddress);

        vm.startBroadcast(deployerPrivateKey);
        pool.approveBoard(boardAddress, boardBudget, rewardPerInitiative);
        vm.stopBroadcast();

        console.log("=== Board Approved ===");
        console.log("Pool Address:", address(pool));
        console.log("Approved By:", deployerAddress);
        console.log("Board Address:", boardAddress);
        console.log("Board Budget:", boardBudget);
        console.log("Reward Per Initiative:", rewardPerInitiative);
        console.log("Is Approved:", pool.isBoardApproved(boardAddress));

        console.log("ScriptOutput:", boardAddress);
    }
}
