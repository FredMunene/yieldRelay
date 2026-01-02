// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {YieldRelayVault} from "../src/vault/YieldRelayVault.sol";
import {YieldRouter} from "../src/router/YieldRouter.sol";
import {BeneficiaryRegistry} from "../src/registry/BeneficiaryRegistry.sol";
import {IAToken} from "../src/interfaces/IAToken.sol";
import {IAaveV3Pool} from "../src/interfaces/IAaveV3Pool.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

/// @notice Deploys YieldRelay core contracts and optionally a mock ERC20.
/// @dev Env vars:
/// - PRIVATE_KEY: deployer key used for broadcasting
/// - YR_ASSET (optional): pre-existing ERC20 asset; deploys mock if unset/zero
/// - YR_ATOKEN: Aave aToken address
/// - YR_AAVE_POOL: Aave pool address
/// - YR_ADMIN (optional): owner/admin address (defaults to PRIVATE_KEY signer)
/// - YR_INITIAL_MINT (optional): amount minted to admin when deploying a mock asset
/// - YR_BENEFICIARY_COUNT (optional): number of registry entries to seed
/// - YR_BENEFICIARY_{i}_ADDR / _META: registry seed values
contract DeployYieldRelay is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address admin = vm.envOr("YR_ADMIN", vm.addr(deployerKey));
        address assetAddr = vm.envOr("YR_ASSET", address(0));
        address aTokenAddr = vm.envAddress("YR_ATOKEN");
        address poolAddr = vm.envAddress("YR_AAVE_POOL");

        vm.startBroadcast(deployerKey);

        IERC20 asset = _ensureAsset(assetAddr, admin);
        BeneficiaryRegistry registry = new BeneficiaryRegistry(admin);
        YieldRouter router = new YieldRouter(asset, registry, admin);
        YieldRelayVault vault = new YieldRelayVault(
            asset, IAaveV3Pool(poolAddr), IAToken(aTokenAddr), router, registry
        );
        router.setVault(address(vault));

        _seedBeneficiaries(registry);

        vm.stopBroadcast();

        _logDeployments(address(asset), address(registry), address(router), address(vault));
    }

    function _ensureAsset(address assetAddr, address admin) internal returns (IERC20) {
        if (assetAddr != address(0)) {
            return IERC20(assetAddr);
        }

        uint256 initialMint = vm.envOr("YR_INITIAL_MINT", uint256(1_000_000 ether));
        MockERC20 mock = new MockERC20("Mock Yield Relay USD", "mYRUSD", 18);
        mock.mint(admin, initialMint);
        return IERC20(address(mock));
    }

    function _seedBeneficiaries(BeneficiaryRegistry registry) internal {
        uint256 count = vm.envOr("YR_BENEFICIARY_COUNT", uint256(0));
        for (uint256 i = 0; i < count; i++) {
            string memory index = vm.toString(i);
            address beneficiary =
                vm.envAddress(string.concat("YR_BENEFICIARY_", index, "_ADDR"));
            string memory metadata =
                vm.envString(string.concat("YR_BENEFICIARY_", index, "_META"));
            registry.addBeneficiary(beneficiary, metadata);
        }
    }

    function _logDeployments(
        address asset,
        address registry,
        address router,
        address vault
    ) internal view {
        console2.log("Asset      :", asset);
        console2.log("Registry   :", registry);
        console2.log("Router     :", router);
        console2.log("Vault      :", vault);
    }
}
