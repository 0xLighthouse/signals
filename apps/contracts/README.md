# Contracts

## Getting Started

We use Foundry to build and test our smart contracts. Get it here:

https://getfoundry.sh/

* Copy `.envrc.example` to `.envrc` and set the correct environment variables

Smart contract source code can be found in the `src` folder.

## Local development

This allows experimenting with the contracts locally.

* Grab `DEPLOYER_TESTNET_PRIVATE_KEY` from the anvil console

```shell
# Start a local development node
anvil --mnemonic $DEPLOYER_TESTNET_SEED_PHRASE 

# Setup Contracts
forge script script/Development.s.sol --fork-url $LOCAL_RPC --broadcast --private-key $DEPLOYER_TESTNET_PRIVATE_KEY
```

### Tests

Our tests are located in the `src/__tests__` directory. Once you've installed Foundry, you can run the unit tests by navigating to the `contracts` directory and calling:

```shell
forge test
```

### Deploy

```shell
forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

