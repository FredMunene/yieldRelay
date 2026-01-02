// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title IAToken
/// @notice Minimal subset of the Aave aToken interface leveraged by the donating strategy.
/// @dev Reference: https://docs.aave.com/developers/core-contracts/atoken
interface IAToken is IERC20 {
    function RESERVE_TREASURY_ADDRESS() external view returns (address);

    function UNDERLYING_ASSET_ADDRESS() external view returns (address);

    function POOL() external view returns (address);

    function scaledBalanceOf(address user) external view returns (uint256);
}
