#!/bin/bash

set -e

# Test if anvil is running on port 8545
if ! nc -z localhost 8545; then
  echo "Anvil is not running"
  exit 1
fi

# Deploy the signals contract to the development network
#
#   Requires:
#     - a local anvil instance running on port 8545
#     - the LOCAL_RPC environment variable set
cd apps/protocol
forge clean && forge install
forge script script/Development.s.sol --fork-url $LOCAL_RPC --broadcast --private-key $LOCAL_DEPLOYER_PRIVATE_KEY
cd ../..

# Error out if the BOND_ISSUER environment variable is not set
if [ -z "$BOND_ISSUER" ]; then
  echo "A BOND_ISSUER environment variable is required"
  exit 1
fi

# Create Signals test data
#
#  - This script creates three initiatives, with minimum support amounts and a 12 month lock duration
cd apps/protocol
forge script script/TestData.s.sol --fork-url $LOCAL_RPC --broadcast --private-key $LOCAL_DEPLOYER_PRIVATE_KEY
cd ../..
