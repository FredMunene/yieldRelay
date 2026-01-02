// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import {YieldRouter} from "../../src/router/YieldRouter.sol";
import {BeneficiaryRegistry} from "../../src/registry/BeneficiaryRegistry.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";

contract YieldRouterTest is Test {
    MockERC20 internal asset;
    BeneficiaryRegistry internal registry;
    YieldRouter internal router;

    address internal vault = address(0xCAFE);
    address internal beneficiary = address(0xBEEF);

    function setUp() public {
        asset = new MockERC20("Mock USD", "mUSD", 18);
        registry = new BeneficiaryRegistry(address(this));
        registry.addBeneficiary(beneficiary, "ipfs://ok");
        router = new YieldRouter(asset, registry, address(this));
        router.setVault(vault);
    }

    function testCreditAndClaim() public {
        asset.mint(address(router), 10 ether);
        vm.prank(vault);
        router.creditYield(beneficiary, 10 ether);

        vm.prank(beneficiary);
        router.claimYield();

        assertEq(asset.balanceOf(beneficiary), 10 ether);
        assertEq(router.claimable(beneficiary), 0);
    }

    function testOnlyVaultCanCredit() public {
        vm.expectRevert(YieldRouter.UnauthorizedCaller.selector);
        router.creditYield(beneficiary, 1 ether);
    }
}
