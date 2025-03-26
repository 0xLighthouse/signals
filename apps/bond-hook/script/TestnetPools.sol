// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {SortTokens} from "@uniswap/v4-core/test/utils/SortTokens.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {Constants} from "@uniswap/v4-core/test/utils/Constants.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {BondHook} from "../src/BondHook.sol";
import {IBondHookLegacy} from "../src/interfaces/IBondHook.sol";

/**
 * Initializes some testnet pools with our hook
 *
 * Notes:
 *  - https://github.com/Uniswap/v4-periphery/tree/main/broadcast
 *
 * Known deployments
 *  - Arbitrum One
 *    - V4 Pool Manager: 0xfb3e0c6f74eb1a21cc1da29aec80d2dfe6c9a317
 */
contract TestnetPools is Script {
    function run() external {
        // Load the private key from the environment
        uint256 deployerPrivateKey = vm.envUint("TESTNET_DEPLOYER_PRIVATE_KEY");
        address _deployer = vm.addr(deployerPrivateKey);

        IPoolManager manager = IPoolManager(vm.envAddress("TESTNET_POOL_MANAGER"));
        IHooks hooks = IHooks(vm.envAddress("TESTNET_HOOK"));
        IBondHookLegacy bondHook = IBondHookLegacy(vm.envAddress("TESTNET_HOOK"));

        console.log("BondHook:", address(bondHook));
        console.log("Underlying token:", Currency.unwrap(bondHook.bondToken()));

        // Log the deployer addresses
        console.log("----- Accounts -----");
        console.log("Deployer:", _deployer);
        console.log("Manager:", address(manager));
        console.log("Hooks:", address(hooks));

        //  TokenContract 0x75e8927FFabD709D7e55Ed44C7a19166A0B215A7
        // USDC contract 0x2ed7De542Ce7377Bca3f3500dA4e7aF830889635
        MockERC20 token = MockERC20(0x75e8927FFabD709D7e55Ed44C7a19166A0B215A7); // 1e18 of precision
        MockERC20 usdc = MockERC20(0x2ed7De542Ce7377Bca3f3500dA4e7aF830889635); // 1e6 of precision
        (Currency _currency0, Currency _currency1) = SortTokens.sort(token, usdc);

        // Record units of precision for the two currencies
        uint256 units0;
        uint256 units1;
        if (_currency0 == Currency.wrap(address(token))) {
            units0 = 1e18;
            units1 = 1e6;
        } else {
            units0 = 1e6;
            units1 = 1e18;
        }

        // Find price for 1:1 ratio
        uint160 sqrtPriceX96 = calculateSqrtPriceX96(units1, units0);

        uint24 dynamicFeeFlag = 0x800000;
        PoolKey memory _key = PoolKey(_currency0, _currency1, dynamicFeeFlag, int24(60), hooks);
        // PoolId id = _key.toId();
        vm.startBroadcast(_deployer);
        manager.initialize(_key, sqrtPriceX96);
        console.log("Deployed pool...");
    }

    function calculateSqrtPriceX96(uint256 price1, uint256 price0) public pure returns (uint160) {
        uint256 ratio = (price1 << 192) / price0;
        uint256 sqrtRatio = babylonianSqrt(ratio);
        return uint160(sqrtRatio);
    }

    function babylonianSqrt(uint256 y) public pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
