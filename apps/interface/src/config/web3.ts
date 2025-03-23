import { createPublicClient, http, erc20Abi, Abi } from 'viem'
import { arbitrumSepolia, hardhat } from 'viem/chains'

import { SignalsABI, IncentivesABI } from '../../../../packages/abis'
import { Board } from 'indexers/ponder.schema'

// Default public client for server components or initial loading
// Components should prefer using the context via useWeb3() whenever possible
export const readClient = createPublicClient({
  chain: process.env.NEXT_PUBLIC_SIGNALS_ENV === 'dev' ? hardhat : arbitrumSepolia,
  transport: http(process.env.NEXT_PUBLIC_RPC_URL!),
})

export const ERC20WithFaucetABI = [
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
] satisfies Abi

export const SIGNALS_ABI = SignalsABI
export const INCENTIVES_ABI = IncentivesABI

/**
 * Critical addresses
 */
export const ERC20_ADDRESS = process.env.NEXT_PUBLIC_GOV_TOKEN as `0x${string}`
export const USDC_ADDRESS = process.env.NEXT_PUBLIC_USDC_TOKEN as `0x${string}`
export const SIGNALS_PROTOCOL = process.env.NEXT_PUBLIC_SIGNALS_PROTOCOL as `0x${string}`
export const TOKEN_REGISTRY = process.env.NEXT_PUBLIC_TOKEN_REGISTRY as `0x${string}`
export const INCENTIVES = process.env.NEXT_PUBLIC_INCENTIVES as `0x${string}`

export const context = {
  network: {
    arbitrumSepolia: {
      chainId: 421614,
      transport: http(process.env.ARBITRUM_SEPOLIA_RPC_URL!),
    },
  },
  contracts: {
    BoardUnderlyingToken: {
      abi: ERC20WithFaucetABI,
      address: '0x26D04e0D3050b7b11054B5A48639D1FE88aA7Be7' as `0x${string}`,
    },
  },
}
