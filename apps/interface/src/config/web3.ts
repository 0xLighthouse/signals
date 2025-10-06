import { createPublicClient, http, erc20Abi, Abi } from 'viem'
import { arbitrumSepolia, hardhat } from 'viem/chains'

import { SignalsABI, IncentivesABI } from '../../../../packages/abis'

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

export const INDEXER_ENDPOINT = process.env.NEXT_PUBLIC_INDEXER_ENDPOINT!

/**
 * Critical addresses
 */
export const context = {
  network: {
    explorerUri: 'https://sepolia.arbiscan.io',
    arbitrumSepolia: {
      chainId: 421614,
      transport: http(process.env.ARBITRUM_SEPOLIA_RPC_URL!),
    },
  },
  contracts: {
    USDC: {
      abi: ERC20WithFaucetABI,
      address: '0x0eFf88D35f413cD1146269D916fb87A451B03d6D' as `0x${string}`,
      label: 'mUSDC',
    },
    BoardUnderlyingToken: {
      abi: ERC20WithFaucetABI,
      address: '0x4713635357F9d01cBAF4DAc7E93B66D69544DEa8' as `0x${string}`,
      label: 'Hook',
      decimals: 18, // TODO: Should be dynamic
    },
    SignalsProtocol: {
      abi: SIGNALS_ABI,
      address: '0x7E00a6dfF783649fB3017151652448647600D47E' as `0x${string}`,
    },
    TokenRegistry: {
      address: '0xacCbbb8140Bd4494e11eEA8268d93F94895abC80' as `0x${string}`,
    },
    Incentives: {
      abi: IncentivesABI,
      address: '0xe4D69c41Db5c5790e3DCA52E4416fbbd676E960a' as `0x${string}`,
    },
  },
}
