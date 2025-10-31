import { createPublicClient, getContract, http } from 'viem'
import { create } from 'zustand'
import { useNetworkStore } from '@/stores/useNetworkStore'

interface RewardsState {
  name?: string
  symbol?: string
  decimals?: number
  totalSupply: number
  balance: number
  isInitialized: boolean
  formatter: (value?: number | null) => number | null
  fetch: (address: `0x${string}`) => Promise<void>
  reset: () => void
}

export const useRewardsStore = create<RewardsState>((set) => ({
  name: '',
  symbol: '',
  decimals: 0,
  totalSupply: 0,
  balance: 0,
  formatter: (value?: number | null) => {
    if (value == null) return null // Handle null or undefined
    return Math.ceil(value / 1e6)
  },
  isInitialized: false,
  fetch: async (address: `0x${string}`) => {
    const { chain, rpcUrl, contracts } = useNetworkStore.getState().config
    const usdcConfig = contracts.USDC
    if (!usdcConfig) {
      console.warn('No USDC contract configured for current network.')
      set({
        name: '',
        symbol: '',
        decimals: 0,
        totalSupply: 0,
        balance: 0,
        isInitialized: true,
      })
      return
    }

    const readClient = createPublicClient({
      chain,
      transport: http(rpcUrl),
    })

    const token = getContract({
      address: usdcConfig.address,
      abi: usdcConfig.abi,
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
      totalSupply: Number(totalSupply ?? 0),
      balance: Number(balance ?? 0),
      isInitialized: true,
    })
  },
  reset: () =>
    set({
      name: '',
      symbol: '',
      decimals: 0,
      totalSupply: 0,
      balance: 0,
      isInitialized: false,
    }),
}))
