// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {OctantMiniVault} from "../src/vault/OctantMiniVault.sol";
import {FundingRouter} from "../src/router/FundingRouter.sol";
import {AaveYieldDonatingStrategy} from "../src/strategy/AaveYieldDonatingStrategy.sol";
import {IAToken} from "../src/interfaces/IAToken.sol";
import {IAaveV3Pool} from "../src/interfaces/IAaveV3Pool.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

/// @notice Deploys Octant Mini core contracts and optionally a mock ERC20 for local testing.
/// @dev Expects the following environment variables:
/// - PRIVATE_KEY: deployer key used for broadcasting
/// - RPC_URL: network endpoint (provided to forge separately)
/// - OM_ASSET (optional): pre-existing ERC20 asset; deploys mock if unset/zero
/// - OM_ATOKEN: Aave aToken address
/// - OM_AAVE_POOL: Aave pool address
/// - OM_ADMIN (optional): owner/admin address (defaults to PRIVATE_KEY signer)
/// - OM_INITIAL_MINT (optional): amount minted to admin when deploying a mock asset (defaults 1_000_000 * 1e18)
contract DeployOctantMini is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address admin = vm.envOr("OM_ADMIN", vm.addr(deployerKey));
        address assetAddr = vm.envOr("OM_ASSET", address(0));
        address aTokenAddr = vm.envAddress("OM_ATOKEN");
        address poolAddr = vm.envAddress("OM_AAVE_POOL");

        vm.startBroadcast(deployerKey);

        IERC20 asset = _ensureAsset(assetAddr, admin);

        FundingRouter router = new FundingRouter(asset, admin);
        OctantMiniVault vault = new OctantMiniVault(asset, "Octant Mini", "oMINI", admin);
        vault.setFundingRouter(address(router));

        AaveYieldDonatingStrategy strategy = new AaveYieldDonatingStrategy(
            vault, asset, IAToken(aTokenAddr), IAaveV3Pool(poolAddr), admin
        );
        vault.setStrategy(address(strategy));

        _seedPrograms(router);

        vm.stopBroadcast();

        _logDeployments(address(asset), address(router), address(vault), address(strategy));
    }

    function _ensureAsset(address assetAddr, address admin) internal returns (IERC20) {
        if (assetAddr != address(0)) {
            return IERC20(assetAddr);
        }

        uint256 initialMint = vm.envOr("OM_INITIAL_MINT", uint256(1_000_000 ether));
        MockERC20 mock = new MockERC20("Mock Octant USD", "mOUSD", 18);
        mock.mint(admin, initialMint);
        return IERC20(address(mock));
    }

    function _logDeployments(address asset, address router, address vault, address strategy)
        internal
        view
    {
        console2.log("Asset      :", asset);
        console2.log("Router     :", router);
        console2.log("Vault      :", vault);
        console2.log("Strategy   :", strategy);
    }

    function _seedPrograms(FundingRouter router) internal {
        uint256 count = vm.envOr("OM_PROGRAM_COUNT", uint256(0));
        for (uint256 i = 0; i < count; i++) {
            string memory index = vm.toString(i);
            address recipient = vm.envAddress(
                string.concat("OM_PROGRAM_", index, "_RECIPIENT")
            );
            uint16 bps = uint16(vm.envUint(string.concat("OM_PROGRAM_", index, "_BPS")));
            string memory metadata = vm.envString(
                string.concat("OM_PROGRAM_", index, "_URI")
            );
            bool active = vm.envOr(
                string.concat("OM_PROGRAM_", index, "_ACTIVE"), true
            );
            FundingRouter.Program memory program = FundingRouter.Program({
                recipient: recipient,
                bps: bps,
                metadataURI: metadata,
                active: active
            });
            router.addProgram(program);
        }
    }
}
