/**
 * GraphQL types for the Signals indexer
 * These types represent the data structures returned from indexer queries
 */

export type BoardRequirement = {
  minBalance: string
  minHoldingDuration: string
  minLockAmount: string
}

export type BoardAttachment = {
  uri: string
  mimeType: string
  description: string
}

export type BoardMetadata = {
  title: string
  body: string
  attachments: BoardAttachment[]
}

export type AcceptanceCriteria = {
  permissions: number
  thresholdOverride: number
  thresholdPercentTotalSupplyWAD: string
  minThreshold: string
}

export type LockingConfig = {
  lockInterval: string
  maxLockIntervals: string
  releaseLockDuration: string
  inactivityTimeout: string
}

export type DecayConfig = {
  curveType: number
  params: string[]
}

/**
 * Complete board data structure from the indexer
 * Used for detailed board queries (single board)
 */
export type BoardByAddressQueryItem = {
  chainId: number | string
  blockTimestamp: string | number
  transactionHash: string
  contractAddress: string
  version: string
  owner: string
  underlyingToken: string
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
}

export type BoardByAddressQueryResponse = {
  data?: {
    boards?: {
      items?: BoardByAddressQueryItem[]
    }
  }
}

/**
 * Summary board data structure
 * Used for board listings and overviews
 */
export type BoardSummary = {
  chainId: number
  blockTimestamp: string | number
  transactionHash: string
  contractAddress: `0x${string}`
  version: string
  owner: `0x${string}`
  underlyingToken: `0x${string}` | undefined
  underlyingTokenSymbol: string
  underlyingTokenDecimals: number
  underlyingTokenName: string
  opensAt: number
  closesAt: number
  boardMetadata: BoardMetadata
  acceptanceCriteria: AcceptanceCriteria
  proposerRequirements: BoardRequirement
  supporterRequirements: BoardRequirement
  lockingConfig: LockingConfig
  decayConfig: DecayConfig
  // Computed fields
  createdAtTimestamp?: number
  updatedAt?: number
}
