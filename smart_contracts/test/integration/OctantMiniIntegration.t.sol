// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import {OctantMiniVault} from "../../src/vault/OctantMiniVault.sol";
import {FundingRouter} from "../../src/router/FundingRouter.sol";
import {AaveYieldDonatingStrategy} from "../../src/strategy/AaveYieldDonatingStrategy.sol";
import {IAaveV3Pool} from "../../src/interfaces/IAaveV3Pool.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {MockAToken} from "../mocks/MockAToken.sol";
import {MockAavePool} from "../mocks/MockAavePool.sol";

contract OctantMiniIntegrationTest is Test {
    MockERC20 internal asset;
    OctantMiniVault internal vault;
    FundingRouter internal router;
    MockAToken internal aToken;
    MockAavePool internal pool;
    AaveYieldDonatingStrategy internal strategy;

    address internal depositor = address(0xDEAD);
    address internal pgp1 = address(0x1111);
    address internal pgp2 = address(0x2222);

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

        FundingRouter.Program memory programA = FundingRouter.Program({
            recipient: pgp1, bps: 7_000, metadataURI: "ipfs://pgp1", active: true
        });
        FundingRouter.Program memory programB = FundingRouter.Program({
            recipient: pgp2, bps: 3_000, metadataURI: "ipfs://pgp2", active: true
        });
        router.addProgram(programA);
        router.addProgram(programB);

        asset.mint(depositor, 1_000 ether);
        vm.prank(depositor);
        asset.approve(address(vault), type(uint256).max);
    }

    function testFullFlowRoutesYield() public {
        vm.prank(depositor);
        vault.deposit(1_000 ether, depositor);

        vault.forwardToStrategy(1_000 ether);
        strategy.deployFunds(1_000 ether);

        aToken.forceMint(address(strategy), 100 ether);
        asset.mint(address(pool), 100 ether);

        strategy.harvestAndReport();
        assertEq(asset.balanceOf(address(router)), 100 ether, "router should hold harvested profit");

        router.route();

        assertEq(asset.balanceOf(pgp1), 70 ether, "program 1 receives 70%");
        assertEq(asset.balanceOf(pgp2), 30 ether, "program 2 receives 30%");
        assertEq(vault.managedAssets(), 1_000 ether, "principal remains tracked");
    }
}
