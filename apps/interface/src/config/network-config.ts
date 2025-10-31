import type { Abi } from 'viem'
import { erc20Abi } from 'viem'
import { arbitrumSepolia, base, anvil } from 'viem/chains'

import type { NetworkConfig, SupportedNetworks } from './network-types'
import { SignalsABI, SignalsFactoryABI } from '../../../../packages/abis'

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

export const DEFAULT_NETWORK: SupportedNetworks = 'local'

export const NETWORK_CONFIG: Record<SupportedNetworks, NetworkConfig> = {
  local: {
    chain: anvil,
    rpcUrl: anvil.rpcUrls.default.http[0]!,
    explorerUrl: anvil.blockExplorers?.default.url,
    indexerEndpoint: 'http://localhost:42069',
    contracts: {
      SignalsProtocol: {
        address: '0xd8058efe0198ae9dD7D563e1b4938Dcbc86A1F81' as `0x${string}`,
        abi: SignalsABI,
        label: 'Signals Protocol',
      },
      SignalsFactory: {
        address: '0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9' as `0x${string}`,
        abi: SignalsFactoryABI,
        label: 'Signals Factory',
      },
      BoardUnderlyingToken: {
        address: ZERO_ADDRESS,
        abi: ERC20WithFaucetABI,
        label: 'Signals Token',
        decimals: 18,
      },
      USDC: {
        address: ZERO_ADDRESS,
        abi: ERC20WithFaucetABI,
        label: 'USDC',
        decimals: 6,
      },
    },
  },
  arbitrumSepolia: {
    chain: arbitrumSepolia,
    rpcUrl: arbitrumSepolia.rpcUrls.default.http[0]!,
    explorerUrl: arbitrumSepolia.blockExplorers?.default.url ?? 'https://sepolia.arbiscan.io',
    indexerEndpoint: 'https://indexer.arbitrum-sepolia.example.org',
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
    contracts: {
      SignalsFactory: {
        address: ZERO_ADDRESS,
        abi: SignalsFactoryABI,
        label: 'Signals Factory',
      },
    },
  },
}
