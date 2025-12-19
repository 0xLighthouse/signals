import { create } from 'zustand'
import { useNetworkStore } from '@/stores/useNetworkStore'
import type {
  BoardSummary,
  BoardRequirement,
  BoardMetadata,
  AcceptanceCriteria,
  LockingConfig,
  DecayConfig,
} from '@/lib/indexer/types.graphql'

export type { BoardSummary }

interface BoardsState {
  boards: BoardSummary[]
  isFetching: boolean
  isInitialized: boolean
  fetchBoards: () => Promise<void>
  reset: () => void
}

interface GraphQLResponse {
  data: {
    boards: {
      items: Array<{
        id: string
        chainId: number
        contractAddress: `0x${string}`
        version: string
        owner: `0x${string}`
        underlyingToken: `0x${string}`
        underlyingTokenSymbol: string
        underlyingTokenDecimals: number
        underlyingTokenName: string
        opensAt: string | number
        closesAt: string | number
        boardMetadata: BoardMetadata
        acceptanceCriteria: AcceptanceCriteria
        proposerRequirements: BoardRequirement
        supporterRequirements: BoardRequirement
        lockingConfig: LockingConfig
        decayConfig: DecayConfig
        blockTimestamp: string
        transactionHash: string
      }>
      totalCount: number
      pageInfo: {
        startCursor: string | null
        endCursor: string | null
      }
    }
  }
}

export const useBoardsStore = create<BoardsState>((set) => ({
  boards: [],
  isFetching: false,
  isInitialized: false,
  fetchBoards: async () => {
    try {
      set({ isFetching: true })

      const { chain, indexerGraphQLEndpoint } = useNetworkStore.getState().config

      const query = `
        query BoardsByNetwork($chainId: Int!) {
          boards(where: { chainId: $chainId }) {
            items {
              id
              chainId
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
              blockTimestamp
              transactionHash
            }
            totalCount
            pageInfo {
              startCursor
              endCursor
            }
          }
        }
      `

      const resp = await fetch(indexerGraphQLEndpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
        body: JSON.stringify({ query, variables: { chainId: chain.id } }),
      })

      if (!resp.ok) {
        throw new Error(`GraphQL request failed: ${resp.status} ${resp.statusText}`)
      }

      const result: GraphQLResponse = await resp.json()

      if (result?.data?.boards?.items) {
        const boards: BoardSummary[] = result.data.boards.items.map((item) => {
          const createdAtSec = Number(item.blockTimestamp)
          const createdAtTimestamp = Number.isFinite(createdAtSec) ? createdAtSec : 0

          return {
            chainId: Number(item.chainId),
            blockTimestamp: item.blockTimestamp,
            transactionHash: item.transactionHash,
            contractAddress: item.contractAddress.toLowerCase() as `0x${string}`,
            version: item.version,
            owner: item.owner.toLowerCase() as `0x${string}`,
            underlyingToken: item.underlyingToken
              ? (item.underlyingToken.toLowerCase() as `0x${string}`)
              : undefined,
            underlyingTokenSymbol: item.underlyingTokenSymbol,
            underlyingTokenDecimals: item.underlyingTokenDecimals,
            underlyingTokenName: item.underlyingTokenName,
            opensAt: Number(item.opensAt),
            closesAt: Number(item.closesAt),
            boardMetadata: item.boardMetadata,
            acceptanceCriteria: item.acceptanceCriteria,
            proposerRequirements: item.proposerRequirements,
            supporterRequirements: item.supporterRequirements,
            lockingConfig: item.lockingConfig,
            decayConfig: item.decayConfig,
            createdAtTimestamp,
            updatedAt: createdAtTimestamp,
          }
        })

        set({ boards })
      } else {
        console.warn('GraphQL response missing expected data structure')
        set({ boards: [] })
      }
    } catch (error) {
      console.error('Error fetching boards from indexer:', error)
      set({ boards: [] })
    } finally {
      set({ isFetching: false, isInitialized: true })
    }
  },
  reset: () => set({ boards: [], isFetching: false, isInitialized: false }),
}))
