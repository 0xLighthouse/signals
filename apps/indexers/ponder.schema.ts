import { onchainTable } from 'ponder'

/**
 * Note: The variable name eventually becomes the GraphQL type name so use PascalCase.
 */

/**
 * SignalsFactory events
 */
export const BoardCreatedEvent = onchainTable('board_created_events', (t) => ({
  id: t.text().primaryKey(),
  chainId: t.integer().notNull(),
  blockTimestamp: t.bigint().notNull(),
  transactionHash: t.text().notNull(),
  // --- event data
  owner: t.hex().notNull(),
  board: t.hex().notNull(),
}))

/**
 * Signals events
 */
export const InitiativeProposedEvent = onchainTable('initiative_proposed_events', (t) => ({
  id: t.text().primaryKey(),
  chainId: t.integer().notNull(),
  blockTimestamp: t.bigint().notNull(),
  transactionHash: t.text().notNull(),
  contractAddress: t.hex().notNull(),
  // --- event data
  initiativeId: t.integer().notNull(),
  proposer: t.hex().notNull(),
  title: t.text().notNull(),
  body: t.text().notNull(),
}))

export const InitiativeSupportedEvent = onchainTable('initiative_supported_events', (t) => ({
  id: t.text().primaryKey(),
  chainId: t.integer().notNull(),
  blockTimestamp: t.bigint().notNull(),
  transactionHash: t.text().notNull(),
  contractAddress: t.hex().notNull(),
  // --- event data
  initiativeId: t.integer().notNull(),
  supporter: t.hex().notNull(),
  amount: t.bigint().notNull(),
  lockDuration: t.integer().notNull(),
  // TODO: Deprecate this column
  // timestamp: t.bigint().notNull(),
}))

/**
 * Pool Manager events
 */
export const PoolManagerInitializeEvent = onchainTable('pool_manager_initialize_events', (t) => ({
  id: t.text().primaryKey(),
  chainId: t.integer().notNull(),
  blockTimestamp: t.bigint().notNull(),
  transactionHash: t.text().notNull(),
  contractAddress: t.hex().notNull(),
  // --- event data
  poolId: t.hex().notNull(),
}))
