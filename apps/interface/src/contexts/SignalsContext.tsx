'use client'

import {
  createContext,
  useCallback,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react'
import { useParams, useRouter } from 'next/navigation'
import { getContract } from 'viem'

import { useAccount } from '@/hooks/useAccount'
import { useWeb3 } from './Web3Provider'
import { getNetworkFromSlug, getBoardUrl } from '@/lib/routing'
import type { SupportedNetworks } from '@/config/network-types'
import { SignalsABI } from '../../../../packages/abis'
import { ZERO_ADDRESS, ERC20WithFaucetABI } from '@/config/web3'
import { NETWORKS } from '@/config/networks'
import { useNetworkStore } from '@/stores/useNetworkStore'

interface UnderlyingMetadata {
  address: `0x${string}` | null
  name: string | null
  symbol: string | null
  decimals: number | null
  totalSupply: number | null
  balance: number | null
}

export interface BoardMetadata {
  name: string | null
  symbol: string | null
  initiativesCount: number | null
  proposalThreshold: number | null
  acceptanceThreshold: number | null
  meetsThreshold: boolean
  lockInterval: number | null
  decayCurveType: number | null
  decayCurveParameters: number[] | null
}

export interface SignalsContextValue {
  network: SupportedNetworks | null
  boardAddress: `0x${string}` | null
  board: BoardMetadata
  underlyingAddress: `0x${string}` | null
  underlyingName: string | null
  underlyingSymbol: string | null
  underlyingDecimals: number | null
  underlyingTotalSupply: number | null
  underlyingBalance: number | null
  formatter: (value?: number | null | undefined) => number
  fetchBoardMetadata: () => Promise<void>
  fetchUnderlyingMetadata: () => Promise<void>
  navigateToBoard: (address: `0x${string}`) => void
}

const initialBoard: Omit<BoardMetadata, 'meetsThreshold'> = {
  name: null,
  symbol: null,
  initiativesCount: null,
  proposalThreshold: null,
  acceptanceThreshold: null,
  lockInterval: null,
  decayCurveType: null,
  decayCurveParameters: null,
}

const initialUnderlying: UnderlyingMetadata = {
  address: null,
  name: null,
  symbol: null,
  decimals: null,
  totalSupply: null,
  balance: null,
}

export const SignalsContext = createContext<SignalsContextValue | undefined>(undefined)

export const SignalsProvider = ({ children }: { children: ReactNode }) => {
  const params = useParams()
  const router = useRouter()
  const { publicClient } = useWeb3()
  const { address: walletAddress } = useAccount()

  const networkSlug = Array.isArray(params?.network)
    ? params?.network[0]
    : (params?.network as string | undefined)
  const boardAddressParam = Array.isArray(params?.boardAddress)
    ? params?.boardAddress[0]
    : (params?.boardAddress as string | undefined)

  const network = networkSlug ? getNetworkFromSlug(networkSlug) : null
  const boardAddress = boardAddressParam
    ? (boardAddressParam.toLowerCase() as `0x${string}`)
    : null

  const [boardState, setBoardState] = useState(initialBoard)
  const [underlying, setUnderlying] = useState<UnderlyingMetadata>(initialUnderlying)

  const formatter = useCallback(
    (value?: number | null | undefined) => {
      if (value == null || !underlying.decimals) return 0
      return Math.ceil(value / 10 ** underlying.decimals)
    },
    [underlying.decimals],
  )

  const fetchBoardMetadata = useCallback(async () => {
    if (!network || !boardAddress) {
      setBoardState(initialBoard)
      return
    }

    const config = NETWORKS[network]
    if (!config?.indexerGraphQLEndpoint) {
      console.warn('Missing indexer configuration for network', network)
      setBoardState(initialBoard)
      return
    }

    const toNumber = (value?: string | null): number | null => {
      if (value == null) return null
      try {
        return Number(BigInt(value))
      } catch {
        return null
      }
    }

    try {
      const query = `
        query BoardByAddress($chainId: Int!, $contractAddress: String!) {
          boards(where: { chainId: $chainId, contractAddress: $contractAddress }) {
            items {
              title
              proposerRequirements
              acceptanceThreshold
              body
            }
          }
        }
      `

      const resp = await fetch(config.indexerGraphQLEndpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
        body: JSON.stringify({
          query,
          variables: {
            chainId: config.chain.id,
            contractAddress: boardAddress,
          },
        }),
      })

      if (!resp.ok) {
        throw new Error(`GraphQL request failed: ${resp.status} ${resp.statusText}`)
      }

      const result: {
        data?: {
          boards?: {
            items?: Array<{
              title?: string | null
              proposerRequirements?: {
                minBalance?: string | null
              } | null
              acceptanceThreshold?: string | null
            }>
          }
        }
      } = await resp.json()

      const boardFromIndexer = result.data?.boards?.items?.[0]
      if (!boardFromIndexer) {
        setBoardState(initialBoard)
        return
      }

      setBoardState({
        name: boardFromIndexer.title ?? null,
        symbol: null,
        initiativesCount: null,
        proposalThreshold: toNumber(boardFromIndexer.proposerRequirements?.minBalance),
        acceptanceThreshold: toNumber(boardFromIndexer.acceptanceThreshold),
        lockInterval: null,
        decayCurveType: null,
        decayCurveParameters: null,
        meetsThreshold: false,
      })
    } catch (error) {
      console.error('Error fetching board metadata from indexer:', error)
      setBoardState(initialBoard)
    }
  }, [network, boardAddress])

  const fetchUnderlyingMetadata = useCallback(async () => {
    if (!publicClient || !boardAddress) {
      setUnderlying(initialUnderlying)
      return
    }

    try {
      const protocol = getContract({
        address: boardAddress,
        abi: SignalsABI,
        client: publicClient,
      })

      const underlyingAddress = (await protocol.read.underlyingToken()) as `0x${string}`
      if (!underlyingAddress) {
        setUnderlying(initialUnderlying)
        return
      }

      const token = getContract({
        address: underlyingAddress,
        abi: ERC20WithFaucetABI,
        client: publicClient,
      })

      const [name, symbol, decimals, totalSupply, balance] = await Promise.all([
        token.read.name(),
        token.read.symbol(),
        token.read.decimals(),
        token.read.totalSupply(),
        walletAddress ? token.read.balanceOf([walletAddress]) : 0n,
      ])

      const decimalsNum = Number(decimals ?? 18)

      setUnderlying({
        address: underlyingAddress.toLowerCase() as `0x${string}`,
        name: name ? String(name) : null,
        symbol: symbol ? String(symbol) : null,
        decimals: decimalsNum,
        totalSupply: Number(totalSupply ?? 0n),
        balance: Number(balance ?? 0n),
      })

      if (network) {
        const baseConfig = NETWORKS[network]
        if (baseConfig) {
          useNetworkStore.setState({
            selected: network,
            config: {
              ...baseConfig,
              contracts: {
                ...baseConfig.contracts,
                SignalsProtocol: {
                  ...baseConfig.contracts.SignalsProtocol,
                  address: boardAddress,
                  abi: SignalsABI,
                  label: baseConfig.contracts.SignalsProtocol?.label ?? 'Signals Protocol',
                },
                BoardUnderlyingToken: {
                  address: underlyingAddress ?? ZERO_ADDRESS,
                  abi: baseConfig.contracts.BoardUnderlyingToken?.abi ?? ERC20WithFaucetABI,
                  label: baseConfig.contracts.BoardUnderlyingToken?.label ?? 'Signals Token',
                  decimals: decimalsNum,
                },
              },
            },
          })
        }
      }
    } catch (error) {
      console.error('Error fetching underlying token metadata:', error)
      setUnderlying(initialUnderlying)
    }
  }, [publicClient, boardAddress, walletAddress, network])

  useEffect(() => {
    void fetchBoardMetadata()
  }, [fetchBoardMetadata])

  useEffect(() => {
    void fetchUnderlyingMetadata()
  }, [fetchUnderlyingMetadata])

  const navigateToBoard = useCallback(
    (address: `0x${string}`) => {
      if (!network) return
      router.push(getBoardUrl(network, address))
    },
    [router, network],
  )

  const boardWithThreshold = useMemo<BoardMetadata>(() => {
    const meetsThreshold =
      boardState.proposalThreshold != null &&
      underlying.balance != null &&
      underlying.balance >= boardState.proposalThreshold
    return {
      ...boardState,
      meetsThreshold,
    }
  }, [boardState, underlying.balance])

  const contextValue = useMemo<SignalsContextValue>(
    () => ({
      network,
      boardAddress,
      board: boardWithThreshold,
      underlyingAddress: underlying.address,
      underlyingName: underlying.name,
      underlyingSymbol: underlying.symbol,
      underlyingDecimals: underlying.decimals,
      underlyingTotalSupply: underlying.totalSupply,
      underlyingBalance: underlying.balance,
      formatter,
      fetchBoardMetadata,
      fetchUnderlyingMetadata,
      navigateToBoard,
    }),
    [
      network,
      boardAddress,
      boardWithThreshold,
      underlying.address,
      underlying.name,
      underlying.symbol,
      underlying.decimals,
      underlying.totalSupply,
      underlying.balance,
      formatter,
      fetchBoardMetadata,
      fetchUnderlyingMetadata,
      navigateToBoard,
    ],
  )

  return <SignalsContext.Provider value={contextValue}>{children}</SignalsContext.Provider>
}
