// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {PausableTokenFactory, PausableToken} from "../src/PausableTokenFactory.sol";

contract PausableTokenFactoryTest is Test {
    PausableTokenFactory private factory;

    function setUp() public {
        factory = new PausableTokenFactory();
    }

    function test_DeployInitialSupplyAndOwner() public {
        address owner = makeAddr("owner");
        uint256 supply = 1_000 ether;

        address tokenAddress = factory.deployToken("Signal Token", "SIG", supply, owner);
        PausableToken token = PausableToken(tokenAddress);

        assertEq(token.name(), "Signal Token");
        assertEq(token.symbol(), "SIG");
        assertEq(token.totalSupply(), supply);
        assertEq(token.balanceOf(owner), supply);
        assertEq(token.owner(), owner);
    }

    function test_DeployDefaultsOwnerToCaller() public {
        uint256 supply = 100 ether;

        address tokenAddress = factory.deployToken("Signal Token", "SIG", supply, address(0));
        PausableToken token = PausableToken(tokenAddress);

        assertEq(token.owner(), address(this));
    }

    function test_PauseBlocksTransfers() public {
        address owner = makeAddr("owner");
        address recipient = makeAddr("recipient");
        uint256 supply = 100 ether;

        PausableToken token = PausableToken(factory.deployToken("Signal Token", "SIG", supply, owner));

        vm.prank(owner);
        bool initialTransfer = token.transfer(recipient, 10 ether);
        assertTrue(initialTransfer);
        assertEq(token.balanceOf(recipient), 10 ether);

        vm.prank(owner);
        token.pause();

        vm.startPrank(owner);
        try token.transfer(recipient, 1 ether) returns (bool pausedTransfer) {
            // silence unused warning if the unexpected path executes
            pausedTransfer;
            fail("transfer should revert while paused");
        } catch (bytes memory revertData) {
            assertEq(revertData, abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        }
        vm.stopPrank();

        vm.prank(owner);
        token.unpause();

        vm.prank(owner);
        bool finalTransfer = token.transfer(recipient, 1 ether);
        assertTrue(finalTransfer);
        assertEq(token.balanceOf(recipient), 11 ether);
    }
}
