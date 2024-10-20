import { createPublicClient, http, createWalletClient, custom, erc20Abi } from 'viem'
import { hardhat } from 'viem/chains'

import signalsAbi from './signals.abi.json'

export const readClient = createPublicClient({
  chain: hardhat,
  transport: http(process.env.NEXT_PUBLIC_RPC_URL!),
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
]

export const SIGNALS_ABI = [...signalsAbi]

/**
 * Critical addresses
 */
export const ERC20_ADDRESS = process.env.NEXT_PUBLIC_GOV_TOKEN as `0x${string}`
export const USDC_ADDRESS = process.env.NEXT_PUBLIC_USDC_TOKEN as `0x${string}`
export const SIGNALS_PROTOCOL = process.env.NEXT_PUBLIC_SIGNALS_PROTOCOL as `0x${string}`
export const TOKEN_REGISTRY = process.env.NEXT_PUBLIC_TOKEN_REGISTRY as `0x${string}`
export const INCENTIVES = process.env.NEXT_PUBLIC_INCENTIVES as `0x${string}`
