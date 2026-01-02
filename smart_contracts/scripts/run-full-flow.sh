#!/usr/bin/env bash
set -euo pipefail

# Usage example (Sepolia mock deployment):
#   ./smart_contracts/scripts/run-full-flow.sh \
#       --vault 0xE1a3D049300BC36c448f5530C8efbA0Ec9E3Be27 \
#       --router 0x4331c7Df086A7711D9a80701A4bCc1C167aF3bdf \
#       --strategy 0x8B588D1bBb680b82d1dCF88D847Aa8cF63c44600 \
#       --asset 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8 \
#       --rpc https://sepolia.infura.io/v3/<key> \
#       --pk $PRIVATE_KEY
#       --holder 0x42772299247add126151ade909e36a8f4975437e \
#       --amount 5000000 \
#       --skip-mint
#
# Flags:
#   --holder <address>     Explicit holder (defaults to signer derived from --pk)
#   --amount <wei>         Amount to deposit/forward (default 5e18)
#   --mint-amount <wei>    Amount to mint when using mock asset (default 1e19)
#   --skip-mint            Skip minting (when using a real asset)
#
# The script mints (if enabled), approves, deposits into the vault, forwards only available
# liquidity, deploys whatever the strategy holds, then calls harvest + route.
AMOUNT_WEI=5000000000000000000 # 5 tokens at 18 decimals
MINT=true
MINT_AMOUNT=10000000000000000000

parse_uint() {
    local raw="${1//$'\n'/}"
    raw="${raw%% *}"
    if [[ "$raw" =~ ^0x[0-9a-fA-F]+$ ]]; then
        cast to-dec "$raw"
        return
    fi
    if [[ "$raw" =~ ^[0-9]+$ ]]; then
        echo "$raw"
        return
    fi
    echo "0"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --vault) VAULT="$2"; shift 2 ;;
        --router) ROUTER="$2"; shift 2 ;;
        --strategy) STRATEGY="$2"; shift 2 ;;
        --asset) ASSET="$2"; shift 2 ;;
        --rpc) RPC="$2"; shift 2 ;;
        --pk) PK="$2"; shift 2 ;;
        --holder) HOLDER="$2"; shift 2 ;;
        --amount) AMOUNT_WEI="$2"; shift 2 ;;
        --mint-amount) MINT_AMOUNT="$2"; shift 2 ;;
        --skip-mint) MINT=false; shift ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
    esac
done

: "${VAULT:?missing --vault}"
: "${ROUTER:?missing --router}"
: "${STRATEGY:?missing --strategy}"
: "${ASSET:?missing --asset}"
: "${RPC:?missing --rpc}"
: "${PK:?missing --pk}"

HOLDER="${HOLDER:-$(cast wallet address --private-key "$PK")}"

echo "Using holder $HOLDER"
echo "Operating amount (wei): $AMOUNT_WEI"

# Mint mock tokens if requested (default true, works with MockERC20 deployment)
if [[ "$MINT" == "true" ]]; then
    echo "Minting $MINT_AMOUNT wei of asset to $HOLDER"
    cast send "$ASSET" "mint(address,uint256)" "$HOLDER" "$MINT_AMOUNT" \
        --private-key "$PK" --rpc-url "$RPC" || true
fi

# Approve & deposit
cast send "$ASSET" "approve(address,uint256)" "$VAULT" "$AMOUNT_WEI" \
    --private-key "$PK" --rpc-url "$RPC"

cast send "$VAULT" "deposit(uint256,address)" "$AMOUNT_WEI" "$HOLDER" \
    --private-key "$PK" --rpc-url "$RPC"

# Determine available liquidity before forwarding
available_raw=$(cast call "$VAULT" "availableLiquidity()(uint256)" --rpc-url "$RPC" 2>/dev/null || echo "0")
available_dec=$(parse_uint "$available_raw")
if [[ "$available_dec" -lt "$AMOUNT_WEI" ]]; then
    echo "Requested amount exceeds available liquidity ($available_dec), reducing forward amount."
    FORWARD_AMOUNT="$available_dec"
else
    FORWARD_AMOUNT="$AMOUNT_WEI"
fi

if [[ "$FORWARD_AMOUNT" == "0" ]]; then
    echo "No liquidity available to forward; aborting."
    exit 1
fi

cast send "$VAULT" "forwardToStrategy(uint256)" "$FORWARD_AMOUNT" \
    --private-key "$PK" --rpc-url "$RPC"

# Deploy only what the strategy currently holds
strategy_balance_raw=$(cast call "$ASSET" "balanceOf(address)(uint256)" "$STRATEGY" --rpc-url "$RPC" 2>/dev/null || echo "0")
strategy_balance_dec=$(parse_uint "$strategy_balance_raw")
DEPLOY_AMOUNT="$strategy_balance_dec"
if [[ "$DEPLOY_AMOUNT" == "0" ]]; then
    echo "Strategy holds zero balance after forwarding; aborting."
    exit 1
fi

cast send "$STRATEGY" "deployFunds(uint256)" "$DEPLOY_AMOUNT" \
    --private-key "$PK" --rpc-url "$RPC"

# Trigger harvest (profit/loss calculation) and routing
cast send "$STRATEGY" "harvestAndReport()" \
    --private-key "$PK" --rpc-url "$RPC"

cast send "$ROUTER" "route()" \
    --private-key "$PK" --rpc-url "$RPC"

echo "End-to-end flow executed."
