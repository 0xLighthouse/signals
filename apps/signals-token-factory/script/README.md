# Deployment

## Logs

* Anvil, 0xD00B87df994b17a27aBA4f04c7A7D77bE3b95e10

## Tips

```sh
# Fund local wallet with ETH easily
cast send <0xADDRESS> --value 10ether --rpc-url $LOCAL_RPC --private-key
cast send 0x8DC791f24589F480fF31Fe654D09bD01B5c5c2E8 --value 10ether --rpc-url $LOCAL_RPC --private-key
```

## Latest deplyment info

```sh
ExperimentFactoryAddress: 0x5FbDB2315678afecb367f032d93F642f64180aa3
```

[base-sepolia]

```sh
 forge script script/DeployFactory.s.sol:DeployFactory \
     --rpc-url $BASE_SEPOLIA_RPC \
     --broadcast \
     --private-key $TESTNET_DEPLOYER_PRIVATE_KEY \
     -s "run(string)" \
     "base-sepolia"

 # [anvil]
 forge script script/DeployFactory.s.sol:DeployFactory \
     --rpc-url $ANVIL_RPC \
     --broadcast \
     --private-key $ANVIL_DEPLOYER_PRIVATE_KEY \
     -s "run(string)" \
     "anvil"
```

## Deploy ExperimentToken via Factory

All parameters are passed as script arguments (no environment variables needed except private key).

**Parameters (in order):**

1. `factoryAddress` - Address of the deployed ExperimentTokenFactory
2. `name` - Token name (e.g., "My Token")
3. `symbol` - Token symbol (e.g., "MTK")
4. `merkleRoot` - Allowlist merkle root (bytes32, use `0x0000...` for no allowlist)
5. `baseClaimAmount` - Base claim amount per address in wei
6. `bonusPerClaim` - Bonus amount per claim in wei
7. `initialSupply` - Initial token supply in wei (use `0` for none)
8. `owner` - Token owner address (use `0x0000000000000000000000000000000000000000` for deployer)

**Example:**

```sh
forge script script/DeployToken.s.sol:DeployToken \
    --rpc-url $LOCAL_RPC \
    --broadcast \
    --private-key $TESTNET_DEPLOYER_PRIVATE_KEY \
    -s "run(address,string,string,bytes32,uint256,uint256,uint256,address)" \
    "0xD00B87df994b17a27aBA4f04c7A7D77bE3b95e10" \
    "Test Token" \
    "TEST" \
    "0x0000000000000000000000000000000000000000000000000000000000000000" \
    "1000000000000000000" \
    "100000000000000000" \
    "0" \
    "0x0000000000000000000000000000000000000000"
```
