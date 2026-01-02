// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import {OctantMiniVault} from "../../src/vault/OctantMiniVault.sol";
import {FundingRouter} from "../../src/router/FundingRouter.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {YieldSink} from "../mocks/YieldSink.sol";
import {MockStrategy} from "../mocks/MockStrategy.sol";

contract OctantMiniVaultTest is Test {
    MockERC20 internal asset;
    OctantMiniVault internal vault;
    YieldSink internal sink;
    address internal depositor = address(0xBEEF);

    function setUp() public {
        asset = new MockERC20("Mock USD", "mUSD", 18);
        vault = new OctantMiniVault(asset, "Octant Mini", "oMINI", address(this));
        sink = new YieldSink(asset);

        asset.mint(depositor, 1_000 ether);
        vm.prank(depositor);
        asset.approve(address(vault), type(uint256).max);
    }

    function testDepositUpdatesManagedAssets() public {
        _deposit(500 ether);
        assertEq(vault.totalAssets(), 500 ether);
        assertEq(vault.managedAssets(), 500 ether);
    }

    function testWithdrawReducesManagedAssets() public {
        _deposit(800 ether);
        vm.prank(depositor);
        vault.withdraw(300 ether, depositor, depositor);
        assertEq(vault.managedAssets(), 500 ether);
    }

    function testForwardToStrategyTransfersFunds() public {
        _deposit(600 ether);
        MockStrategy strat = new MockStrategy(asset);
        vault.setStrategy(address(strat));
        vault.forwardToStrategy(400 ether);
        assertEq(asset.balanceOf(address(strat)), 400 ether);
    }

    function testForwardToStrategyRevertsWithoutStrategy() public {
        _deposit(100 ether);
        vm.expectRevert(OctantMiniVault.StrategyNotSet.selector);
        vault.forwardToStrategy(10 ether);
    }

    function testReportProfitDonatesToRouter() public {
        _deposit(700 ether);
        vault.setFundingRouter(address(sink));
        vault.setStrategy(address(this));

        vault.report(100 ether, 0);
        assertEq(asset.balanceOf(address(sink)), 100 ether);
        assertEq(vault.managedAssets(), 700 ether);
    }

    function testReportLossReducesManagedAssets() public {
        _deposit(700 ether);
        vault.setStrategy(address(this));
        vault.report(0, 200 ether);
        assertEq(vault.managedAssets(), 500 ether);
    }

    function testReportProfitWithoutRouterReverts() public {
        _deposit(200 ether);
        vault.setStrategy(address(this));
        vm.expectRevert(OctantMiniVault.RouterNotSet.selector);
        vault.report(50 ether, 0);
    }

    function _deposit(uint256 amount) internal {
        vm.prank(depositor);
        vault.deposit(amount, depositor);
    }
}
