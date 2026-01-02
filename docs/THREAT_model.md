# Threat Model — Octant Mini x Aave Yield-Donating Vault

## Assets
- User principal (deposited USDC)
- Generated yield
- Allocation / routing rights
- Strategy principal accounting
- Admin privileges

## Trust Boundaries
[User Wallet] ↔ [Vault (ERC-4626)] ↔ [Strategy (Aave Pool)] ↔ [Aave Protocol]
                                               ↘
                                                [FundingRouter]

## Identified Threats & Mitigations

| ID | Threat | Impact | Mitigation |
|----|---------|---------|------------|
| T1 | **Re-entrancy** during `report()` or `route()` | Theft or double-donation | Use `nonReentrant` modifier (OpenZeppelin ReentrancyGuard) |
| T2 | **Incorrect profit calculation** | Over-donation → under-collateralized vault | Maintain explicit `principal` state; use SafeMath; audit before harvest |
| T3 | **Aave integration risk** | Loss if Aave pool exploited | Limit exposure; enable emergencyWithdraw |
| T4 | **Router compromise** | Misallocation of funds | `setFundingRouter()` callable only by admin/governance; emit events |
| T5 | **Admin key misuse** | Rug / parameter manipulation | Multisig or timelock for admin functions |
| T6 | **Keeper spam / DoS** | Gas griefing or forced harvest loops | Rate-limit `harvestAndReport()`; keeper allowlist |
| T7 | **Loss of price oracle / APY feed** | Incorrect yield display | Use mock APY for MVP; fail-safe UI messages |
| T8 | **Front-end phishing** | Users deposit into fake vault | Verify contract addresses; pin frontend hash to IPFS |
| T9 | **Slippage or rounding errors** | Accounting drift | Use fixed-point math libraries and basis-point precision |
| T10 | **Unexpected Aave upgrade** | Incompatible pool ABI | Use interface abstraction; version-check on deploy |

## Residual Risks
- Dependence on Aave protocol security.  
- External keeper availability for regular harvesting.  
- DAO governance quality for routing allocations.

## Security Controls
- OpenZeppelin base contracts for ERC-20 / ERC-4626 / AccessControl.  
- Hardhat/Foundry test suite for deposit, withdraw, harvest, route.  
- Continuous audit checks before mainnet migration.
