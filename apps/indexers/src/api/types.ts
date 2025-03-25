import schema from 'ponder:schema'

type InitiativeEntity = typeof schema.Initiative.$inferSelect
type InitiativeWeightEntity = typeof schema.InitiativeWeight.$inferSelect

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
