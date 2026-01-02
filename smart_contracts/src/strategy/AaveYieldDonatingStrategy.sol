// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {OctantMiniVault} from "../vault/OctantMiniVault.sol";
import {IAaveV3Pool} from "../interfaces/IAaveV3Pool.sol";
import {IAToken} from "../interfaces/IAToken.sol";

/// @title AaveYieldDonatingStrategy
/// @notice Deploys funds into Aave v3 and reports yield back to the Octant Mini vault.
contract AaveYieldDonatingStrategy is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");

    OctantMiniVault public immutable vault;
    IERC20 public immutable asset;
    IAToken public immutable aToken;
    IAaveV3Pool public immutable pool;

    uint256 public principalBalance;

    event FundsDeployed(uint256 indexed amount);
    event FundsFreed(uint256 indexed amount);
    event Harvested(int256 indexed pnl);
    event EmergencyWithdrawn(uint256 indexed amount, address indexed recipient);

    error InvalidAddress();
    error ZeroAmount();
    error InsufficientPrincipal();
    error WithdrawalFailed();
    error InsufficientIdle();

    constructor(
        OctantMiniVault vault_,
        IERC20 asset_,
        IAToken aToken_,
        IAaveV3Pool pool_,
        address admin
    ) {
        if (
            address(vault_) == address(0) || address(asset_) == address(0)
                || address(aToken_) == address(0) || address(pool_) == address(0) || admin == address(0)
        ) revert InvalidAddress();

        vault = vault_;
        asset = asset_;
        aToken = aToken_;
        pool = pool_;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(KEEPER_ROLE, admin);

        asset_.safeApprove(address(pool_), type(uint256).max);
    }

    function deployFunds(uint256 amount) external onlyRole(KEEPER_ROLE) nonReentrant {
        if (amount == 0) revert ZeroAmount();
        uint256 idle = asset.balanceOf(address(this));
        if (amount > idle) revert InsufficientIdle();

        pool.supply(address(asset), amount, address(this), 0);

        principalBalance += amount;
        emit FundsDeployed(amount);
    }

    function freeFunds(uint256 amount) external onlyRole(KEEPER_ROLE) nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (amount > principalBalance) revert InsufficientPrincipal();

        uint256 withdrawn = pool.withdraw(address(asset), amount, address(this));
        if (withdrawn < amount) revert WithdrawalFailed();

        principalBalance -= amount;
        asset.safeTransfer(address(vault), withdrawn);
        emit FundsFreed(withdrawn);
    }

    function harvestAndReport() external onlyRole(KEEPER_ROLE) nonReentrant {
        uint256 currentValue = aToken.balanceOf(address(this));

        if (currentValue >= principalBalance) {
            uint256 profit = currentValue - principalBalance;
            if (profit > 0) {
                pool.withdraw(address(asset), profit, address(this));
                asset.safeTransfer(address(vault), profit);
                vault.report(profit, 0);
                emit Harvested(int256(profit));
            }
        } else {
            uint256 loss = principalBalance - currentValue;
            vault.report(0, loss);
            principalBalance = currentValue;
            emit Harvested(-int256(loss));
        }
    }

    function emergencyWithdraw(address recipient)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonReentrant
    {
        if (recipient == address(0)) revert InvalidAddress();

        uint256 withdrawn = pool.withdraw(address(asset), type(uint256).max, recipient);
        principalBalance = 0;
        emit EmergencyWithdrawn(withdrawn, recipient);
    }
}
