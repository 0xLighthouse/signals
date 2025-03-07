# Bond Hook

A Uniswap v4 hook for creating bond markets.

## Features

- LPs can provide single-sided liquidity to a bond market
- Bonds can be sold into the pool
- Bonds can be purchased from the pool
- LPs can claim their profits

## Integration with Signals

To integrate this library with the Signals project, add it as a dependency in your Foundry project:

```bash
# Add the bond-hook as a dependency
forge install lighthouse-cx/signals-poc/apps/bond-hook

# Import in your Solidity files
import {BondHook, DesiredCurrency, SwapData} from "bond-hook/BondHook.sol";
import {IBondPricing} from "bond-hook/interfaces/IBondPricing.sol";
import {ExampleLinearPricing} from "bond-hook/pricing/ExampleLinearPricing.sol";
```

## Project Structure

- `src/BondHook.sol` - Main hook implementation for bond markets
- `src/PipsLib.sol` - Helper library for price manipulation
- `src/interfaces/` - Contains interface definitions
  - `IBondIssuer.sol` - Interface for bond issuing contracts
  - `IBondPricing.sol` - Interface for bond pricing strategies
- `src/pricing/` - Contains bond pricing implementations
  - `ExampleLinearPricing.sol` - Linear pricing model for bonds

## Development

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

## Documentation

For more information on Foundry:
https://book.getfoundry.sh/
