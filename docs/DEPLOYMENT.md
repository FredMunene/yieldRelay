# Deployment Guide

## Prerequisites
- Node v18+, Foundry or Hardhat toolchain  
- Testnet RPC (Alchemy/Infura for Sepolia or Base Sepolia)  
- Private key with testnet ETH  
- Deployed mock or real USDC token  
- Verified Aave v3 Pool and aToken addresses for the same testnet  

## Deployment Order

### 1. Configure Environment
```bash
export RPC_URL=<https endpoint>
export PRIVATE_KEY=<hex private key without 0x>
export OM_ATOKEN=<aToken address>
export OM_AAVE_POOL=<Aave pool address>
# Optional overrides:
export OM_ASSET=<existing ERC20, default deploys MockERC20>
export OM_ADMIN=<protocol admin address, default signer>
export OM_INITIAL_MINT=<uint amount minted to admin when deploying mock asset>
# Optional router programs (repeat per index)
export OM_PROGRAM_COUNT=2
export OM_PROGRAM_0_RECIPIENT=0x...
export OM_PROGRAM_0_BPS=7000
export OM_PROGRAM_0_URI=ipfs://program0
export OM_PROGRAM_0_ACTIVE=true
export OM_PROGRAM_1_RECIPIENT=0x...
export OM_PROGRAM_1_BPS=3000
export OM_PROGRAM_1_URI=ipfs://program1
export OM_PROGRAM_1_ACTIVE=true
```

### 2. Run Foundry Script
```bash
cd smart_contracts
forge script script/DeployOctantMini.s.sol \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify # optional
```
The script:
1. Deploys a mock ERC20 (18 decimals) if `OM_ASSET` is unset.
2. Deploys `FundingRouter`, `OctantMiniVault`, and `AaveYieldDonatingStrategy`.
3. Wires the vault to the router/strategy automatically.
4. Mints `OM_INITIAL_MINT` tokens to `OM_ADMIN` when using the mock asset (default 1M tokens).

All addresses are printed to stdout for record keeping.

### 3. Configure Router Programs
- Preferred: populate the `OM_PROGRAM_*` env vars (see above) before running the script.
- Alternative: use `cast` or a multisig to add programs and set allocations manually:
  ```bash
  cast send <ROUTER> "addProgram((address,uint16,string,bool))" \
    "([<recipient>,<bps>,\"ipfs://...\",true])" --rpc-url $RPC_URL --private-key $PRIVATE_KEY
  ```

### 4. Deposits / Strategy Funding
1. Approve the vault for the asset.
2. Call `deposit`.
3. Call `forwardToStrategy` from a strategist role, then `deployFunds` on the strategy keeper.

> Shortcut: use `./smart_contracts/scripts/run-full-flow.sh` with the deployed addresses, RPC URL, and keeper key to run a full drill (mint → deposit → forward → deploy → harvest → route) on Sepolia.

### 5. Harvest & Route
1. Keeper runs `harvestAndReport`.
2. Router keeper calls `route()` to fan out yield.

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
1. Deposit USDC → shares minted.  
2. Trigger `harvestAndReport()` manually.  
3. Confirm router receives yield.  
4. Call `route()` → verify recipient balances.  
5. Validate events in Etherscan.
