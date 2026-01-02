// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {MockAToken} from "./MockAToken.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";

contract MockAavePool {
    using SafeERC20 for IERC20;

    IERC20 public immutable asset;
    MockAToken public immutable aToken;

    constructor(IERC20 asset_, MockAToken aToken_) {
        asset = asset_;
        aToken = aToken_;
    }

    function supply(address asset_, uint256 amount, address onBehalfOf, uint16) external {
        require(asset_ == address(asset), "asset mismatch");
        asset.safeTransferFrom(msg.sender, address(this), amount);
        aToken.mintTo(onBehalfOf, amount);
    }

    function withdraw(address asset_, uint256 amount, address to) external returns (uint256) {
        require(asset_ == address(asset), "asset mismatch");
        if (amount == type(uint256).max) {
            amount = aToken.balanceOf(msg.sender);
        }

        aToken.burnFrom(msg.sender, amount);
        asset.safeTransfer(to, amount);
        return amount;
    }

    function getReserveData(address)
        external
        view
        returns (
            uint256,
            uint128,
            uint128,
            uint128,
            uint128,
            uint128,
            uint40,
            address,
            address,
            address,
            address,
            uint8
        )
    {
        return (0, 0, 0, 0, 0, 0, 0, address(aToken), address(0), address(0), address(0), 0);
    }

    function getReserveNormalizedIncome(address) external pure returns (uint256) {
        return 1e27;
    }

    function seed(uint256 amount) external {
        MockERC20(address(asset)).mint(address(this), amount);
    }
}
