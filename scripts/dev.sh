#!/bin/bash

set -euo pipefail

CLEAN=false

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

extract_script_output() {
  printf '%s\n' "$1" | sed -E 's/\x1b\[[0-9;]*m//g' | awk -F': ' '/ScriptOutput/ {print $2}' | tr -d '[:space:]'
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

  if [[ $status -ne 0 ]]; then
    echo "Command failed: $*" >&2
    exit $status
  fi

  local script_output=""
  script_output=$(extract_script_output "$output")
  if [[ -z "${script_output}" ]]; then
    echo "Failed to determine script output" >&2
    exit 1
  fi

  printf -v "$__resultvar" '%s' "$script_output"
}

# Test if anvil is running on port 8545
if ! nc -z localhost 8545; then
  echo "Anvil is not running"
  exit 1
fi

#####################
#   Set up environment variables
#####################

ANVIL_RPC=${ANVIL_RPC:-"http://localhost:8545"}

export ANVIL_DEPLOYER_PRIVATE_KEY=${ANVIL_DEPLOYER_PRIVATE_KEY:-"0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"}
export ANVIL_SIGNER_PRIVATE_KEY=${ANVIL_SIGNER_PRIVATE_KEY:-"0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"}
export ANVIL_ALICE_PRIVATE_KEY=${ANVIL_ALICE_PRIVATE_KEY:-"0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"}
export ANVIL_BOB_PRIVATE_KEY=${ANVIL_BOB_PRIVATE_KEY:-"0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"}
export ANVIL_CHARLIE_PRIVATE_KEY=${ANVIL_CHARLIE_PRIVATE_KEY:-"0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a"}

# TODO: Use correct addresses for [alice, bob, charlie]
export ANVIL_ADDRESS_ALICE="0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"
export ANVIL_ADDRESS_BOB="0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"
export ANVIL_ADDRESS_CHARLIE="0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65"

cd apps/signals-token-factory
#forge clean && forge install

#####################
#   Deploy Experiment Token Factory
#####################

echo "Deploying Experiment Token Factory..."
run_and_capture token_factory_address \
  forge script script/DeployTokenFactory.s.sol:DeployTokenFactory \
    --rpc-url "$ANVIL_RPC" \
    --broadcast \
    -s "run(string)" \
    "anvil"

#####################
#   Deploy Experiment Token
#####################

TOKEN_NAME=${TOKEN_NAME:-"Signals Edge Experiment"}
TOKEN_SYMBOL=${TOKEN_SYMBOL:-"SIG-INT"}

echo "Deploying Experiment Token..."
run_and_capture token_address \
  forge script script/DeployTokenFromFactory.s.sol:DeployTokenFromFactory \
    --rpc-url "$ANVIL_RPC" \
    --broadcast \
    -s "run(string,address,string,string)" \
    "anvil" \
    "$token_factory_address" \
    "$TOKEN_NAME" \
    "$TOKEN_SYMBOL"

# #####################
# #   Issue test tokens to Alice, Bob, and Charlie
# #####################

echo "Issuing test tokens..."
run_and_capture issue_test_tokens_output \
  forge script script/IssueTestTokens.s.sol:IssueTestTokens \
    --rpc-url "$ANVIL_RPC" \
    --broadcast \
    -s "run(string,string,address,string[])" \
    "anvil" \
    "deployer" \
    "$token_address" \
    "[\"alice\", \"bob\", \"charlie\"]" \

cd ../..

# #####################
# #   Deploy Signals Factory
# #####################

cd apps/protocol
#forge clean && forge install

echo "Deploying Signals Factory..."
run_and_capture signals_factory_address \
  forge script script/DeploySignalsFactory.s.sol:DeploySignalsFactory \
    --rpc-url "$ANVIL_RPC" \
    --broadcast \
    -s "run(string)" \
    "anvil"


# #####################
# #   Deploy Signals Board
# #####################

echo "Deploying Signals board..."
run_and_capture board_address \
  forge script script/DeploySignalsBoardFromFactory.s.sol:DeploySignalsBoardFromFactory \
    --rpc-url "$ANVIL_RPC" \
    --broadcast \
    -s "run(string,address,address)" \
    "anvil" \
    "$signals_factory_address" \
    "$token_address"


# #####################
# #   Seed test initiatives
# #####################

echo "Seeding test initiatives..."
run_and_capture seed_initiatives_output \
  forge script script/TestnetData.s.sol:SeedInitiativesScript \
    --rpc-url "$ANVIL_RPC" \
    --broadcast \
    -s "run(string,address)" \
    "anvil" \
    "$board_address"

cd ../..

echo
echo "=== Deployment summary ==="
echo "ExperimentTokenFactory: $token_factory_address"
echo "ExperimentToken:        $token_address"
echo "Issue test tokens:      $issue_test_tokens_output"
echo "SignalsFactory:         $signals_factory_address"
echo "Signals board:          $board_address"
echo "Seed initiatives:       $seed_initiatives_output"
