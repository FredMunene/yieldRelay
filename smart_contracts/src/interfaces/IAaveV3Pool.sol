// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IAaveV3Pool
/// @notice Minimal subset of the Aave v3 Pool interface needed by Octant Mini strategy contracts.
/// @dev Reference: https://docs.aave.com/developers/core-contracts/pool
interface IAaveV3Pool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    function withdraw(address asset, uint256 amount, address to) external returns (uint256);

    function getReserveData(
        address asset
    )
        external
        view
        returns (
            uint256 configuration,
            uint128 liquidityIndex,
            uint128 currentLiquidityRate,
            uint128 variableBorrowIndex,
            uint128 currentVariableBorrowRate,
            uint128 currentStableBorrowRate,
            uint40 lastUpdateTimestamp,
            address aTokenAddress,
            address stableDebtTokenAddress,
            address variableDebtTokenAddress,
            address interestRateStrategyAddress,
            uint8 id
        );

    function getReserveNormalizedIncome(address asset) external view returns (uint256);
}
