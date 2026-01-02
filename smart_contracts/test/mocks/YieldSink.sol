// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract YieldSink {
    IERC20 public immutable asset;

    constructor(IERC20 asset_) {
        asset = asset_;
    }

    function balance() external view returns (uint256) {
        return asset.balanceOf(address(this));
    }
}
