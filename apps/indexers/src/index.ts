import { ponder } from 'ponder:registry'
import schema from 'ponder:schema'

ponder.on('SignalsFactory:BoardCreated', async ({ event, context }) => {
  await context.db.insert(schema.BoardCreatedEvent).values({
    id: event.id,
    chainId: context.network.chainId,
    blockTimestamp: event.block.timestamp,
    transactionHash: event.transaction.hash,
    owner: event.args.owner,
    board: event.args.board,
  })
})

ponder.on('Signals:InitiativeProposed', async ({ event, context }) => {
  await context.db.insert(schema.InitiativeProposedEvent).values({
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
})

ponder.on('Signals:InitiativeSupported', async ({ event, context }) => {
  await context.db.insert(schema.InitiativeSupportedEvent).values({
    id: event.id,
    chainId: context.network.chainId,
    contractAddress: event.log.address,
    blockTimestamp: event.block.timestamp,
    transactionHash: event.transaction.hash,
    initiativeId: Number(event.args.initiativeId),
    supporter: event.args.supporter,
    amount: event.args.tokenAmount,
    lockDuration: Number(event.args.lockDuration),
    // timestamp: event.block.timestamp,
  })
})

ponder.on('PoolManager:Initialize', async ({ event, context }) => {
  console.log('PoolManager:Initialize()')
  console.log('PoolManager:Initialize()')
  console.log('PoolManager:Initialize()')
  await context.db.insert(schema.PoolManagerInitializeEvent).values({
    id: event.id,
    chainId: context.network.chainId,
    contractAddress: event.log.address,
    blockTimestamp: event.block.timestamp,
    transactionHash: event.transaction.hash,
    // --- event data
    poolId: event.args.poolId,
  })
})
