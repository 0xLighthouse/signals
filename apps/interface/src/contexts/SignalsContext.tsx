'use client'

import { createContext, useCallback, useEffect, useMemo, useState, type ReactNode } from 'react'
import { useParams, useRouter } from 'next/navigation'

import { useWeb3 } from './WalletProvider'
import { getNetworkFromSlug, getBoardUrl } from '@/lib/routing'
import type { SupportedNetworks } from '@/config/network-types'
import { useNetworkConfig } from '@/hooks/useNetworkConfig'
import { useRouteStore } from '@/stores/useRouteStore'
import type {
  BoardRequirement,
  BoardByAddressQueryItem,
  BoardByAddressQueryResponse,
  AcceptanceCriteria,
  LockingConfig,
  DecayConfig,
} from '@/lib/indexer/types.graphql'

export interface IndexedBoardMetadata {
  chainId?: number
  blockTimestamp?: number
  transactionHash?: string
  contractAddress?: `0x${string}`
  version?: string
  owner?: `0x${string}`
  name?: string
  body?: string
  opensAt?: number
  closesAt?: number
  symbol?: string
  initiativesCount?: number
  /**
   * @deprecated Use `proposerRequirements.minBalance` instead
   */
  proposalThreshold?: number
  /**
   * @deprecated Use `acceptanceCriteria.minThreshold` instead
   */
  acceptanceThreshold?: number
  /**
   * @deprecated Use `lockingConfig.lockInterval` instead
   */
  lockInterval?: number
  /**
   * @deprecated Use `lockingConfig.maxLockIntervals` instead
   */
  maxLockIntervals?: number
  /**
   * @deprecated Use `decayConfig.curveType` instead
   */
  decayCurveType?: number
  /**
   * @deprecated Use `decayConfig.params` instead
   */
  decayCurveParameters?: number[]
  // Full indexed structures
  acceptanceCriteria?: AcceptanceCriteria
  lockingConfig?: LockingConfig
  decayConfig?: DecayConfig
  proposerRequirements?: BoardRequirement
  participantRequirements?: BoardRequirement
  underlyingToken?: `0x${string}`
  underlyingTokenSymbol?: string
  underlyingTokenDecimals?: number
  underlyingTokenName?: string
}

export interface SignalsContextValue {
  network: SupportedNetworks | null
  boardAddress: `0x${string}` | null
  board: IndexedBoardMetadata
  underlyingAddress?: `0x${string}`
  underlyingName?: string
  underlyingSymbol?: string
  underlyingDecimals?: number
  underlyingTotalSupply?: number
  underlyingBalance?: number
  formatter: (value?: number | null | undefined) => number
  fetchBoardMetadata: () => Promise<void>
  meetsProposalThreshold: (balance: number) => boolean
  navigateToBoard: (address: `0x${string}`) => void
}

const initialBoard: IndexedBoardMetadata = {}

interface BoardBalances {
  // Wallet balance of the underlying token
  walletBalance: number | null
  // Total supply of the underlying token
  totalSupply: number | null
}

export const SignalsContext = createContext<SignalsContextValue | undefined>(undefined)

