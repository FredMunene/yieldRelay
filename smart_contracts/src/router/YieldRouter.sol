// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {BeneficiaryRegistry} from "../registry/BeneficiaryRegistry.sol";

/// @title YieldRouter
/// @notice Records claimable yield per beneficiary and pays out on claim.
contract YieldRouter is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable asset;
    BeneficiaryRegistry public immutable registry;
    address public vault;

    mapping(address => uint256) public claimable;

    event VaultSet(address indexed vault);
    event YieldCredited(address indexed beneficiary, uint256 amount);
    event YieldClaimed(address indexed beneficiary, uint256 amount, address indexed to);

    error InvalidAddress();
    error UnauthorizedCaller();
    error VaultAlreadySet();
    error NotEligible();
    error ZeroAmount();

    constructor(IERC20 asset_, BeneficiaryRegistry registry_, address admin) {
        if (address(asset_) == address(0) || address(registry_) == address(0) || admin == address(0)) {
            revert InvalidAddress();
        }
        asset = asset_;
        registry = registry_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function setVault(address vault_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (vault_ == address(0)) revert InvalidAddress();
        if (vault != address(0)) revert VaultAlreadySet();
        vault = vault_;
        emit VaultSet(vault_);
    }

    function creditYield(address beneficiary, uint256 amount) external {
        if (msg.sender != vault) revert UnauthorizedCaller();
        if (amount == 0) revert ZeroAmount();
        if (!registry.isEligible(beneficiary)) revert NotEligible();
        claimable[beneficiary] += amount;
        emit YieldCredited(beneficiary, amount);
    }

    function claimYield() external nonReentrant {
        _claim(msg.sender, msg.sender);
    }

    function claimYieldTo(address to) external nonReentrant {
        _claim(msg.sender, to);
    }

    function _claim(address beneficiary, address to) internal {
        if (!registry.isEligible(beneficiary)) revert NotEligible();
        uint256 amount = claimable[beneficiary];
        if (amount == 0) revert ZeroAmount();
        claimable[beneficiary] = 0;
        asset.safeTransfer(to, amount);
        emit YieldClaimed(beneficiary, amount, to);
    }
}
