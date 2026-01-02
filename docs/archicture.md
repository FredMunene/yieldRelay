# Architecture Overview

YieldRelay is designed as a modular, composable infrastructure primitive that separates yield generation from yield routing.

---

## Core Design Principles

- **Separation of concerns**  
  Yield generation is external. Yield routing is internal.

- **Principal safety**  
  Principal is never routed, redistributed, or implicitly transferred.

- **Compliance awareness**  
  Regulatory constraints are acknowledged without storing sensitive data on-chain.

- **Composable by default**  
  Designed to integrate with existing DeFi and RealFi systems.

---

## High-Level Architecture

User
↓
YieldRelay Vault
↓
Aave Pool (Yield Source)
↑
Yield Accrual
↓
Yield Router
↓
Beneficiaries


---

## Smart Contract Components

### 1. YieldRelayVault

Responsibilities:
- Accept user deposits
- Supply assets to Aave
- Track principal per depositor
- Track per-depositor beneficiary split configs
- Accrue and allocate yield on demand

Key invariants:
- Principal cannot be routed
- Withdrawals are bounded by available liquidity
- Yield is allocated pro-rata by principal ownership

---

### 2. YieldRouter

Responsibilities:
- Record claimable yield per beneficiary
- Enforce registry eligibility on credit and claim
- Transfer yield on beneficiary claim

Routing is deterministic and auditable.

---

### 3. BeneficiaryRegistry

Responsibilities:
- Register eligible beneficiaries
- Enforce allowlists
- Support attestations and metadata
- Enable compliance disclosures

No PII is stored on-chain.

---

## Yield Accounting Model

- Principal = sum of user deposits
- Yield = current vault value − principal
- Only positive yield is distributable
- Vault uses a global yield accumulator (accYieldPerPrincipal)
- Each depositor's pending yield is computed on-demand and split to beneficiaries

---

## Failure & Risk Handling

- Liquidity shortfall → partial withdrawals
- High utilization → delayed withdrawals
- Zero yield → no distribution
- Aave pause → vault freeze

All failure cases are explicit and observable.

---

## Security Considerations

- Reentrancy protection on all state changes
- Explicit accounting boundaries
- Minimal trust assumptions
- External protocol risk isolated to Aave

---

## Extensibility

- Multiple yield sources
- ERC-4626 adapters
- DAO governance hooks
- Compliance attestation layers
