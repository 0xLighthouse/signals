#!/bin/bash
set -e

# Check required environment variables
for var in TESTNET_RPC TESTNET_DEPLOYER_PRIVATE_KEY TESTNET_SEED_PHRASE TESTNET_BOND_ISSUER; do
  if [ -z "${!var}" ]; then
    echo "A [$var] environment variable is required"
    exit 1
  fi
done

# Create a new Signals deployment to testnet (Arbitrum Sepolia)
# cd apps/signals
# forge clean && forge install
# forge script script/Testnet.s.sol \
#   --fork-url $TESTNET_RPC \
#   --broadcast \
#   --private-key $TESTNET_DEPLOYER_PRIVATE_KEY \
#   --verify \
#   --etherscan-api-key $ARBISCAN_API_KEY
# cd ../..
# echo "Update the TESTNET_BOND_ISSUER environment variable with the address of the BondIssuer contract"
# exit 0

# Deploy a new version of the BondHook contract to testnet (Arbitrum Sepolia)
# cd apps/bond-hook
# forge clean && forge install
# forge script script/Testnet.sol \
#   --fork-url $TESTNET_RPC \
#   --broadcast \
#   --private-key $TESTNET_DEPLOYER_PRIVATE_KEY \
#   --verify \
#   --etherscan-api-key $ARBISCAN_API_KEY
# cd ../..

# Create Signals test data
#  - This script creates three initiatives, with minimum support amounts and a 12 month lock duration
# cd apps/signals
# forge script script/TestnetData.s.sol --fork-url $TESTNET_RPC --broadcast --private-key $TESTNET_DEPLOYER_PRIVATE_KEY
# cd ../..

# Deploy testnet pools
cd apps/bond-hook
forge script script/TestnetPools.sol --fork-url $TESTNET_RPC --broadcast --private-key $TESTNET_DEPLOYER_PRIVATE_KEY
cd ../..
