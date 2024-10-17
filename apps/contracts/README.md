# Contracts

## Getting Started

* Ensure the standard foundry tools are available
* Copy `.envrc.example` to `.envrc` and set the correct environment variables

## Local development

This allows experimenting with the contracts locally.

* Grab `DEPLOYER_TESTNET_PRIVATE_KEY` from the anvil console

```shell
# Start a local development node
anvil --mnemonic $DEPLOYER_TESTNET_SEED_PHRASE 

# Setup Contracts
forge script script/Development.s.sol --fork-url $LOCAL_RPC --broadcast --private-key $DEPLOYER_TESTNET_PRIVATE_KEY
```

### Test

```shell
forge test
```

### Deploy

```shell
forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```
