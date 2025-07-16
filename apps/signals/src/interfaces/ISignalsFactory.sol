// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IIncentives} from "./IIncentives.sol";
import {IBondIssuer} from "@bondhook/interfaces/IBondIssuer.sol";

interface ISignalsFactory {
    struct FactoryDeployment {
        address owner;
        address underlyingToken;
        uint256 proposalThreshold;
        uint256 acceptanceThreshold;
        uint256 maxLockIntervals;
        uint256 proposalCap;
        uint256 lockInterval;
        uint256 decayCurveType;
        uint256[] decayCurveParameters;
    }

    function create(ISignalsFactory.FactoryDeployment calldata config) external payable returns (address);
}
