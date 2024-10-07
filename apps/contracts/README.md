## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

```shell
forge install OpenZeppelin/openzeppelin-contracts@v4.8.3 --no-commit
forge install transmissions11/solmate --no-commit
forge install vectorized/solady --no-commit
```

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Local Development

```shell
# Local Development Node
anvil --mnemonic $DEPLOYER_TESTNET_SEED_PHRASE --auto-impersonate

# Setup Contracts
forge script script/Development.s.sol --fork-url http://127.0.0.1:8545 --broadcast
forge script script/Development.s.sol --broadcast
```


## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
