// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {BondHook, BondHookOptions} from "../src/BondHook.sol";
import {BondHookLibrary} from "../src/interfaces/IBondHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {ExampleLinearPricing} from "../src/pricing/ExampleLinearPricing.sol";
import {IBondPricing} from "../src/interfaces/IBondPricing.sol";
import {HookMiner} from "v4-periphery/utils/HookMiner.sol";

/**
 * Deploys an instance of the Uniswap V4 Pool Manager and the Bond Hook.
 */
contract DeployManagerAndHook is Script, Deployers {
    function run() external {
        // Load the private key from the environment
        uint256 deployerPrivateKey = vm.envUint("LOCAL_DEPLOYER_PRIVATE_KEY");
        address _deployer = vm.addr(deployerPrivateKey);
        address bondIssuer = vm.envAddress("BOND_ISSUER");

        // Log the deployer addresses
        console.log("----- Accounts -----");
        console.log("Deployer:", _deployer);

        // 1. Deploy the manager and routers
        deployFreshManagerAndRouters();

        // 2. Deploy pricing contract
        vm.startBroadcast(_deployer);
        IBondPricing pricing = new ExampleLinearPricing(10_0000, 10_0000); // 10% fees on each side
        vm.stopBroadcast();

        console.log("Pricing contract", address(pricing));

        // 3. Compute the salt and hook address
        address CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
        (address hookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER,
            BondHookLibrary.flags,
            type(BondHook).creationCode,
            abi.encode(IPoolManager(manager), address(bondIssuer), address(pricing))
        );

        console.log("Flags", address(BondHookLibrary.flags));
        console.log("Hook address", hookAddress);
        console.log("Salt", uint256(salt));

        // 4. Deploy the hook
        vm.startBroadcast(_deployer);
        BondHook hook = new BondHook{salt: salt}(
            BondHookOptions({
                poolManager: IPoolManager(manager),
                bondIssuer: address(bondIssuer),
                bondPricing: address(pricing),
                ownerFeeAsPips: 1000,
                profitShareRatioAsPips: 1000,
                swapFeeDiscountAsPips: 1000
            })
        );
        console.log("BondHookContract", address(hook));
        vm.stopBroadcast();
    }
}
