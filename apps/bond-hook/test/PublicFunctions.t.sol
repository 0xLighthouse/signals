// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "v4-periphery/lens/StateView.sol"; // import for abi generation

import {BondHookHarness} from "./utils/BondHookHarness.sol";
import {LiquidityData, DesiredCurrency} from "../src/BondHook.sol";
import {IBondIssuer} from "../src/interfaces/IBondIssuer.sol";
import {Constants} from "v4-core-test/utils/Constants.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";

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

    function test_getUnderlyingAmountForLiquidity() public {
        deployHookWithFeesAndPools(0, 0, 0, 0, SQRT_PRICE_1_1);
        uint256 daiBalanceBefore = _dai.balanceOf(address(_liquidityProvider));
        uint256 tokenBalanceBefore = _token.balanceOf(address(_liquidityProvider));
        modifyLiquidityFromProvider(poolA, 100 ether);
        uint256 daiBalanceAfter = _dai.balanceOf(address(_liquidityProvider));
        uint256 tokenBalanceAfter = _token.balanceOf(address(_liquidityProvider));
        int256 amount = bondhook.getUnderlyingAmountForLiquidity(poolA.toId(), 100 ether);
        assertApproxEqAbs(amount, 200 ether, 1000, "Incorrect liquidity as underlying token");
    }
}
