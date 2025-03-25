// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {BondHookHarness} from "./utils/BondHookHarness.sol";
import {LiquidityData, DesiredCurrency} from "../src/BondHook.sol";
import {IBondIssuer} from "../src/interfaces/IBondIssuer.sol";

contract PublicFunctionsTest is Test, BondHookHarness {
    function setUp() public {
        deployFreshManagerAndRouters();
        dealMockTokens();
    }

    function test_previewPercentOfTotalSharesAsPips() public {
        deployHookAndPools();
        modifyLiquidityFromProvider(poolA, 75 ether);
        uint256 twentyfivepercent = bondhook.previewPercentOfTotalSharesAsPips(poolA.toId(), 25 ether);
        assertEq(twentyfivepercent, 25_0000, "Incorrect percent of total shares (anonymous)");

        vm.startPrank(_alice);
        _token.approve(address(bondhook), type(uint256).max);
        _dai.approve(address(bondhook), type(uint256).max);
        bondhook.modifyLiquidity(
            LiquidityData({
                poolKey: poolA,
                liquidityDelta: 50 ether,
                desiredCurrency: DesiredCurrency.Mixed,
                swapPriceLimit: 0
            })
        );
        uint256 twentyfivepercentagain = bondhook.previewPercentOfTotalSharesAsPips(poolA.toId(), -25 ether);
        assertEq(twentyfivepercentagain, 25_0000, "Incorrect percent of total shares (alice)");

        uint256 zeropercent = bondhook.previewPercentOfTotalSharesAsPips(poolA.toId(), -50 ether);
        assertEq(zeropercent, 0, "Incorrect percent of total shares (alice removing all liquidity)");
        vm.stopPrank();
    }

    function test_getPoolPrice() public {
        deployHookWithFeesAndPools(0, 0, 0, 0, SQRT_PRICE_1_4);
        uint256 price = bondhook.getPoolPrice(poolA.toId());
        assertEq(price, 25 ether / 100, "Incorrect price");
    }

    function test_getPoolLiquidityAsUnderlying() public {
        deployHookWithFeesAndPools(0, 0, 0, 0, SQRT_PRICE_1_4);
        modifyLiquidityFromProvider(poolA, 100 ether);
        uint256 liquidity = bondhook.getPoolLiquidityAsUnderlying(poolA.toId());
        assertApproxEqAbs(liquidity, 100 ether, 1000, "Incorrect liquidity as underlying token");
    }

    function test_getBondInfo() public {
        deployHookAndPools();
        uint256 bondId = aliceCreateBondAndWaits(50 ether, 50);

        IBondIssuer.BondInfo memory bondInfo = bondhook.getBondInfo(bondId);
        assertEq(bondInfo.referenceId, 1, "Incorrect bond reference id");
        assertEq(bondInfo.nominalValue, 50 ether, "Incorrect bond nominal value");
    }
}
