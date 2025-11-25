// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Id} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";

struct MarketDataExt {
    uint256 totalSupplyAssets;
    uint256 totalSupplyShares;
    uint256 totalBorrowAssets;
    uint256 totalBorrowShares;
    uint256 fee;
    uint256 utilization;
    uint256 supplyRate;
    uint256 borrowRate;
}

struct PositionExt {
    uint256 suppliedShares;
    uint256 suppliedAssets;
    uint256 borrowedShares;
    uint256 borrowedAssets;
    uint256 collateral;
    uint256 collateralValue;
    uint256 ltv;
    uint256 healthFactor;
}

interface IMorphoReader {
    function getMarketData(Id id) external view returns (MarketDataExt memory);

    function getPosition(
        Id id,
        address user
    ) external view returns (PositionExt memory);
}