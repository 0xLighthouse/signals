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

/**
 * Critical addresses
 */

export const context = {
  network: {
    arbitrumSepolia: {
      chainId: 421614,
      transport: http(process.env.ARBITRUM_SEPOLIA_RPC_URL!),
    },
  },
  contracts: {
    USDC: {
      abi: ERC20WithFaucetABI,
      address: '0x2ed7De542Ce7377Bca3f3500dA4e7aF830889635' as `0x${string}`,
      label: 'mUSDC',
    },
    BoardUnderlyingToken: {
      abi: ERC20WithFaucetABI,
      address: '0x75e8927FFabD709D7e55Ed44C7a19166A0B215A7' as `0x${string}`,
      label: 'SomeGovToken',
      decimals: 18, // TODO: Should be dynamic
    },
    SignalsProtocol: {
      abi: SIGNALS_ABI,
      address: '0xa6c364E36bB6329EE55BDBfA62318108275662a7' as `0x${string}`,
    },
    TokenRegistry: {
      address: '0x2817374F735fcA6C775B31e48bEc5e52d0b0D12B' as `0x${string}`,
    },
    Incentives: {
      abi: IncentivesABI,
      address: '0xdC81693e3601B4b9252ec3060204415408AA4350' as `0x${string}`,
    },
  },
}
