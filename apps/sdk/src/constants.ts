import type { Address } from 'viem'
import { signalsAbi, signalsFactoryAbi } from './abis'

export enum ContractType {
  UniswapV4PoolManager = 'UniswapV4PoolManager',
  SignalsFactory = 'SignalsFactory',
  Signals = 'Signals',
}

export enum Network {
  Anvil = 31337,
  ArbitrumSepolia = 421614,
}

// Define specific ABI types
type ContractAbiMap = {
  [ContractType.UniswapV4PoolManager]: [] // TODO: Add ABI
  [ContractType.SignalsFactory]: typeof signalsFactoryAbi
  [ContractType.Signals]: typeof signalsAbi
}

// Define the contract addresses structure type with proper ABI mapping
type ContractAddressesType = {
  [chainId in Network]: {
    [key in ContractType]: {
      address: Address
      abi: ContractAbiMap[key]
    }
  }
}

export const ContractAddresses: ContractAddressesType = {
  [Network.ArbitrumSepolia]: {
    [ContractType.UniswapV4PoolManager]: {
      address: '0x0000000000000000000000000000000000000000',
      abi: [], // FIXME: Add ABI
    },
    [ContractType.SignalsFactory]: {
      address: '0x0000000000000000000000000000000000000000',
      abi: signalsFactoryAbi,
    },
    [ContractType.Signals]: {
      address: '0x0000000000000000000000000000000000000000',
      abi: signalsAbi,
    },
  },
  [Network.Anvil]: {
    [ContractType.UniswapV4PoolManager]: {
      address: '0x0000000000000000000000000000000000000000',
      abi: [], // FIXME: Add ABI
    },
    [ContractType.SignalsFactory]: {
      address: '0x0000000000000000000000000000000000000000',
      abi: signalsFactoryAbi,
    },
    [ContractType.Signals]: {
      address: '0x0000000000000000000000000000000000000000',
      abi: signalsAbi,
    },
  },
}
