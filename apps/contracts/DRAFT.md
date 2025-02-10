# Hook design

## Overview

This protocol transforms NFTs issued by the `Signals` contract into digital bond instruments.

Each NFT represents a bond with:

- A Nominal Value (NV)—the guaranteed principal (face value) that will be repaid at maturity.
- A Market Price (MP)—the current trading price, which fluctuates with time until maturity and yield conditions.

## Automated Market Maker (AMM)

We leverage the power of a Uniswap V4 hook to enable intermediaries to create a secondary market for the bonds.

The Hook enables three primary activities:

 1. Bond Redemption (Sell NFT Flow): Bondholders can redeem (sell) their NFTs instantly at market defined price.
 2. Bond Acquisition (Buy NFT Flow): Investors can purchase specific bond-NFTs from the pool.
 3. Liquidity Provision: Liquidity providers deposit USDC (one-sided liquidity) and earn swap fees as the pool continuously reflects the aggregate nominal value of the bonds held.

## Protocol Setup & Core Instruments

The Bonded Governance Token (bGOV)

- Role: The protocol deploys a bespoke ERC20 token—the bGOV token—to serve as the unit of account.
- Denomination: Each unit of bGOV is a whole number representation of the bond-underlying token.

eg. A bonnd of 1000 UNI would be represented as 1000 bUNI.

## Glossary

- `Nominal Value (NV)`:
  - The immutable face value of the bond-NFT, analogous to the principal repaid at maturity.
  - This is the minimum amount guaranteed by the bond, regardless of market fluctuations.
- `Market Price (MP)`:
  - An algorithmic price set by the Hook, determined by factors such as time until maturity and prevailing yield conditions.
  - MP dictates how many bGOV tokens are exchanged in the market when a bond is bought or sold.

## User Actions

### Sell Bond

A bondholder (NFT owner) who wishes to exit their bond before maturity follows this process:

Example:

- A bond with a Nominal Value (NV) of 1000 UNI and a Market Price (MP) of 500 UNI.
- UNI is currenly worth 10 USDC
- The bondholder wants to sell their bond

- Our hook in this instance is attatched to the UNI/USDC pool
- The hook will receive the Bond NFT
- The hook will calculate the amount of bGOV tokens to mint to the bondholder based on the Market Price (MP)

```
// 10 * 500 = 5000 usdc is sent to the user
// NFT is transferred to the hook
// 1000 bUNI is added to the pool
```

### Buy Bond

- An investor who wants to purchase a bond follows this process:

Example:

- An investor may want to acquire the bond
- This hook dynamically sets the Market Price (MP) based on the current price of the underlying asset, using their own formula

```
// Investors sends 10k USDC
// Hook burns 1000 bUNI
// NFT is transferred to the investor
```

### Redeem Bond

- A bond reaches maturity and is redeemed for the Nominal Value (NV)

```
// Bond is redeemed for 1000 UNI
// Any surplus UNI is sent to LPs
// Hook burns 1000 bUNI
```

## Ideas

Everyday LPs can set their own algos for acquiring bonds at a discount and selling at preimum.
