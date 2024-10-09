'use client'

import { createPublicClient, http, createWalletClient, custom, erc20Abi } from 'viem';
import { hardhat } from 'viem/chains';


export const readClient = createPublicClient({
  chain: hardhat,
  transport: http(process.env.RPC_URL!),
})

export const signer = createWalletClient({
  chain: hardhat,
  transport: custom(window.ethereum!),
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
