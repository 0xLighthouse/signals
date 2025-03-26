import schema from 'ponder:schema'

type InitiativeEntity = typeof schema.Initiative.$inferSelect
type InitiativeWeightEntity = typeof schema.InitiativeWeight.$inferSelect
type PoolEntity = typeof schema.Pool.$inferSelect

export type Pool = {
  poolId: number
  currency0: {
    address: `0x${string}`
    symbol: string
    name: string
    decimals: number
  }
  currency1: {
    address: `0x${string}`
    symbol: string
    name: string
    decimals: number
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
} & InitiativeWeightEntity

export type LockResponse = {
  version: string
  data: Lock[]
}

export type GetPoolsResponse = {
  data: Pool[]
}
