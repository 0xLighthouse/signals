import type { Abi } from 'viem'
import { erc20Abi } from 'viem'
import { arbitrumSepolia, base, baseSepolia } from 'viem/chains'

import type { NetworkConfig, SupportedNetworks } from './network-types'
import { ExperimentTokenABI, SignalsFactoryABI } from '../../../../packages/abis'

export const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000' as const

export const ERC20WithFaucetABI = [
  ...erc20Abi,
  {
    inputs: [{ internalType: 'address', name: 'to', type: 'address' }],
    name: 'faucet',
    outputs: [],
    stateMutability: 'payable',
    type: 'function',
  },
] as const satisfies Abi

// TODO[fixme]: Move to constants.ts
export const DEFAULT_NETWORK: SupportedNetworks = 'baseSepolia'

export const NETWORK_CONFIG: Record<SupportedNetworks, NetworkConfig> = {
  baseSepolia: {
    chain: baseSepolia,
    rpcUrl: 'https://small-twilight-market.base-sepolia.quiknode.pro/f58c26c114caf9887d370a568617b5dd80f8852d/',
    explorerUrl: baseSepolia.blockExplorers?.default.url,
    indexerEndpoint: process.env.NEXT_PUBLIC_INDEXER_ENDPOINT || 'http://localhost:42069',
    indexerGraphQLEndpoint: `${process.env.NEXT_PUBLIC_INDEXER_ENDPOINT || 'http://localhost:42069'}/graphql`,
    contracts: {
      EdgeExperimentToken: {
        address: '0x9265E5DF98c2Aa68aB89fbC68ab2404553DFa07b' as `0x${string}`,
        abi: ExperimentTokenABI,
        label: 'Edge Experiment Token',
        decimals: 18,
      },
      SignalsFactory: {
        address: '0xf2bd22802f6672EDe21a4c23DA81C2ece269baA3' as `0x${string}`,
        abi: SignalsFactoryABI,
        label: 'Signals Factory',
      },
    },
  },
  arbitrumSepolia: {
    chain: arbitrumSepolia,
    rpcUrl: arbitrumSepolia.rpcUrls.default.http[0]!,
    explorerUrl: arbitrumSepolia.blockExplorers?.default.url ?? 'https://sepolia.arbiscan.io',
    indexerEndpoint: 'https://indexer.arbitrum-sepolia.example.org',
    indexerGraphQLEndpoint: 'https://indexer.arbitrum-sepolia.example.org/graphql',
    contracts: {
      SignalsFactory: {
        address: ZERO_ADDRESS,
        abi: SignalsFactoryABI,
        label: 'Signals Factory',
      },
    },
  },
  base: {
    chain: base,
    rpcUrl: base.rpcUrls.default.http[0]!,
    explorerUrl: base.blockExplorers?.default.url ?? 'https://basescan.org',
    indexerEndpoint: 'https://indexer.base.placeholder.invalid',
    indexerGraphQLEndpoint: 'https://indexer.base.placeholder.invalid/graphql',
    contracts: {
      SignalsFactory: {
        address: ZERO_ADDRESS,
        abi: SignalsFactoryABI,
        label: 'Signals Factory',
      },
    },
  },
}
