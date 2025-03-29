import { schema } from 'ponder:schema'
import { PonderEvent, PonderContext } from 'ponder:registry'

export const handleInitiativeProposed = async ({
  event,
  context,
}: { event: PonderEvent<SignalsBoardInitiativeProposed>; context: PonderContext }) => {
  await context.db.insert(schema.Initiative).values({
    id: event.id,
    chainId: context.network.chainId,
    contractAddress: event.log.address,
    blockTimestamp: event.block.timestamp,
    transactionHash: event.transaction.hash,
    initiativeId: Number(event.args.initiativeId),
    proposer: event.args.proposer,
    title: event.args.title,
    body: event.args.body,
  })
}
