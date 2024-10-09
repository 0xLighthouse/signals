'use client'

import { createPublicClient, http, createWalletClient, custom, erc20Abi } from 'viem';
import { hardhat } from 'viem/chains';


export const readClient = createPublicClient({
  chain: hardhat,
  transport: http(process.env.RPC_URL!),
})

// TODO: Should be in an effect
export const signer = createWalletClient({
  chain: hardhat,
  // Injected provider from MetaMask
  transport: custom(window?.ethereum!),
})

export const ABI = [
  ...erc20Abi,
  {
    inputs: [
      {
        internalType: 'address',
        name: 'to',
        type: 'address',
      },
    ],
    name: 'faucet',
    outputs: [],
    stateMutability: 'payable',
    type: 'function',
  },
];

/**
 * The address of the mock ERC20 contract for testing...
 */
export const ERC20_ADDRESS = '0xD00B87df994b17a27aBA4f04c7A7D77bE3b95e10'
export const SIGNALS_PROTOCOL = '0xc4Aa97F06ed19301Fa0C34c67e1B39B8fF444980'

