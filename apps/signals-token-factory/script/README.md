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

1. `network` - Network label matching the configured deployer key (e.g., `anvil`, `base-sepolia`)
2. `factoryAddress` - Address of the deployed `ExperimentTokenFactory`
3. `name` - Token name (e.g., "My Token")
4. `symbol` - Token symbol (e.g., "MTK")
5. `initialSupply` - Initial token supply in wei (use `0` for none)
6. `owner` - Token owner address (use `0x0000000000000000000000000000000000000000` to default to the broadcaster)
7. `allowanceSigner` - Optional allowance signer (use `0x000…000` to default to the owner)

**Example:**

```sh
forge script script/DeployFactoryToken.s.sol:DeployFactoryToken \
    --rpc-url $LOCAL_RPC \
    --broadcast \
    --private-key $TESTNET_DEPLOYER_PRIVATE_KEY \
    -s "run(string,address,string,string,uint256,address,address)" \
    "anvil" \
    "0xD00B87df994b17a27aBA4f04c7A7D77bE3b95e10" \
    "Test Token" \
    "TEST" \
    "0" \
    "0x0000000000000000000000000000000000000000" \
    "0x0000000000000000000000000000000000000000"
```

## Manage Allowance Signer

Use `SetAllowanceSigner` to rotate the off-chain signer key:

```sh
forge script script/ExperimentOwner.s.sol:SetAllowanceSigner \
    --rpc-url $BASE_SEPOLIA_RPC \
    --broadcast \
    --private-key $TESTNET_DEPLOYER_PRIVATE_KEY \
    -s "run(string,address,address)" \
    "base-sepolia" \
    "0xYourTokenAddress" \
    "0xNewAllowanceSigner"
```
