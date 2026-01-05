# 🌀 YieldRelay
**Earn yield. Fund your ecosystem.**

---

## Summary

**YieldRelay** is a compliance-aware RealFi infrastructure primitive on Mantle that preserves capital while routing only **accrued yield** to verified real-world beneficiaries.

Built on Mantle and integrated with Aave, YieldRelay separates **principal ownership** from **yield distribution**, enabling sustainable funding for social infrastructure, DAOs, and public-good initiatives without spending principal.

---

## 🌱 Story

Recent DAO shutdowns and governance pauses across major ecosystems have exposed a deeper issue: communities struggle to turn treasury capital into sustained impact when governance becomes slow, fragile, or overly complex.

YieldRelay takes a different approach. Instead of relying on continuous votes or manual grant cycles, it enables communities to generate yield from idle capital and automatically route that yield to builders, grants, and ecosystem programs—**without touching principal** and **without requiring constant governance intervention**.

---

## 🧠 Problem

Social infrastructure (e.g. healthcare, education, community services) is typically funded through one-off donations and grants that are immediately spent, leading to:

- Rapid depletion of capital
- Limited long-term sustainability
- Low transparency into fund usage

At the same time, institutions and donors face increasing compliance and reporting requirements that make experimentation with on-chain funding models difficult. There is no simple, composable way to generate recurring funding from capital while preserving principal and maintaining compliance awareness.

---

## 💡 Solution

YieldRelay introduces a **vault-on-Aave + yield router** architecture that:

- Deposits capital into a yield-generating protocol (Aave)
- Preserves the principal amount
- Programmatically routes only the accrued yield
- Distributes yield to registered, verified beneficiaries
- Provides full on-chain transparency

YieldRelay does not generate yield itself. It integrates with external yield sources and focuses on **safe accounting, deterministic routing, and distribution**.

---

## How It Works

1. A user deposits assets into a YieldRelay Vault
2. The vault supplies assets to Aave on Mantle
3. Yield accrues via borrower-paid interest
4. YieldRelay calculates accrued yield above principal
5. Yield is split according to configured rules
6. Beneficiaries claim routed yield on-chain

Principal remains withdrawable only by the depositor.

---

## Why Mantle

YieldRelay is deployed on Mantle to leverage:

- Low gas fees for frequent yield distribution
- High throughput for scalable public-good funding
- EVM compatibility with existing DeFi infrastructure
- Native support for real-world financial use cases

---

## Compliance Disclosure

This MVP does not issue or custody regulated assets.

Compliance is represented through:
- Beneficiary allowlists
- Role-based access control
- Explicit disclosures of simulated components

No personal data or KYC information is stored on-chain.

---

## Smart Contracts (YieldRelay MVP)

- `smart_contracts/src/vault/YieldRelayVault.sol` — vault-on-Aave with per-depositor principal + split config
- `smart_contracts/src/router/YieldRouter.sol` — claimable yield accounting + beneficiary payouts
- `smart_contracts/src/registry/BeneficiaryRegistry.sol` — compliance allowlist registry

### Deploy (Contracts Only)

```bash
forge script smart_contracts/script/DeployYieldRelay.s.sol --rpc-url $RPC_URL --broadcast
```

Deploy script uses mock `MockAToken` + `MockAavePool` for the yield source.

---

## Repository Structure

```
smart_contracts/
  src/
    vault/YieldRelayVault.sol
    router/YieldRouter.sol
    registry/BeneficiaryRegistry.sol
docs/
  archicture.md
  PRD2.md
frontend/
```

---

## 🎥 Demo

Check out a short demo video showing how deposits, yield generation, and allocation routing work:
[Watch Demo](https://youtu.be/n09t7tFkUeg)

---


## ⚙ How to Use

You can either try **the live demo** or run it locally:

### Live Demo
[Visit YieldRelay live](https://yieldrelay.vercel.app/)

### Local Setup (for developers / hackathon judges)

```bash
git clone https://github.com/Fredmunene/yieldrelay.git
cd yieldrelay/frontend
npm install
npm start
```

Open your browser at http://localhost:3000 and explore the dashboard. It shows:

- Total deposited funds
- - Accrued yield generated from the underlying vault (simulated for MVP)

- Distribution flow to grants, builders, or other projects

---

## 🗺 Roadmap

**Q4 2025**

- MVP launch (Vault, Routing, Simulation)
- Public GitHub release
- Feedback loop from early DAOs

**Q1 2026**

- Integrate more yield strategies (Lido, Aave, Pendle)
- Add role-based access for DAO treasurers
- Introduce a “Community Goals” module

**Q2 2026**

- Expand simulation tools (historical yield projection)
- Add governance layer for yield allocation votes
- UI/UX redesign for mobile DAOs

**Q3 2026**

- Launch analytics and reporting API
- Support multi-chain vaults (Solana, Base, Polygon)

**Q4 2026**

- Public beta with ecosystem partners
- Full open-source documentation
- DAO onboarding program

---

## 📌 License

- MIT License — free to use, fork, and build on.

---

## ❤️ Why It Matters

YieldRelay started as a hackathon MVP, but it’s built for every DAO or community that wants to make their funds work automatically. Even small treasuries can generate real impact without waiting for perfect governance or endless votes.

With YieldRelay, DAOs stop watching their funds sit idle and start turning capital into growth, builders, and community magic.
