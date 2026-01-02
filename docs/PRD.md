# Product Requirements Document (PRD)

## Product Name
YieldRelay

---

## Objective

Enable sustainable, transparent funding for real-world infrastructure by routing yield—not principal—from on-chain capital markets to verified beneficiaries.

---

## Target Users

- Foundations and NGOs
- Social infrastructure operators
- DAOs and community funds
- Protocol treasuries

---

## User Stories

### Depositor
- I want to deposit capital and preserve my principal
- I want my yield to support real-world initiatives
- I want transparency into yield usage

### Beneficiary
- I want recurring funding without custody of principal
- I want predictable yield streams
- I want transparent accounting

### Administrator
- I want to manage beneficiary eligibility
- I want compliance-aware controls
- I want auditability

---

## Functional Requirements

### Vault
- Accept deposits
- Track principal
- Supply assets to Aave
- Enable principal withdrawal

### Yield Routing
- Calculate accrued yield
- Apply split ratios
- Support per-depositor multi-beneficiary splits
- Route yield only
- Prevent principal leakage

### Beneficiary Management
- Register beneficiaries
- Enable/disable eligibility
- Attach compliance metadata

---

## Non-Functional Requirements

- Deployed on Mantle
- Low gas cost
- Deterministic execution
- Transparent accounting
- Minimal UI dependencies

---

## MVP Scope

Included:
- Single asset support
- Fixed routing ratios
- Testnet deployment
- Minimal frontend

Excluded:
- Real KYC
- ZK proofs
- DAO governance
- Multi-chain support

---

## Success Metrics

- Vault safety (no principal loss)
- Accurate yield accounting
- Successful beneficiary claims
- Clear judge understanding

---

## Compliance Statement

YieldRelay is an infrastructure MVP.

It does not:
- Issue regulated assets
- Custody funds on behalf of users
- Perform identity verification

All compliance mechanisms are representational.
