# Contracts

## TODO

- [ ] Use X96 for math

## Getting Started

We use Foundry to build and test our smart contracts. Get it here:

<https://getfoundry.sh/>

- Copy `.envrc.example` to `.envrc` and set the correct environment variables

Smart contract source code can be found in the `src` folder.

## Local development

This allows experimenting with the contracts locally.

- Grab `DEPLOYER_TESTNET_PRIVATE_KEY` from the anvil console

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

#### Test specific file with args

```shell
forge test <file> -vvvv
```

### Deploy

```shell
forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

#### Deploying a new contract

To aid in the deployment of new contracts (to create a new space), we have created a factory contract which will deploy the contract for you. Simply call the `create` method and provide the required default parameters (most can be changed by the owner after deployment):

**owner:** The address that will own the new contract
**underlyingToken:** The address of the governance token that will be used for lockups
**proposalThreshold:** The minimum token balance required in order to submit an initiative
**acceptanceThreshold:** How much support an initiative must have before it can be accepted
**lockDurationCap:** The maximum duration that funds can be locked (specified in interval)
**proposalCap:** The maximum number of proposals
**lockInterval:** The duration of one lock interval, in seconds
**decayCurveType:** Decay curve type (see below)
**decayCurveParameters:** Decay curve parameters (see below)

### Interacting with the contract

Once the contract is deploywed, the following public methods are available:

| Method | Returns | Description |
|--------|---------|-------------|
 | supportInitiative(uint256 initiativeId, uint256 amount, uint256 lockDuration) | | Lock up tokens in support of an existing initiative |
 | acceptInitiative(uint256 initiativeId) | | Once an initiative has received enough support, accept the initiative (owner only for now) |
 | expireInitiative(uint256 initiativeId) | | Once an initiative has been inactive for a long enough time, expire the initiative (owner only for now) |
 | withdrawTokens(uint256 initiativeId) | | Submit an initiative ID, and any tokens the sender has locked up for that initiative which are now free for withdrawal will be withdrawn |
 | withdrawAllTokens() | | For all initiatives, tokens the sender has locked up for that initiative which are now free for withdrawal will be withdrawn |
 | getInitiative(uint256 initiativeId) | Initiative struct | Metadata for the specified initative (title, body, created date, etc) |
 | getSupporters(uint256 initiativeId) | List of addresses | Returns a list of all addresses which have supported this initiative |
 | getWeight(uint256 initiativeId) | uint256 | Returns the current weight of the specified initiative |
 | token() | Address | Returns the contract address of the ERC20 token being used by the lockups |
 | totalInitiatives() | uint256 | Returns the total number of initiatives that have been submitted |
 | totalSupporters(uint256 initiativeId) | uint256 | Returns the total number of supporters for the specified initiative |
 | setInactivityThreshold(uint256 newThreshold) | | Allows the owner to update the inactivity threshold (default: 60 days) |
 | setDecayCurve(uint256 decayCurveType, uint256[]  decayCurveParameters) | | Allows the owner to update the decay curve and parameters (see below) |

### Decay curves

The owner of the contract can specify what kind of decay curve is used to determine the rate at which lockup bonuses decay. There are two components to this setting:

- The curve type: uint256
- The curve parameters: uint256[]

The `curve type` indicates one of the provided curves. Currently we only provide type 0 (linear) and type 1 (exponential). More curves can be added in the future.

The `curve parameters` is an array of integers which contain the values needed to customize the behavior of the curve. Currently, both provided curves only take one value, but future curves could require multiple values which is why we accept an array.

All curve parameters which are meant to be fractional/decimal are expected to be provided as an integer with 1e18 representing 1.0. 9e17 would therefore be 0.9, 11e18 would be 1.1, etc.

#### Linear

Curve type: `0`
Curve parameters: `[x]`
`x`: A multiplier to shape the angle of the curve. A default value of `1.0` (1e18) means the weight will decay at a linear rate, proportional to the length of the lockup. E.g. a lock up of 20 periods will lose 1/20th of its weight each period. A multiplier of 1.1 would see the weight decay slightly faster, losing 11/200ths each period.

#### Exponential

Curve type: `1`
Curve parameters: `[x]`
`x`: A multiplier to shape the angle of the curve. A default value of `0.9` (9e17) means the weight will decay at an exponential rate, with the weight as of the previous period being multiplied by 0.9 for the next period.
