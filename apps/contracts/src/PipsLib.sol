// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

library PipsLib {

    uint256 public constant OneHundred = 100_0000;

    function percentToPips(uint256 percent) public pure returns (uint256) {
        return percent * 10000;
    }

    function bpsToPips(uint256 x) public pure returns (uint256) {
        return x * 100;
    }
}
