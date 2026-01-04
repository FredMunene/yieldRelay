#!/usr/bin/env bash
set -euo pipefail

# Usage example (YieldRelay mock deployment):
#   ./smart_contracts/scripts/run-full-flow.sh \
#       --vault 0x... \
#       --router 0x... \
#       --registry 0x... \
#       --asset 0x... \
#       --rpc https://sepolia.infura.io/v3/<key> \
#       --pk $PRIVATE_KEY \
#       --holder 0x... \
#       --amount 5000000 \
#       --beneficiaries '["0x...","0x..."]' \
#       --bps "[6000,4000]" \
#       --skip-mint
#
# Flags:
#   --holder <address>     Explicit holder (defaults to signer derived from --pk)
#   --amount <wei>         Amount to deposit/forward (default 5e18)
#   --mint-amount <wei>    Amount to mint when using mock asset (default 1e19)
#   --beneficiaries <json> JSON array of beneficiary addresses
#   --bps <json>           JSON array of uint16 bps (must sum to 10_000)
#   --skip-mint            Skip minting (when using a real asset)
#   --simulate-yield <wei> Mint mock aTokens to the vault (only works with MockAToken)
#   --atoken <address>     Required when using --simulate-yield
#
# The script mints (if enabled), approves, deposits into the vault, optionally simulates
# yield, allocates yield, then claims to each beneficiary.
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
        --registry) REGISTRY="$2"; shift 2 ;;
        --asset) ASSET="$2"; shift 2 ;;
        --rpc) RPC="$2"; shift 2 ;;
        --pk) PK="$2"; shift 2 ;;
        --holder) HOLDER="$2"; shift 2 ;;
        --amount) AMOUNT_WEI="$2"; shift 2 ;;
        --mint-amount) MINT_AMOUNT="$2"; shift 2 ;;
        --beneficiaries) BENEFICIARIES="$2"; shift 2 ;;
        --bps) BPS="$2"; shift 2 ;;
        --simulate-yield) SIM_YIELD="$2"; shift 2 ;;
        --atoken) ATOKEN="$2"; shift 2 ;;
        --skip-mint) MINT=false; shift ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
    esac
done

: "${VAULT:?missing --vault}"
: "${ROUTER:?missing --router}"
: "${REGISTRY:?missing --registry}"
: "${ASSET:?missing --asset}"
: "${RPC:?missing --rpc}"
: "${PK:?missing --pk}"
: "${BENEFICIARIES:?missing --beneficiaries}"
: "${BPS:?missing --bps}"

HOLDER="${HOLDER:-$(cast wallet address --private-key "$PK")}"

BENEFICIARIES_JSON=$(python3 - <<'PY'
import json, os

raw = os.environ.get("BENEFICIARIES", "").strip()
if not raw:
    print("[]")
    raise SystemExit

if '"' in raw:
    print(raw)
    raise SystemExit

if raw.startswith("[") and raw.endswith("]"):
    inner = raw[1:-1].strip()
    if not inner:
        print("[]")
        raise SystemExit
    arr = [item.strip() for item in inner.split(",") if item.strip()]
    print(json.dumps(arr))
    raise SystemExit

print(json.dumps([raw]))
PY
)

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

cast send "$VAULT" "deposit(uint256,address[],uint16[])" "$AMOUNT_WEI" \
    "$BENEFICIARIES" "$BPS" \
    --private-key "$PK" --rpc-url "$RPC"

# Optional: simulate yield with MockAToken forceMint (mock-only)
if [[ -n "${SIM_YIELD:-}" ]]; then
    : "${ATOKEN:?missing --atoken for --simulate-yield}"
    echo "Simulating yield by minting $SIM_YIELD aTokens to vault (mock only)."
    cast send "$ATOKEN" "forceMint(address,uint256)" "$VAULT" "$SIM_YIELD" \
        --private-key "$PK" --rpc-url "$RPC"
fi

# Allocate yield for depositor and report claimable for each beneficiary
cast send "$VAULT" "allocateYield(address)" "$HOLDER" \
    --private-key "$PK" --rpc-url "$RPC"

export BENEFICIARIES
export BENEFICIARIES_JSON
export ROUTER
export RPC

python3 - <<'PY'
import json, os, subprocess

beneficiaries = json.loads(os.environ.get("BENEFICIARIES_JSON", "[]"))
router = os.environ["ROUTER"]
rpc = os.environ["RPC"]

for b in beneficiaries:
    output = subprocess.check_output(
        ["cast", "call", router, "claimable(address)(uint256)", b, "--rpc-url", rpc],
        text=True,
    ).strip()
    print(f"Claimable for {b}: {output}")
PY

echo "End-to-end flow executed."
