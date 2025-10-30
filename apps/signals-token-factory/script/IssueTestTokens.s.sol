// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/console.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {SharedScriptBase} from "@shared/SharedScriptBase.sol";
import {IExperimentToken} from "@shared/interfaces/IExperimentToken.sol";

/**
 * This script is used to create a Signals board with some default parameters for the Edge Experiment
 */
contract IssueTestTokens is SharedScriptBase {
    IExperimentToken _token;

    uint256 private constant TEST_TOKEN_AMOUNT = 20_000 ether;

    /**
     * @param network The network to deploy the contracts to
     * @param tokenOwner The owner of the token
     * @param tokenAddress The address of the token
     * @param tokenRecipients The names of the token recipients
     */
    function run(string memory network, string memory tokenOwner, address tokenAddress, string[] memory tokenRecipients)
        external
    {
        if (!isSupportedNetwork(network)) {
            revert(string.concat("Unsupported network [", network, "] provided"));
        }
        _token = IExperimentToken(tokenAddress);

        (uint256 deployerPrivateKey,) = _loadPrivateKey(network, tokenOwner);

        console.log("=== Issue Test Tokens ===");

        uint256 totalAmount = 0;
        IExperimentToken.BatchMintRequest[] memory mints =
            new IExperimentToken.BatchMintRequest[](tokenRecipients.length);

        for (uint256 i = 0; i < tokenRecipients.length; i++) {
            (, address recipientAddress) = _loadPrivateKey(network, tokenRecipients[i]);
            uint256 amount = TEST_TOKEN_AMOUNT * (i + 1);
            totalAmount += amount;
            mints[i] = IExperimentToken.BatchMintRequest({to: recipientAddress, amount: amount});
            console.log(string.concat(tokenRecipients[i], ": ", Strings.toString(amount)));
        }
        vm.startBroadcast(deployerPrivateKey);
        _token.batchMint(mints, "Test token distribution");
        vm.stopBroadcast();

        console.log("ScriptOutput:", Strings.toString(totalAmount / 1 ether), " tokens issued");
    }
}
