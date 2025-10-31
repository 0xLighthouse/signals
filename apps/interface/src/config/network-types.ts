import type { Abi, Chain } from 'viem'

export type SupportedNetworks = 'local' | 'arbitrumSepolia' | 'base'

export interface ContractConfig {
  address: `0x${string}`
  abi: Abi
  label?: string
  decimals?: number
}

export interface ContractsConfig {
  SignalsFactory: ContractConfig
  SignalsProtocol?: ContractConfig
  BoardUnderlyingToken?: ContractConfig
  USDC?: ContractConfig
  TokenRegistry?: ContractConfig
  Incentives?: ContractConfig | null
}

export interface NetworkConfig {
  chain: Chain
  rpcUrl: string
  indexerEndpoint: string
  explorerUrl?: string
  contracts: ContractsConfig
}
