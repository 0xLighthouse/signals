import { ponder } from 'ponder:registry'
import schema from 'ponder:schema'

ponder.on('SignalsFactory:SignalsCreated', async ({ event, context }) => {
  await context.db.insert(schema.FactoryCreatedEvent).values({
    id: event.log.id,
    chainId: context.network.chainId,
    blockTimestamp: event.block.timestamp,
    transactionHash: event.transaction.hash,
    owner: event.args.owner,
    newSignals: event.args.newSignals,
  })
})
