// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import {FundingRouter} from "../../src/router/FundingRouter.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";

contract FundingRouterTest is Test {
    MockERC20 internal asset;
    FundingRouter internal router;
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    function setUp() public {
        asset = new MockERC20("Mock USD", "mUSD", 18);
        router = new FundingRouter(asset, address(this));
    }

    function testAddProgramAndRoute() public {
        FundingRouter.Program memory programA = FundingRouter.Program({
            recipient: alice, bps: 6_000, metadataURI: "ipfs://a", active: true
        });
        FundingRouter.Program memory programB = FundingRouter.Program({
            recipient: bob, bps: 4_000, metadataURI: "ipfs://b", active: true
        });

        router.addProgram(programA);
        router.addProgram(programB);

        asset.mint(address(router), 1_000 ether);
        router.route();

        assertEq(asset.balanceOf(alice), 600 ether);
        assertEq(asset.balanceOf(bob), 400 ether);
    }

    function testSetAllocationsEnforcesTotals() public {
        router.addProgram(
            FundingRouter.Program({recipient: alice, bps: 5_000, metadataURI: "a", active: true})
        );
        router.addProgram(
            FundingRouter.Program({recipient: bob, bps: 5_000, metadataURI: "b", active: true})
        );

        uint16[] memory bpsList = new uint16[](2);
        bpsList[0] = 7_000;
        bpsList[1] = 4_000;

        vm.expectRevert(FundingRouter.BpsTooHigh.selector);
        router.setAllocations(bpsList);
    }

    function testRouteRevertsWithoutActivePrograms() public {
        router.addProgram(
            FundingRouter.Program({recipient: alice, bps: 10_000, metadataURI: "a", active: false})
        );
        asset.mint(address(router), 100 ether);
        vm.expectRevert(FundingRouter.NoActivePrograms.selector);
        router.route();
    }

    function testFuzzSetAllocationsWithinBps(uint16 a, uint16 b, uint16 c) public {
        router.addProgram(
            FundingRouter.Program({recipient: alice, bps: 0, metadataURI: "a", active: true})
        );
        router.addProgram(
            FundingRouter.Program({recipient: bob, bps: 0, metadataURI: "b", active: true})
        );
        router.addProgram(
            FundingRouter.Program({
                recipient: address(0xFEE), bps: 0, metadataURI: "c", active: true
            })
        );

        uint256 total = uint256(a) + uint256(b) + uint256(c);
        vm.assume(total <= router.BPS_DENOMINATOR());

        uint16[] memory list = new uint16[](3);
        list[0] = a;
        list[1] = b;
        list[2] = c;
        router.setAllocations(list);

        FundingRouter.Program[] memory configured = router.getPrograms();
        assertEq(configured[0].bps, a);
        assertEq(configured[1].bps, b);
        assertEq(configured[2].bps, c);
    }
}
