# Operations Runbook — Octant Mini x Aave Strategy

## Overview
This runbook defines daily operations, yield maintenance, and incident recovery for the Octant Mini contracts deployed on testnet/mainnet.

## Routine Tasks

| Frequency | Task | Command / Action |
|------------|------|------------------|
| Daily | Monitor vault TVL & aToken balances | `cast call <aToken> "balanceOf(address)" <strategy>` |
| 2× per week | Trigger `harvestAndReport()` | `cast send <strategy> "harvestAndReport()"` |
| Weekly | Route yield to programs | `cast send <router> "route()"` |
| Ad-hoc | Update allocations | `cast send <router> "setAllocations(uint16[])" ...` |

## Normal Operations
1. **Deposit Handling**  
   - Users deposit USDC via frontend → vault mints ERC-4626 shares.  
2. **Yield Harvest Cycle**  
   - Keeper calls `harvestAndReport()`.  
   - Vault donates profit to router.  
3. **Distribution**  
   - Admin or automation triggers `route()` to distribute funds.

## Incident Scenarios

### A. Aave Pool Failure
- **Impact:** Strategy `withdraw` reverts.  
- **Action:**  
  1. Pause vault deposits (if pauseable).  
  2. Call `emergencyWithdraw()` from strategy to pull remaining liquidity.  
  3. Redeploy new strategy and update vault reference.

### B. Yield Mis-Accounting
- **Impact:** Incorrect profit reported → over-donation or under-donation.  
- **Action:**  
  - Manually adjust `principal` tracking variable via admin patch.  
  - Audit last `report()` values and recompute expected principal.

### C. Router Compromise
- **Impact:** Wrong allocations / theft risk.  
- **Action:**  
  1. Freeze vault donations (`setFundingRouter(address(0))`).  
  2. Redeploy verified router and re-link.  
  3. Post-mortem entry in governance log.

### D. Gas / Network Congestion
- Use smaller batch allocations.  
- Switch to another RPC or L2 testnet.

## Monitoring
- Etherscan or Tenderly alert on:
  - `YieldDonated`, `FundsRouted` events.  
  - Unusual loss values in `report()`.  
- Subgraph (optional): track TVL, total yield donated.

## Recovery Verification
After any incident:
1. Compare on-chain balances vs internal accounting.  
2. Redeploy test flow in staging before resuming main vault.
