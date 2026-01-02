// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import {AaveYieldDonatingStrategy} from "../../src/strategy/AaveYieldDonatingStrategy.sol";
import {OctantMiniVault} from "../../src/vault/OctantMiniVault.sol";
import {FundingRouter} from "../../src/router/FundingRouter.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {MockAToken} from "../mocks/MockAToken.sol";
import {MockAavePool} from "../mocks/MockAavePool.sol";
import {IAaveV3Pool} from "../../src/interfaces/IAaveV3Pool.sol";

contract AaveYieldDonatingStrategyTest is Test {
    MockERC20 internal asset;
    OctantMiniVault internal vault;
    FundingRouter internal router;
    MockAToken internal aToken;
    MockAavePool internal pool;
    AaveYieldDonatingStrategy internal strategy;

    address internal depositor = address(0xCAFE);

    function setUp() public {
        asset = new MockERC20("Mock USD", "mUSD", 18);
        vault = new OctantMiniVault(asset, "Octant Mini", "oMINI", address(this));
        router = new FundingRouter(asset, address(this));
        vault.setFundingRouter(address(router));

        aToken = new MockAToken(address(asset));
        pool = new MockAavePool(asset, aToken);
        aToken.setPool(address(pool));

        strategy = new AaveYieldDonatingStrategy(
            vault, asset, aToken, IAaveV3Pool(address(pool)), address(this)
        );
        vault.setStrategy(address(strategy));

        asset.mint(depositor, 2_000 ether);
        vm.prank(depositor);
        asset.approve(address(vault), type(uint256).max);
    }

    function testDeployFundsIncreasesPrincipal() public {
        _depositAndForward(1_000 ether);

        strategy.deployFunds(800 ether);

        assertEq(strategy.principalBalance(), 800 ether);
        assertEq(aToken.balanceOf(address(strategy)), 800 ether);
        assertEq(asset.balanceOf(address(pool)), 800 ether);
    }

    function testFreeFundsReturnsPrincipalToVault() public {
        _depositAndForward(1_000 ether);
        strategy.deployFunds(900 ether);

        strategy.freeFunds(300 ether);

        assertEq(strategy.principalBalance(), 600 ether);
        assertEq(asset.balanceOf(address(vault)), 300 ether);
    }

    function testHarvestReportsProfit() public {
        _depositAndForward(1_000 ether);
        strategy.deployFunds(1_000 ether);

        aToken.forceMint(address(strategy), 100 ether);
        asset.mint(address(pool), 100 ether);

        strategy.harvestAndReport();

        assertEq(asset.balanceOf(address(router)), 100 ether);
        assertEq(strategy.principalBalance(), 1_000 ether);
    }

    function testHarvestReportsLoss() public {
        _depositAndForward(1_000 ether);
        strategy.deployFunds(1_000 ether);

        aToken.forceBurn(address(strategy), 200 ether);

        strategy.harvestAndReport();

        assertEq(strategy.principalBalance(), 800 ether);
        assertEq(vault.managedAssets(), 800 ether);
    }

    function testEmergencyWithdrawResetsPrincipal() public {
        _depositAndForward(500 ether);
        strategy.deployFunds(500 ether);

        strategy.emergencyWithdraw(address(this));

        assertEq(strategy.principalBalance(), 0);
        assertEq(aToken.balanceOf(address(strategy)), 0);
    }

    function _depositAndForward(uint256 amount) internal {
        vm.prank(depositor);
        vault.deposit(amount, depositor);
        vault.forwardToStrategy(amount);
    }
}