export const SignalsProvider = ({ children }: { children: ReactNode }) => {
  const params = useParams()
  const router = useRouter()
  const { isInitialized } = useWeb3()

  const [balances, setBalances] = useState<BoardBalances>({
    walletBalance: null,
    totalSupply: null,
  })

  // Get network config at top level
  const { network: resolvedNetwork, config: networkConfig } = useNetworkConfig()
  const routeBoardAddress = useRouteStore((state) => state.boardAddress)
  const routeNetwork = useRouteStore((state) => state.network)

  const networkSlug = Array.isArray(params?.network)
    ? params?.network[0]
    : (params?.network as string | undefined)
  const boardAddressParam = Array.isArray(params?.boardAddress)
    ? params?.boardAddress[0]
    : (params?.boardAddress as string | undefined)

  const network =
    routeNetwork ?? (networkSlug ? getNetworkFromSlug(networkSlug) : (resolvedNetwork ?? null))
  const boardAddress = routeBoardAddress
    ? routeBoardAddress
    : boardAddressParam
      ? (boardAddressParam.toLowerCase() as `0x${string}`)
      : null

  const [boardState, setBoardState] = useState(initialBoard)

  const formatter = useCallback(
    (value?: number | null | undefined) => {
      if (value == null || !boardState.underlyingTokenDecimals) return 0
      return Math.ceil(value / 10 ** boardState.underlyingTokenDecimals)
    },
    [boardState.underlyingTokenDecimals],
  )

  const fetchBoardMetadata = useCallback(async () => {
    if (!boardAddress || !networkConfig) {
      setBoardState(initialBoard)
      return
    }

    if (!networkConfig.indexerGraphQLEndpoint) {
      console.warn('Missing indexer configuration')
      setBoardState(initialBoard)
      return
    }

    const toNumber = (value?: string | number | null): number | undefined => {
      if (value == null) return undefined
      try {
        return Number(BigInt(value))
      } catch {
        return undefined
      }
    }

    const toNumberArray = (values?: Array<string | number | null> | null): number[] | undefined => {
      if (!values || values.length === 0) return undefined

      const parsed = values
        .map((value) => {
          if (value == null) return null
          try {
            return Number(BigInt(value))
          } catch {
            const asNumber = Number(value)
            return Number.isNaN(asNumber) ? null : asNumber
          }
        })
        .filter((value): value is number => value != null)

      return parsed.length > 0 ? parsed : undefined
    }

    try {
      const query = `
        query BoardByAddress($chainId: Int!, $contractAddress: String!) {
          boards(where: { chainId: $chainId, contractAddress: $contractAddress }) {
            items {
              chainId
              blockTimestamp
              transactionHash
              contractAddress
              version
              owner
              underlyingToken
              underlyingTokenSymbol
              underlyingTokenDecimals
              underlyingTokenName
              opensAt
              closesAt
              boardMetadata
              acceptanceCriteria
              proposerRequirements
              supporterRequirements
              lockingConfig
              decayConfig
            }
          }
        }
      `

      const resp = await fetch(networkConfig.indexerGraphQLEndpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
        body: JSON.stringify({
          query,
          variables: {
            chainId: networkConfig.chain.id,
            contractAddress: boardAddress,
          },
        }),
      })

      if (!resp.ok) {
        throw new Error(`GraphQL request failed: ${resp.status} ${resp.statusText}`)
      }

      const result: BoardByAddressQueryResponse = await resp.json()

      const indexedBoard = result.data?.boards?.items?.[0]

      if (!indexedBoard) {
        setBoardState(initialBoard)
        return
      }

      setBoardState({
        chainId: toNumber(indexedBoard.chainId),
        blockTimestamp: toNumber(indexedBoard.blockTimestamp),
        transactionHash: indexedBoard.transactionHash ?? undefined,
        contractAddress: indexedBoard.contractAddress
          ? (indexedBoard.contractAddress.toLowerCase() as `0x${string}`)
          : undefined,
        version: indexedBoard.version ?? undefined,
        owner: indexedBoard.owner ? (indexedBoard.owner.toLowerCase() as `0x${string}`) : undefined,
        name: indexedBoard.boardMetadata?.title ?? undefined,
        body: indexedBoard.boardMetadata?.body ?? undefined,
        opensAt: toNumber(indexedBoard.opensAt),
        closesAt: toNumber(indexedBoard.closesAt),
        proposalThreshold: toNumber(indexedBoard.proposerRequirements?.minBalance),
        acceptanceThreshold: toNumber(indexedBoard.acceptanceCriteria?.minThreshold),
        lockInterval: toNumber(indexedBoard.lockingConfig?.lockInterval),
        maxLockIntervals: toNumber(indexedBoard.lockingConfig?.maxLockIntervals),
        decayCurveType: toNumber(indexedBoard.decayConfig?.curveType),
        decayCurveParameters: toNumberArray(indexedBoard.decayConfig?.params),
        acceptanceCriteria: indexedBoard.acceptanceCriteria ?? undefined,
        lockingConfig: indexedBoard.lockingConfig ?? undefined,
        decayConfig: indexedBoard.decayConfig ?? undefined,
        proposerRequirements: indexedBoard.proposerRequirements ?? undefined,
        participantRequirements: indexedBoard.supporterRequirements ?? undefined,
        underlyingToken: indexedBoard.underlyingToken
          ? (indexedBoard.underlyingToken.toLowerCase() as `0x${string}`)
          : undefined,
        underlyingTokenSymbol: indexedBoard.underlyingTokenSymbol ?? undefined,
        underlyingTokenDecimals: indexedBoard.underlyingTokenDecimals ?? undefined,
        underlyingTokenName: indexedBoard.underlyingTokenName ?? undefined,
      })
    } catch (error) {
      console.error('Error fetching board metadata from indexer:', error)
      setBoardState(initialBoard)
    }
  }, [boardAddress, networkConfig])

  useEffect(() => {
    void fetchBoardMetadata()
  }, [fetchBoardMetadata])

  useEffect(() => {
    if (!isInitialized || !boardAddress || !networkConfig) {
      console.info(
        'Fetching balances for board...',
        boardAddress,
        'on network...',
        networkConfig.chain.name,
      )
      setBalances({ walletBalance: 69, totalSupply: 420420 })
      return
    }
  }, [isInitialized, boardAddress, networkConfig])

  const navigateToBoard = useCallback(
    (address: `0x${string}`) => {
      if (!network) return
      router.push(getBoardUrl(network, address))
    },
    [router, network],
  )

  const contextValue = useMemo<SignalsContextValue>(
    () => ({
      network,
      boardAddress,
      board: boardState,
      /**
       * Checks if the wallet balance meets the proposal threshold
       *
       * @param walletBalance - The wallet balance of the underlying token
       * @returns Whether the wallet balance meets the proposal threshold
       */
      meetsProposalThreshold: (walletBalance: number) => {
        const meetsThreshold =
          walletBalance != null && walletBalance > 0 && boardState.proposalThreshold != null
            ? walletBalance >= boardState.proposalThreshold
            : null
        return meetsThreshold ?? false
      },
      underlyingAddress: boardState.underlyingToken,
      underlyingName: boardState.underlyingTokenName,
      underlyingSymbol: boardState.underlyingTokenSymbol,
      underlyingDecimals: boardState.underlyingTokenDecimals,
      underlyingTotalSupply: balances.totalSupply ?? undefined,
      underlyingBalance: balances.walletBalance ?? undefined,
      formatter,
      fetchBoardMetadata,
      navigateToBoard,
    }),
    [
      network,
      boardAddress,
      boardState,
      boardState.underlyingToken,
      boardState.underlyingTokenName,
      boardState.underlyingTokenSymbol,
      boardState.underlyingTokenDecimals,
      balances.totalSupply,
      balances.walletBalance,
      formatter,
      fetchBoardMetadata,
      navigateToBoard,
    ],
  )

  return <SignalsContext.Provider value={contextValue}>{children}</SignalsContext.Provider>
}
