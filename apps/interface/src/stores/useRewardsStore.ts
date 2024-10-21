import { ABI, USDC_ADDRESS } from '@/config/web3'
import { createPublicClient, getContract, http } from 'viem'
import { hardhat } from 'viem/chains'
import { create } from 'zustand'

interface RewardsState {
  name?: string
  symbol?: string
  decimals?: number
  totalSupply?: number
  balance?: number
  isInitialized: boolean
  formatter: (value?: number | null) => number | null
  fetch: (address: `0x${string}`) => Promise<void>
}

export const useRewardsStore = create<RewardsState>((set) => ({
  name: '',
  symbol: '',
  decimals: 0,
  totalSupply: 0,
  balance: 0,
  formatter: (value?: number | null) => {
    if (value == null) return null; // Handle null or undefined
    return Math.ceil(value / 1e6);
  },
  isInitialized: false,
  fetch: async (address: `0x${string}`) => {
    const readClient = createPublicClient({
      // TODO: We need to make this dynamic
      // TODO: We need to make this dynamic
      // TODO: We need to make this dynamic
      chain: hardhat,
      transport: http(process.env.NEXT_PUBLIC_RPC_URL!),
    })

    const token = getContract({
      address: USDC_ADDRESS,
      abi: ABI,
      client: readClient,
    })

    // Fetch contract data in parallel using Promise.all
    const [name, symbol, decimals, totalSupply, balance] = await Promise.all([
      token.read.name(),
      token.read.symbol(),
      token.read.decimals(),
      token.read.totalSupply(),
      token.read.balanceOf([address]),
    ])

    // Update state with fetched metadata
    set({
      name: String(name),
      symbol: String(symbol),
      decimals: Number(decimals),
      totalSupply: Number(totalSupply),
      balance: Number(balance),
      isInitialized: true,
    })
  },
}))
