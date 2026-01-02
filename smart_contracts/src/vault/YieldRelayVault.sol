// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {IAaveV3Pool} from "../interfaces/IAaveV3Pool.sol";
import {IAToken} from "../interfaces/IAToken.sol";
import {YieldRouter} from "../router/YieldRouter.sol";
import {BeneficiaryRegistry} from "../registry/BeneficiaryRegistry.sol";

/// @title YieldRelayVault
/// @notice Supplies principal to Aave and routes accrued yield to beneficiary splits.
contract YieldRelayVault is ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint16 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant ACC_SCALE = 1e18;

    IERC20 public immutable asset;
    IAaveV3Pool public immutable pool;
    IAToken public immutable aToken;
    YieldRouter public immutable router;
    BeneficiaryRegistry public immutable registry;

    struct SplitConfig {
        address[] beneficiaries;
        uint16[] bps;
        bool exists;
    }

    uint256 public totalPrincipal;
    uint256 public accYieldPerPrincipal;

    mapping(address => uint256) public principalOf;
    mapping(address => uint256) public yieldDebt;
    mapping(address => SplitConfig) private splitConfigs;

    event Deposited(address indexed depositor, uint256 amount);
    event PrincipalWithdrawn(address indexed depositor, uint256 amount);
    event YieldAccrued(uint256 amount, uint256 newAccYieldPerPrincipal);
    event YieldAllocated(address indexed depositor, uint256 amount);
    event SplitConfigUpdated(address indexed depositor);

    error InvalidAddress();
    error ZeroAmount();
    error InvalidBps();
    error LengthMismatch();
    error NoSplitConfig();
    error BeneficiaryNotEligible(address beneficiary);
    error InsufficientPrincipal();
    error WithdrawalFailed();

    constructor(
        IERC20 asset_,
        IAaveV3Pool pool_,
        IAToken aToken_,
        YieldRouter router_,
        BeneficiaryRegistry registry_
    ) {
        if (
            address(asset_) == address(0) || address(pool_) == address(0)
                || address(aToken_) == address(0) || address(router_) == address(0)
                || address(registry_) == address(0)
        ) revert InvalidAddress();
        asset = asset_;
        pool = pool_;
        aToken = aToken_;
        router = router_;
        registry = registry_;

        asset.safeApprove(address(pool_), type(uint256).max);
    }

    function deposit(uint256 amount, address[] calldata beneficiaries, uint16[] calldata bps)
        external
        nonReentrant
    {
        if (amount == 0) revert ZeroAmount();

        _accrueYield();
        _allocateYield(msg.sender);

        if (beneficiaries.length > 0) {
            _setSplitConfig(msg.sender, beneficiaries, bps);
        } else if (!splitConfigs[msg.sender].exists) {
            revert NoSplitConfig();
        }

        asset.safeTransferFrom(msg.sender, address(this), amount);
        pool.supply(address(asset), amount, address(this), 0);

        principalOf[msg.sender] += amount;
        totalPrincipal += amount;
        yieldDebt[msg.sender] = _accruedFor(msg.sender);

        emit Deposited(msg.sender, amount);
    }

    function withdrawPrincipal(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        _accrueYield();
        _allocateYield(msg.sender);

        if (amount > principalOf[msg.sender]) revert InsufficientPrincipal();

        principalOf[msg.sender] -= amount;
        totalPrincipal -= amount;

        uint256 withdrawn = pool.withdraw(address(asset), amount, msg.sender);
        if (withdrawn < amount) revert WithdrawalFailed();

        yieldDebt[msg.sender] = _accruedFor(msg.sender);
        emit PrincipalWithdrawn(msg.sender, amount);
    }

    function setSplitConfig(address[] calldata beneficiaries, uint16[] calldata bps)
        external
        nonReentrant
    {
        _accrueYield();
        _allocateYield(msg.sender);
        _setSplitConfig(msg.sender, beneficiaries, bps);
        yieldDebt[msg.sender] = _accruedFor(msg.sender);
    }

    function allocateYield(address depositor) external nonReentrant {
        _accrueYield();
        _allocateYield(depositor);
    }

    function accruedYield() external view returns (uint256) {
        uint256 currentValue = aToken.balanceOf(address(this)) + asset.balanceOf(address(this));
        if (currentValue <= totalPrincipal) return 0;
        return currentValue - totalPrincipal;
    }

    function getSplitConfig(address depositor)
        external
        view
        returns (address[] memory beneficiaries, uint16[] memory bps)
    {
        SplitConfig storage config = splitConfigs[depositor];
        return (config.beneficiaries, config.bps);
    }

    function pendingYield(address depositor) external view returns (uint256) {
        uint256 accrued = _accruedFor(depositor);
        if (accrued <= yieldDebt[depositor]) return 0;
        return accrued - yieldDebt[depositor];
    }

    function _setSplitConfig(
        address depositor,
        address[] calldata beneficiaries,
        uint16[] calldata bps
    ) internal {
        if (beneficiaries.length == 0) revert NoSplitConfig();
        if (beneficiaries.length != bps.length) revert LengthMismatch();

        uint256 totalBps;
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            if (beneficiaries[i] == address(0)) revert InvalidAddress();
            if (!registry.isEligible(beneficiaries[i])) {
                revert BeneficiaryNotEligible(beneficiaries[i]);
            }
            uint16 share = bps[i];
            if (share == 0) revert InvalidBps();
            totalBps += share;
        }
        if (totalBps != BPS_DENOMINATOR) revert InvalidBps();

        SplitConfig storage config = splitConfigs[depositor];
        delete config.beneficiaries;
        delete config.bps;
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            config.beneficiaries.push(beneficiaries[i]);
            config.bps.push(bps[i]);
        }
        config.exists = true;
        emit SplitConfigUpdated(depositor);
    }

    function _accrueYield() internal {
        if (totalPrincipal == 0) return;

        uint256 aTokenBalance = aToken.balanceOf(address(this));
        if (aTokenBalance <= totalPrincipal) return;

        uint256 yieldAmount = aTokenBalance - totalPrincipal;
        uint256 withdrawn = pool.withdraw(address(asset), yieldAmount, address(this));
        if (withdrawn == 0) return;

        accYieldPerPrincipal += (withdrawn * ACC_SCALE) / totalPrincipal;
        emit YieldAccrued(withdrawn, accYieldPerPrincipal);
    }

    function _allocateYield(address depositor) internal {
        uint256 principal = principalOf[depositor];
        if (principal == 0) {
            yieldDebt[depositor] = 0;
            return;
        }

        uint256 accrued = _accruedFor(depositor);
        uint256 owed = accrued > yieldDebt[depositor] ? accrued - yieldDebt[depositor] : 0;
        if (owed == 0) {
            yieldDebt[depositor] = accrued;
            return;
        }

        SplitConfig storage config = splitConfigs[depositor];
        if (!config.exists) revert NoSplitConfig();

        asset.safeTransfer(address(router), owed);

        uint256 distributed;
        for (uint256 i = 0; i < config.beneficiaries.length; i++) {
            address beneficiary = config.beneficiaries[i];
            if (!registry.isEligible(beneficiary)) revert BeneficiaryNotEligible(beneficiary);
            uint256 share = (owed * config.bps[i]) / BPS_DENOMINATOR;
            if (share > 0) {
                router.creditYield(beneficiary, share);
                distributed += share;
            }
        }

        if (distributed < owed) {
            address last = config.beneficiaries[config.beneficiaries.length - 1];
            router.creditYield(last, owed - distributed);
        }

        yieldDebt[depositor] = accrued;
        emit YieldAllocated(depositor, owed);
    }

    function _accruedFor(address depositor) internal view returns (uint256) {
        return (principalOf[depositor] * accYieldPerPrincipal) / ACC_SCALE;
    }
}
