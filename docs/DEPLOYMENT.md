# Deployment Guide

## Prerequisites
- Node v18+, Foundry toolchain
- Testnet RPC (Mantle or any EVM testnet)
- Private key with testnet ETH

## Deployment Order

### 1. Configure Environment
```bash
export RPC_URL=<https endpoint>
export PRIVATE_KEY=<hex private key without 0x>
# Optional overrides:
export YR_ASSET=<existing ERC20, default deploys MockERC20>
export YR_ADMIN=<protocol admin address, default signer>
export YR_INITIAL_MINT=<uint amount minted to admin when deploying mock asset>
export YR_POOL_SEED=<uint amount minted to mock pool for withdrawals>
# Optional registry seed entries (repeat per index)
export YR_BENEFICIARY_COUNT=2
export YR_BENEFICIARY_0_ADDR=0x...
export YR_BENEFICIARY_0_META=ipfs://beneficiary0
export YR_BENEFICIARY_1_ADDR=0x...
export YR_BENEFICIARY_1_META=ipfs://beneficiary1
```

### 2. Run Foundry Script
```bash
cd smart_contracts
forge script script/DeployYieldRelay.s.sol \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify # optional
```
The script:
1. Deploys a mock ERC20 (18 decimals) if `YR_ASSET` is unset.
2. Deploys `BeneficiaryRegistry`, `YieldRouter`, and `YieldRelayVault`.
3. Deploys mock `MockAToken` + `MockAavePool` for the yield source.
4. Mints `YR_INITIAL_MINT` tokens to `YR_ADMIN` when using the mock asset (default 1M tokens).
5. Seeds the mock pool with `YR_POOL_SEED` (default 1M tokens) for withdrawals.

All addresses are printed to stdout for record keeping.

### 3. Configure Beneficiary Registry
- Preferred: populate the `YR_BENEFICIARY_*` env vars (see above) before running the script.
- Alternative: add beneficiaries manually:
  ```bash
  cast send <REGISTRY> "addBeneficiary(address,string)" \
    <beneficiary> "ipfs://..." --rpc-url $RPC_URL --private-key $PRIVATE_KEY
  ```

### 4. Deposit & Yield Allocation
1. Approve the vault for the asset.
2. Call `deposit` with beneficiaries + bps (sum to 10_000).
3. Call `allocateYield` to credit beneficiaries.

> Shortcut: use `./smart_contracts/scripts/run-full-flow.sh` with the deployed addresses, RPC URL, and depositor key to run a full drill (mint → deposit → allocate).

### 6. Verify Contracts (optional)
```bash
forge verify-contract --rpc-url $RPC_URL --etherscan-api-key $ETHERSCAN_KEY <address> <contract>
```

### 7. Deploy Frontend
- `npm install && npm run build`
- Host via Vercel / Netlify / Static IPFS.

## Environment Variables (example)
```
NEXT_PUBLIC_VAULT_ADDRESS=0x...
NEXT_PUBLIC_ROUTER_ADDRESS=0x...
NEXT_PUBLIC_USDC_ADDRESS=0x...
NEXT_PUBLIC_RPC_URL=https://sepolia.base.org
```

## Post-Deployment Tests
1. Deposit USDC → principal tracked.
2. Simulate yield (mock aToken) or wait for real yield.
3. Call `allocateYield()` → verify `claimable` balances on router.
4. Beneficiaries call `claimYield()` → verify recipient balances.
