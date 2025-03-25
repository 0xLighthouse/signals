#!/bin/bash

set -e

# Check required environment variables
for var in TESTNET_RPC TESTNET_DEPLOYER_PRIVATE_KEY TESTNET_SEED_PHRASE BOND_ISSUER; do
  if [ -z "${!var}" ]; then
    echo "A [$var] environment variable is required"
    exit 1
  fi
done

# Deploy the signals contract to the development network
#
#   Requires:
#     - a local anvil instance running on port 8545
#     - the LOCAL_RPC environment variable set
# cd apps/signals
# forge clean && forge install
# forge script script/Testnet.s.sol --fork-url $TESTNET_RPC --broadcast --private-key $TESTNET_DEPLOYER_PRIVATE_KEY --verify
# cd ../..

# Deploy our hook to testnet
#
#   Requires:
#     - a local anvil instance running on port 8545
#     - the BOND_ISSUER environment variable set
cd apps/bond-hook
forge clean && forge install
forge script script/Testnet.sol --fork-url $TESTNET_RPC --broadcast --private-key $TESTNET_DEPLOYER_PRIVATE_KEY --verify
cd ../..

# Create Signals test data
#
#  - This script creates three initiatives, with minimum support amounts and a 12 month lock duration
# cd apps/signals
# forge script script/TestData.s.sol --fork-url $LOCAL_RPC --broadcast --private-key $LOCAL_DEPLOYER_PRIVATE_KEY
# cd ../..
