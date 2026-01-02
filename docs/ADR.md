# Architecture Decision Record (ADR)

## Title
Adopt a Yield-Donating Vault Architecture Using Aave v3 and Octant Mini

## Status
Accepted — November 2025

## Context
Small DAOs and early-stage ecosystems often hold idle stablecoins (e.g. USDC) but lack the technical and security resources to deploy them effectively.  
Octant Mini aims to provide a minimal, composable version of the **Octant v2 yield-donating engine** — allowing DAOs to earn yield safely and redirect it automatically to fund public goods.

Aave v3 offers a robust ERC-4626–compatible vault interface (ATokenVault) with proven liquidity and transparent on-chain Vaccounting.  
Combining Aave v3’s yield layer with an Octant-style *skimming mechanism* achieves sustainable, transparent funding with minimal infra.

## Decision
1. **Use Aave v3 as the primary yield source.**
   - Strategy contract interacts directly with the Pool contract (`supply`, `withdraw`).
2. **Implement ERC-4626-compliant `OctantMiniVault`.**
   - Accepts deposits in USDC and tracks user shares.
   - Delegates yield farming to an external strategy.
3. **Implement `AaveYieldDonatingStrategy`.**
   - Supplies capital to Aave v3.
   - Calls `vault.report(profit, loss)` to donate yield instead of compounding to depositors.
4. **Add a lightweight `FundingRouter`.**
   - Receives skimmed yield.
   - Splits donations among registered ecosystem programs using basis-point allocations.
5. **Keep all yield routing transparent and on-chain.**

## Consequences
- 🟢 Sustainable DAO funding with minimal ops overhead.  
- 🟢 ERC-4626 compatibility → plug-and-play with other DeFi protocols.  
- ⚠️ Vault logic must prevent re-entrancy and incorrect profit accounting.  
- ⚠️ Requires a trusted keeper or cron job to trigger `harvestAndReport()`.

## Alternatives Considered
- **Yearn v3 / Kalani** strategies — good for advanced composition but heavier infra.
- **Morpho v2** — higher yield potential but adds dependency complexity.
