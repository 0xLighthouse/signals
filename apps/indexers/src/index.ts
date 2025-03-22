import { ponder } from 'ponder:registry'
import schema from 'ponder:schema'
import { SignalsABI } from '../../../packages/abis'

ponder.on('SignalsBoard:InitiativeProposed', async ({ event, context }) => {
  console.log('SignalsBoard:InitiativeProposed', event.args)
  // const hooks = await context.client.readContract({
  //   address: event.log.address,
  //   abi: SignalsABI,
  //   functionName: ,
  // })
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
})

ponder.on('SignalsFactory:BoardCreated', async ({ event, context }) => {
  /**
   * TODO: Patch additional board metadata
   */
  const [proposalThreshold, acceptanceThreshold] = await Promise.all([
    context.client.readContract({
      address: event.args.board,
      abi: SignalsABI,
      functionName: 'proposalThreshold',
    }),
    context.client.readContract({
      address: event.args.board,
      abi: SignalsABI,
      functionName: 'acceptanceThreshold',
    }),
  ])

  await context.db.insert(schema.Board).values({
    id: event.id,
    chainId: context.network.chainId,
    blockTimestamp: event.block.timestamp,
    transactionHash: event.transaction.hash,
    owner: event.args.owner,
    board: event.args.board,
    proposalThreshold,
    acceptanceThreshold,
  })
})

// ponder.on('Signals:InitiativeProposed', async ({ event, context }) => {
//   await context.db.insert(schema.InitiativeProposedEvent).values({
//     id: event.id,
//     chainId: context.network.chainId,
//     contractAddress: event.log.address,
//     blockTimestamp: event.block.timestamp,
//     transactionHash: event.transaction.hash,
//     initiativeId: Number(event.args.initiativeId),
//     proposer: event.args.proposer,
//     title: event.args.title,
//     body: event.args.body,
//   })
// })

// ponder.on('Signals:InitiativeSupported', async ({ event, context }) => {
//   await context.db.insert(schema.InitiativeSupportedEvent).values({
//     id: event.id,
//     chainId: context.network.chainId,
//     contractAddress: event.log.address,
//     blockTimestamp: event.block.timestamp,
//     transactionHash: event.transaction.hash,
//     initiativeId: Number(event.args.initiativeId),
//     supporter: event.args.supporter,
//     amount: event.args.tokenAmount,
//     lockDuration: Number(event.args.lockDuration),
//     // timestamp: event.block.timestamp,
//   })
// })

// FIXME: wtf is up with the types?
ponder.on('PoolManager:Initialize', async ({ event, context }) => {
  await context.db.insert(schema.PoolManagerInitializeEvent).values({
    id: event.id,
    chainId: context.network.chainId,
    contractAddress: event.log.address,
    blockTimestamp: event.block.timestamp,
    transactionHash: event.transaction.hash,
    // --- pool data
    hookAddress: event.args.hooks,
    // --- event data
    poolId: event.args.id,
  })
})

// FIXME: wtf is up with the types?
ponder.on('BondMarket:PoolInitialized', async ({ event, context }) => {
  await context.db.insert(schema.PoolManagerInitializeEvent).values({
    id: event.id,
    chainId: context.network.chainId,
    contractAddress: event.log.address,
    blockTimestamp: event.block.timestamp,
    transactionHash: event.transaction.hash,
    // --- pool data
    hookAddress: event.args.hooks,
    // --- event data
    poolId: event.args.id,
  })
})
