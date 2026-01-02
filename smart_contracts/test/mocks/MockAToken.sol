// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IAToken} from "../../src/interfaces/IAToken.sol";

contract MockAToken is ERC20, IAToken {
    address public pool;
    address public immutable owner;
    address public immutable underlying;

    constructor(address underlying_) ERC20("Mock AToken", "maTOKEN") {
        owner = msg.sender;
        underlying = underlying_;
    }

    modifier onlyPool() {
        require(msg.sender == pool, "not pool");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    function setPool(address pool_) external onlyOwner {
        pool = pool_;
    }

    function mintTo(address to, uint256 amount) external onlyPool {
        _mint(to, amount);
    }

    function burnFrom(address from, uint256 amount) external onlyPool {
        _burn(from, amount);
    }

    function forceMint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function forceBurn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }

    // Interface helpers
    function RESERVE_TREASURY_ADDRESS() external view returns (address) {
        return address(0);
    }

    function UNDERLYING_ASSET_ADDRESS() external view returns (address) {
        return underlying;
    }

    function POOL() external view returns (address) {
        return pool;
    }

    function scaledBalanceOf(address user) external view returns (uint256) {
        return balanceOf(user);
    }
}
