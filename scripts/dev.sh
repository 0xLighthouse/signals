#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.envrc"

if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
else
  echo "Missing environment configuration at ${ENV_FILE}" >&2
  exit 1
fi

cd "${ROOT_DIR}"

: "${ANVIL_RPC:?ANVIL_RPC is not set.}"
: "${ANVIL_DEPLOYER_PRIVATE_KEY:?ANVIL_DEPLOYER_PRIVATE_KEY is not set.}"

strip_ansi() {
  sed -E 's/\x1b\[[0-9;]*m//g'
}

run_and_capture() {
  local __resultvar=$1
  shift

  local tmp
  tmp=$(mktemp)

  set +e
  "$@" 2>&1 | tee "$tmp"
  local status=${PIPESTATUS[0]}
  set -e

  local output
  output=$(cat "$tmp")
  rm -f "$tmp"

  eval "$__resultvar=\"\$output\""

  if [[ $status -ne 0 ]]; then
    echo "Command failed: $*" >&2
    exit $status
  fi
}

# Test if anvil is running on port 8545
if ! nc -z localhost 8545; then
  echo "Anvil is not running"
  exit 1
fi

# Deploy the signals token factory to the development network
cd apps/signals-token-factory

TOKEN_NAME=${TOKEN_NAME:-"Signals Edge Experiment"}
TOKEN_SYMBOL=${TOKEN_SYMBOL:-"SIG-INT"}
TOKEN_INITIAL_SUPPLY=${TOKEN_INITIAL_SUPPLY:-0}
TOKEN_OWNER=${TOKEN_OWNER:-"0x0000000000000000000000000000000000000000"}
TOKEN_ALLOWANCE_SIGNER=${TOKEN_ALLOWANCE_SIGNER:-"0x0000000000000000000000000000000000000000"}

echo "Deploying ExperimentTokenFactory..."
run_and_capture token_factory_output \
  forge script script/DeployFactory.s.sol:DeployFactory \
    --rpc-url "$ANVIL_RPC" \
    --broadcast \
    --private-key "$ANVIL_DEPLOYER_PRIVATE_KEY" \
    -s "run(string)" \
    "anvil"

token_factory_address=$(printf '%s\n' "$token_factory_output" | strip_ansi | awk -F': ' '/Factory deployed at/ {print $2}' | tr -d '[:space:]')
if [[ -z "$token_factory_address" ]]; then
  echo "Failed to determine ExperimentTokenFactory address" >&2
  exit 1
fi
echo "ExperimentTokenFactory: $token_factory_address"

echo "Deploying ExperimentToken..."
run_and_capture token_output \
  forge script script/DeployFactoryToken.s.sol:DeployFactoryToken \
    --rpc-url "$ANVIL_RPC" \
    --broadcast \
    --private-key "$ANVIL_DEPLOYER_PRIVATE_KEY" \
    -s "run(string,address,string,string,uint256,address,address)" \
    "anvil" \
    "$token_factory_address" \
    "$TOKEN_NAME" \
    "$TOKEN_SYMBOL" \
    "$TOKEN_INITIAL_SUPPLY" \
    "$TOKEN_OWNER" \
    "$TOKEN_ALLOWANCE_SIGNER"

token_address=$(printf '%s\n' "$token_output" | strip_ansi | awk -F': ' '/ExperimentToken deployed at/ {print $2}' | tr -d '[:space:]')
if [[ -z "$token_address" ]]; then
  echo "Failed to determine ExperimentToken address" >&2
  exit 1
fi
echo "ExperimentToken: $token_address"

cd ../..

# Create a Signals Board
cd apps/protocol
forge clean && forge install

echo "Deploying SignalsFactory..."
run_and_capture signals_factory_output \
  forge script script/CreateFactory.s.sol:CreateFactory \
    --rpc-url "$ANVIL_RPC" \
    --broadcast \
    --private-key "$ANVIL_DEPLOYER_PRIVATE_KEY" \
    -s "run(string)" \
    "anvil"

signals_factory_address=$(printf '%s\n' "$signals_factory_output" | strip_ansi | awk '/FactoryContract/ {print $2}' | tr -d '[:space:]')
if [[ -z "$signals_factory_address" ]]; then
  echo "Failed to determine SignalsFactory address" >&2
  exit 1
fi
echo "SignalsFactory: $signals_factory_address"

echo "Creating Signals board..."
run_and_capture board_output \
  forge script script/CreateBoard.s.sol:CreateBoard \
    --rpc-url "$ANVIL_RPC" \
    --broadcast \
    --private-key "$ANVIL_DEPLOYER_PRIVATE_KEY" \
    -s "run(string,address,address)" \
    "anvil" \
    "$signals_factory_address" \
    "$token_address"

board_address=$(printf '%s\n' "$board_output" | strip_ansi | awk '/SignalsContract/ {print $2}' | tr -d '[:space:]')
if [[ -z "$board_address" ]]; then
  echo "Failed to determine Signals board address" >&2
  exit 1
fi
echo "Signals board: $board_address"

echo "Seeding test initiatives..."
run_and_capture seed_output \
  forge script script/TestnetData.s.sol:SeedInitiativesScript \
    --rpc-url "$ANVIL_RPC" \
    --broadcast \
    --private-key "$ANVIL_DEPLOYER_PRIVATE_KEY" \
    -s "run(string,address)" \
    "anvil" \
    "$board_address"

cd ../..

echo
echo "=== Deployment summary ==="
echo "ExperimentTokenFactory: $token_factory_address"
echo "ExperimentToken:        $token_address"
echo "SignalsFactory:         $signals_factory_address"
echo "Signals board:          $board_address"
