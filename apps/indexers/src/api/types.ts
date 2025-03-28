import schema from 'ponder:schema'

type InitiativeEntity = typeof schema.Initiative.$inferSelect
type InitiativeWeightEntity = typeof schema.InitiativeWeight.$inferSelect
type PoolEntity = typeof schema.Pool.$inferSelect

export type InitiativeLock = {
  initiativeId: bigint
  tokenId: bigint
  nominalValue: bigint
  durationAsIntervals: bigint
  createdAt: bigint
  isRedeemed: boolean
}

export type Pool = {
  poolId: string
  version: string
  swapPrice: number
  swapFee: number
  formattedSwapFee: number
  currency0: {
    address: `0x${string}`
    symbol: string
    name: string
    decimals: number
    totalTVL: number
    bondHookTVL: number
  }
  currency1: {
    address: `0x${string}`
    symbol: string
    name: string
    decimals: number
    totalTVL: number
    bondHookTVL: number
  }
} & PoolEntity

export type Initiative = {
  initiativeId: number
  title: string
  description: string
  weight: number
  progress: number
  proposer: string
  rewards: number
  support: number
  supporters: string[]
  createdAtTimestamp: number
  updatedAtTimestamp: number
  status: 'active' | 'accepted' | 'archived'
} & InitiativeEntity

export type InitiativeResponse = {
  version: string
  initiatives: Initiative[]
}

export type Lock = {
  initiativeId: number
  initiative: Initiative
  metadata: {
    referenceId: string
    nominalValue: string
    expires: string
    created: string
    claimed: boolean
  }
} & InitiativeWeightEntity

export type LockResponse = {
  version: string
  data: Lock[]
}

export type GetPoolsResponse = {
  data: Pool[]
}
