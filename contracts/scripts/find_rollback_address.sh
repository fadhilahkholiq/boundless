#!/usr/bin/env bash

set -euo pipefail

# Usage check
if [[ -z "$1" ]]; then
  echo "Usage: $0 <PROXY_ADDRESS>"
  exit 1
fi

# Config
PROXY_ADDRESS="$1"
SLOT="0x360894A13BA1A3210667C828492DB98DCA3E2076CC3735A920A3CA505D382BBC" # EIP-1967 slot
RPC_URL="${RPC_URL}"
DAYS_BACK=7
AVG_BLOCK_TIME=2

# Determine OS for date formatting
platform=$(uname)
if [[ "$platform" == "Darwin" ]]; then
  # macOS
  format_date() { date -r "$1" "+%Y-%m-%d"; }
else
  # Linux
  format_date() { date -d "@$1" "+%Y-%m-%d"; }
fi

# Get current implementation
CURRENT_RAW=$(cast storage "$PROXY_ADDRESS" "$SLOT" --rpc-url "$RPC_URL")
CURRENT_IMPL="0x${CURRENT_RAW:26}"
echo "Current implementation: $CURRENT_IMPL"

LATEST_BLOCK=$(cast block-number --rpc-url "$RPC_URL")
LATEST_TS=$(cast block "$LATEST_BLOCK" --json --rpc-url "$RPC_URL" | jq -r .timestamp)

for ((i=1; i<=DAYS_BACK; i++)); do
  TARGET_TS=$((LATEST_TS - i * 86400))
  DELTA_SECS=$((LATEST_TS - TARGET_TS))
  BLOCK_DELTA=$((DELTA_SECS / AVG_BLOCK_TIME))
  APPROX_BLOCK=$((LATEST_BLOCK - BLOCK_DELTA))
  DATE_STR=$(format_date "$TARGET_TS")

  VALUE=$(cast storage "$PROXY_ADDRESS" "$SLOT" --block "$APPROX_BLOCK" --rpc-url "$RPC_URL" 2>/dev/null || true)
  [[ -z "$VALUE" ]] && { echo "[$DATE_STR] Could not fetch storage at block $APPROX_BLOCK"; continue; }

  IMPL="0x${VALUE:26}"

  if [[ "$IMPL" != "$CURRENT_IMPL" ]]; then
    echo "[$DATE_STR] Block $APPROX_BLOCK: Implementation was $IMPL"
  fi
done