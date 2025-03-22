import { onchainTable } from 'ponder'

/**
 * Note: The variable name eventually becomes the GraphQL type name so prefer PascalCase.
 */

// ===========================================================================
//                                   ENTITIES
// ===========================================================================

export const Board = onchainTable('boards', (t) => ({
  id: t.text().primaryKey(),
  chainId: t.integer().notNull(),
  blockTimestamp: t.bigint().notNull(),
  transactionHash: t.text().notNull(),
  // --- event data
  owner: t.hex().notNull(),
  board: t.hex().notNull(),
}))

export const Initiative = onchainTable('initiatives', (t) => ({
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

export const Weight = onchainTable('weights', (t) => ({
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

// Pool Manager events
export const PoolManagerInitializeEvent = onchainTable('pool_manager_initialize_events', (t) => ({
  id: t.text().primaryKey(),
  chainId: t.integer().notNull(),
  blockTimestamp: t.bigint().notNull(),
  transactionHash: t.text().notNull(),
  contractAddress: t.hex().notNull(),
  // --- event data
  poolId: t.hex().notNull(),
}))

// ===========================================================================
//                                   RELATIONS
// ===========================================================================

// FIXME: TODO
