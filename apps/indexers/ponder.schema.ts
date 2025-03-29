import { onchainTable, relations } from 'ponder'

/**
 * Notes:
 *  - The variable name eventually becomes the GraphQL type name so prefer PascalCase.
 *  - https://ponder.sh/docs/schema#column-types
 */

// ===========================================================================
//                                   ENTITIES
// ===========================================================================

export const Board = onchainTable('boards', (t) => ({
  id: t.text().primaryKey(),
  chainId: t.integer().notNull(),
  blockTimestamp: t.bigint().notNull(),
  transactionHash: t.text().notNull(),
  // --- attributes
  contractAddress: t.hex().notNull(),
  owner: t.hex().notNull(),
  proposalThreshold: t.bigint().notNull(),
  acceptanceThreshold: t.bigint().notNull(),
  underlyingToken: t.hex().notNull(),
}))

export const Transfer = onchainTable('transfers', (t) => ({
  id: t.text().primaryKey(),
  chainId: t.integer().notNull(),
  blockTimestamp: t.bigint().notNull(),
  transactionHash: t.text().notNull(),
  contractAddress: t.hex().notNull(),
  // --- attributes
  from: t.hex().notNull(),
  to: t.hex().notNull(),
  tokenId: t.bigint().notNull(),
}))

export const Bond = onchainTable('bonds', (t) => ({
  id: t.text().primaryKey(),
  chainId: t.integer().notNull(),
  contractAddress: t.hex().notNull(),
  tokenId: t.bigint().notNull(),
  blockTimestamp: t.bigint().notNull(),
  // --- attributes
  initiativeId: t.bigint().notNull(),
  owner: t.hex().notNull(),
  burnedAt: t.bigint(),
  nominalValue: t.bigint().notNull(),
  durationAsIntervals: t.bigint().notNull(),
  isActive: t.boolean().notNull(),
}))

export const Incentive = onchainTable('incentives', (t) => ({
  id: t.text().primaryKey(),
  chainId: t.integer().notNull(),
  blockTimestamp: t.bigint().notNull(),
  transactionHash: t.text().notNull(),
  contractAddress: t.hex().notNull(),
  // --- attributes
  initiativeId: t.bigint().notNull(),
  incentiveId: t.bigint().notNull(),
  token: t.hex().notNull(),
  amount: t.bigint().notNull(),
  expiresAt: t.bigint().notNull(),
  terms: t.integer().notNull(),
}))

export const Initiative = onchainTable('initiatives', (t) => ({
  id: t.text().primaryKey(),
  chainId: t.integer().notNull(),
  blockTimestamp: t.bigint().notNull(),
  transactionHash: t.text().notNull(),
  contractAddress: t.hex().notNull(),
  // --- attributes
  initiativeId: t.integer().notNull(),
  proposer: t.hex().notNull(),
  title: t.text().notNull(),
  body: t.text().notNull(),
}))

export const InitiativeWeight = onchainTable('initiative_weights', (t) => ({
  id: t.text().primaryKey(),
  chainId: t.integer().notNull(),
  blockTimestamp: t.bigint().notNull(),
  transactionHash: t.text().notNull(),
  contractAddress: t.hex().notNull(),
  // --- attributes
  initiativeId: t.integer().notNull(),
  weight: t.bigint().notNull(),
  supporter: t.hex().notNull(),
  duration: t.bigint().notNull(),
  tokenId: t.bigint().notNull(),
}))

export const Pool = onchainTable('pools', (t) => ({
  id: t.text().primaryKey(),
  chainId: t.integer().notNull(),
  blockTimestamp: t.bigint().notNull(),
  transactionHash: t.text().notNull(),
  contractAddress: t.hex().notNull(),
  // --- attributes
  poolId: t.hex().notNull(),
  hookAddress: t.hex(),
  currency0: t.hex().notNull(),
  currency1: t.hex().notNull(),
}))

// ===========================================================================
//                                   RELATIONS
// ===========================================================================

export const boardRelations = relations(Board, ({ many }) => ({
  initiatives: many(Initiative),
}))

export const initiativeRelations = relations(Initiative, ({ one, many }) => ({
  board: one(Board),
  bonds: many(Bond),
  weights: many(InitiativeWeight),
}))

export const bondRelations = relations(Bond, ({ one }) => ({
  initiative: one(Initiative, {
    fields: [Bond.initiativeId, Bond.contractAddress, Bond.chainId],
    references: [Initiative.initiativeId, Initiative.contractAddress, Initiative.chainId],
  }),
}))

export const weightRelations = relations(InitiativeWeight, ({ one }) => ({
  initiative: one(Initiative, {
    fields: [
      InitiativeWeight.initiativeId,
      InitiativeWeight.contractAddress,
      InitiativeWeight.chainId,
    ],
    references: [Initiative.initiativeId, Initiative.contractAddress, Initiative.chainId],
  }),
}))
