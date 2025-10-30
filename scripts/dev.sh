#!/bin/bash

set -e

# Test if anvil is running on port 8545
if ! nc -z localhost 8545; then
  echo "Anvil is not running"
  exit 1
fi

# Deploy the signals token factory to the development network
#
#   Requires:
#     - a local anvil instance running on port 8545
#     - the LOCAL_RPC environment variable set
cd apps/signals-token-factory

# # --- Create the token factory ---
forge script script/DeployFactory.s.sol:DeployFactory \
     --rpc-url $ANVIL_RPC \
     --broadcast \
     --private-key $ANVIL_DEPLOYER_PRIVATE_KEY \
     -s "run(string)" \
     "anvil"

# --- Deploy the signals token for the experiment ---
forge script script/DeployFactoryToken.s.sol:DeployFactoryToken \
     --rpc-url $ANVIL_RPC \
     --broadcast \
     --private-key $ANVIL_DEPLOYER_PRIVATE_KEY \
     -s "run(string,address,string,string,uint256,address,address)" \
     "anvil" \
     "0x5FbDB2315678afecb367f032d93F642f64180aa3" \
     "Signals Edge Experiment" \
     "SIG-INT" \
     "0" \
     "0x0000000000000000000000000000000000000000" \
     "0x0000000000000000000000000000000000000000"

cd ../..

# Create a Signals Board
cd apps/protocol
forge clean && forge install

# Create a Signals Factory
forge script script/DeployFactory.s.sol:DeployFactory \
    --rpc-url $ANVIL_RPC \
    --broadcast \
    --private-key $ANVIL_DEPLOYER_PRIVATE_KEY \
    -s "run(string)" \
    "anvil"

# Create a Signals Board with an underlying token
forge script script/CreateBoard.s.sol:CreateBoard \
    --rpc-url $ANVIL_RPC \
    --broadcast \
    --private-key $ANVIL_DEPLOYER_PRIVATE_KEY \
    -s "run(string,string)" \
    "anvil" \
    "0xa16E02E87b7454126E5E10d957A927A7F5B5d2be"

cd ../..


# # Create Signals test data
# #
# #  - This script creates three initiatives, with minimum support amounts and a 12 month lock duration
# cd apps/protocol
# forge script script/TestData.s.sol --fork-url $LOCAL_RPC --broadcast --private-key $LOCAL_DEPLOYER_PRIVATE_KEY
# cd ../..
