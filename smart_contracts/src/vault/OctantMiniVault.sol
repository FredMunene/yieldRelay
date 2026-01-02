// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @title OctantMiniVault
/// @notice ERC-4626 vault that coordinates with a donating strategy and funding router.
contract OctantMiniVault is ERC4626, AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant STRATEGIST_ROLE = keccak256("STRATEGIST_ROLE");

    address public strategy;
    address public fundingRouter;
    uint256 private _managedAssets;

    event StrategyUpdated(address indexed caller, address indexed newStrategy);
    event FundingRouterUpdated(address indexed caller, address indexed newRouter);
    event YieldDonated(uint256 indexed profit, address indexed router);
    event LossReported(uint256 indexed loss, address indexed reporter);
    event StrategyFundsForwarded(address indexed caller, address indexed strategy, uint256 amount);

    error InvalidAddress();
    error UnauthorizedStrategy();
    error RouterNotSet();
    error StrategyNotSet();
    error InsufficientLiquidity();
    error InsufficientManagedAssets();
    error ZeroAmount();

    constructor(IERC20 asset_, string memory name_, string memory symbol_, address admin)
        ERC20(name_, symbol_)
        ERC4626(asset_)
    {
        if (admin == address(0)) revert InvalidAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(STRATEGIST_ROLE, admin);
    }

    modifier onlyStrategy() {
        if (msg.sender != strategy) revert UnauthorizedStrategy();
        _;
    }

    /// @notice Returns the principal tracked by the vault (vault float + deployed capital).
    function totalAssets() public view virtual override returns (uint256) {
        return _managedAssets;
    }

    /// @notice Assigns the active strategy that can call report().
    function setStrategy(address newStrategy) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newStrategy == address(0)) revert InvalidAddress();
        strategy = newStrategy;
        emit StrategyUpdated(msg.sender, newStrategy);
    }

    /// @notice Assigns the funding router that will receive donated yield.
    function setFundingRouter(address newRouter) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newRouter == address(0)) revert InvalidAddress();
        fundingRouter = newRouter;
        emit FundingRouterUpdated(msg.sender, newRouter);
    }

    /// @notice Moves idle vault liquidity to the strategy contract.
    function forwardToStrategy(uint256 amount) external onlyRole(STRATEGIST_ROLE) nonReentrant {
        if (strategy == address(0)) revert StrategyNotSet();
        if (amount == 0) revert ZeroAmount();

        IERC20 underlying = IERC20(asset());
        if (amount > underlying.balanceOf(address(this))) revert InsufficientLiquidity();

        underlying.safeTransfer(strategy, amount);
        emit StrategyFundsForwarded(msg.sender, strategy, amount);
    }

    /// @notice Strategy hook to report profit/loss, routing yield to the FundingRouter.
    function report(uint256 profit, uint256 loss) external virtual onlyStrategy nonReentrant {
        IERC20 underlying = IERC20(asset());

        if (loss > 0) {
            uint256 appliedLoss = loss > _managedAssets ? _managedAssets : loss;
            if (appliedLoss > 0) {
                _managedAssets -= appliedLoss;
                emit LossReported(appliedLoss, msg.sender);
            }
        }

        if (profit > 0) {
            if (fundingRouter == address(0)) revert RouterNotSet();
            if (profit > underlying.balanceOf(address(this))) revert InsufficientLiquidity();

            underlying.safeTransfer(fundingRouter, profit);
            emit YieldDonated(profit, fundingRouter);
        }
    }

    /// @notice Exposes tracked principal for external accounting.
    function managedAssets() external view returns (uint256) {
        return _managedAssets;
    }

    /// @notice Idle liquidity available in the vault (not yet forwarded to the strategy).
    function availableLiquidity() public view returns (uint256) {
        return IERC20(asset()).balanceOf(address(this));
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares)
        internal
        override
    {
        super._deposit(caller, receiver, assets, shares);
        _managedAssets += assets;
    }

    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal override {
        if (assets > _managedAssets) revert InsufficientManagedAssets();
        _managedAssets -= assets;
        super._withdraw(caller, receiver, owner, assets, shares);
    }
}
