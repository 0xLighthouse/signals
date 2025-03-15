import { onchainTable } from 'ponder'

/**
 * Note: The variable name eventually becomes the GraphQL type name.
 */
export const FactoryCreatedEvent = onchainTable('factory_created_events', (t) => ({
  id: t.text().primaryKey(),
  chainId: t.integer().notNull(),
  blockTimestamp: t.bigint().notNull(),
  transactionHash: t.text().notNull(),
  owner: t.hex().notNull(),
  newSignals: t.hex().notNull(),
}))
