// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {BondHook} from "../src/BondHook.sol";
import {BondHookLibrary} from "../src/interfaces/IBondHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {ExampleLinearPricing} from "../src/pricing/ExampleLinearPricing.sol";
import {IBondPricing} from "../src/interfaces/IBondPricing.sol";
import {HookMiner} from "v4-periphery/utils/HookMiner.sol";
import {IBondIssuer} from "../src/interfaces/IBondIssuer.sol";
import {BondHookHarness} from "../test/utils/BondHookHarness.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

/**
 * Deploys an instance of the Uniswap V4 Pool Manager and the Bond Hook.
 */
contract DeployManagerAndHook is Script, BondHookHarness {
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
        console.log("PoolManager", address(manager));

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
        BondHook hook = new BondHook{salt: salt}(IPoolManager(manager), address(bondIssuer), address(pricing));
        console.log("BondHookContract", address(hook));
        vm.stopBroadcast();

        // 5. Create pools
        // N.B Not worth moving this to a separate script as
        // "createPool" requires a manager to be available in scope
        IBondIssuer issuer = IBondIssuer(bondIssuer);
        address usdc = address(0xa513E6E4b8f2a923D98304ec87F64353C4D5C853);
        address underlyingToken = issuer.getUnderlyingToken();

        vm.startBroadcast(_deployer);
        createPool(MockERC20(usdc), MockERC20(underlyingToken), IHooks(hook));
        console.log("- USDC/%s pool created", MockERC20(underlyingToken).symbol());
        vm.stopBroadcast();
    }
}
