// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import {YieldRelayVault} from "../../src/vault/YieldRelayVault.sol";
import {YieldRouter} from "../../src/router/YieldRouter.sol";
import {BeneficiaryRegistry} from "../../src/registry/BeneficiaryRegistry.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {MockAToken} from "../mocks/MockAToken.sol";
import {MockAavePool} from "../mocks/MockAavePool.sol";

contract YieldRelayVaultTest is Test {
    MockERC20 internal asset;
    MockAToken internal aToken;
    MockAavePool internal pool;
    BeneficiaryRegistry internal registry;
    YieldRouter internal router;
    YieldRelayVault internal vault;

    address internal depositor = address(0xBEEF);
    address internal beneficiaryA = address(0xA1);
    address internal beneficiaryB = address(0xB2);

    function setUp() public {
        asset = new MockERC20("Mock USD", "mUSD", 18);
        aToken = new MockAToken(address(asset));
        pool = new MockAavePool(asset, aToken);
        aToken.setPool(address(pool));
        pool.seed(1_000 ether);

        registry = new BeneficiaryRegistry(address(this));
        registry.addBeneficiary(beneficiaryA, "ipfs://a");
        registry.addBeneficiary(beneficiaryB, "ipfs://b");

        router = new YieldRouter(asset, registry, address(this));
        vault = new YieldRelayVault(asset, pool, aToken, router, registry);
        router.setVault(address(vault));

        asset.mint(depositor, 1_000 ether);
        vm.prank(depositor);
        asset.approve(address(vault), type(uint256).max);
    }

    function testDepositUpdatesPrincipalAndAToken() public {
        _deposit(100 ether);
        assertEq(vault.principalOf(depositor), 100 ether);
        assertEq(vault.totalPrincipal(), 100 ether);
        assertEq(aToken.balanceOf(address(vault)), 100 ether);
    }

    function testYieldAllocationToMultipleBeneficiaries() public {
        _deposit(100 ether);

        aToken.forceMint(address(vault), 20 ether);
        vault.allocateYield(depositor);

        assertEq(router.claimable(beneficiaryA), 12 ether);
        assertEq(router.claimable(beneficiaryB), 8 ether);

        vm.prank(beneficiaryA);
        router.claimYield();
        vm.prank(beneficiaryB);
        router.claimYield();

        assertEq(asset.balanceOf(beneficiaryA), 12 ether);
        assertEq(asset.balanceOf(beneficiaryB), 8 ether);
    }

    function testWithdrawCannotExceedPrincipal() public {
        _deposit(50 ether);
        vm.prank(depositor);
        vm.expectRevert(YieldRelayVault.InsufficientPrincipal.selector);
        vault.withdrawPrincipal(60 ether);
    }

    function testAllocationRevertsForDisabledBeneficiary() public {
        _deposit(100 ether);
        registry.disableBeneficiary(beneficiaryA);
        aToken.forceMint(address(vault), 10 ether);
        vm.expectRevert(
            abi.encodeWithSelector(
                YieldRelayVault.BeneficiaryNotEligible.selector, beneficiaryA
            )
        );
        vault.allocateYield(depositor);
    }

    function _deposit(uint256 amount) internal {
        address[] memory beneficiaries = new address[](2);
        beneficiaries[0] = beneficiaryA;
        beneficiaries[1] = beneficiaryB;
        uint16[] memory bps = new uint16[](2);
        bps[0] = 6_000;
        bps[1] = 4_000;

        vm.prank(depositor);
        vault.deposit(amount, beneficiaries, bps);
    }
}
