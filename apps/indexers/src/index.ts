import { ponder } from 'ponder:registry'
import schema from 'ponder:schema'
import { SignalsABI } from '../../../packages/abis'

ponder.on('SignalsBoard:InitiativeProposed', async ({ event, context }) => {
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

ponder.on('Incentives:IncentiveAdded', async ({ event, context }) => {
  await context.db.insert(schema.Incentive).values({
    id: event.id,
    chainId: context.network.chainId,
    contractAddress: event.log.address,
    blockTimestamp: event.block.timestamp,
    transactionHash: event.transaction.hash,
    initiativeId: event.args.initiativeId,
    incentiveId: event.args.incentiveId,
    token: event.args.token,
    amount: event.args.amount,
    expiresAt: event.args.expiresAt,
    terms: event.args.terms,
  })
})

ponder.on('SignalsBoard:Transfer', async ({ event, context }) => {
  console.log('SignalsBoard:Transfer', event)

  const { from, to, tokenId } = event.args

  // Create transfer record
  // FIXME: Not really needed, but we can use it to track the history of the bond
  await context.db.insert(schema.Transfer).values({
    id: event.id,
    chainId: context.network.chainId,
    blockTimestamp: event.block.timestamp,
    transactionHash: event.transaction.hash,
    contractAddress: event.log.address,
    // --- attributes
    from: from as `0x${string}`,
    to: to as `0x${string}`,
    tokenId: tokenId,
  })

  const key = `${context.network.chainId}:${event.log.address}:${tokenId}`

  // Handle mint (from zero address)
  if (from === '0x0000000000000000000000000000000000000000') {
    // No-op, we'll handle this in the initiative supported event
  }
  // Handle burn (to zero address)
  else if (to === '0x0000000000000000000000000000000000000000') {
    await context.db.update(schema.Bond, { id: key }).set({
      burnedAt: event.block.timestamp,
      isActive: false,
    })
  }
  // Handle regular transfer
  else {
    // Update NFT owner
    await context.db.update(schema.Bond, { id: key }).set({
      owner: to as `0x${string}`,
    })
  }
})

ponder.on('SignalsBoard:InitiativeSupported', async ({ event, context }) => {
  console.log('SignalsBoard:InitiativeSupported', event)
  await context.db.insert(schema.InitiativeWeight).values({
    id: event.id,
    chainId: context.network.chainId,
    contractAddress: event.log.address,
    blockTimestamp: event.block.timestamp,
    transactionHash: event.transaction.hash,
    // --- event data
    initiativeId: Number(event.args.initiativeId),
    weight: event.args.tokenAmount,
    supporter: event.args.supporter,
    duration: event.args.lockDuration,
    tokenId: event.args.tokenId,
  })

  const key = `${context.network.chainId}:${event.log.address}:${event.args.tokenId}`

  // Register the bond NFT separately, so we can track ownership
  await context.db.insert(schema.Bond).values({
    id: key,
    chainId: context.network.chainId,
    contractAddress: event.log.address,
    blockTimestamp: event.block.timestamp,
    // --- attributes
    owner: event.args.supporter as `0x${string}`,
    initiativeId: event.args.initiativeId,
    tokenId: event.args.tokenId,
    nominalValue: event.args.tokenAmount,
    durationAsIntervals: event.args.lockDuration,
    isActive: true,
  })
})

ponder.on('SignalsFactory:BoardCreated', async ({ event, context }) => {
  /**
   * TODO: Patch additional board metadata
   */
  const [proposalThreshold, acceptanceThreshold, underlyingToken] = await Promise.all([
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
    context.client.readContract({
      address: event.args.board,
      abi: SignalsABI,
      functionName: 'underlyingToken',
    }),
  ])

  await context.db.insert(schema.Board).values({
    id: event.id,
    chainId: context.network.chainId,
    blockTimestamp: event.block.timestamp,
    transactionHash: event.transaction.hash,
    contractAddress: event.args.board,
    owner: event.args.owner,
    proposalThreshold,
    acceptanceThreshold,
    underlyingToken,
  })
})

// FIXME: wtf is up with the types?
//  args: {
//   id: '0xd747d5c96aa744c2284ef5763974ac7c63e84ca7e0b6ba1c21d1ea0cbcda869e',
//   currency0: '0x2ed7De542Ce7377Bca3f3500dA4e7aF830889635',
//   currency1: '0x75e8927FFabD709D7e55Ed44C7a19166A0B215A7',
//   fee: 8388608,
//   tickSpacing: 60,
//   hooks: '0xd6F1Cd295Bf3cfeFA4c09B455A420edaEad478c0',
//   sqrtPriceX96: 79228162514264337593543950336n,
//   tick: 0
// },
// @ts-ignore
ponder.on('PoolManager:Initialize', async ({ event, context }) => {
  // console.log('PoolManager:Initialize', event)

  await context.db.insert(schema.Pool).values({
    id: event.id,
    chainId: context.network.chainId,
    contractAddress: event.log.address,
    blockTimestamp: event.block.timestamp,
    transactionHash: event.transaction.hash,
    // --- pool data
    // @ts-ignore
    hookAddress: event.args.hooks,
    // @ts-ignore
    currency0: event.args.currency0,
    // @ts-ignore
    currency1: event.args.currency1,
    // --- event data
    // @ts-ignore
    poolId: event.args.id,
  })
})

// FIXME: wtf is up with the types?
// NO needed
// ponder.on('BondMarket:PoolInitialized', async ({ event, context }) => {
//   console.log('BondMarket:PoolInitialized', event)

//   await context.db.insert(schema.PoolManagerInitializeEvent).values({
//     id: event.id,
//     chainId: context.network.chainId,
//     contractAddress: event.log.address,
//     blockTimestamp: event.block.timestamp,
//     transactionHash: event.transaction.hash,
//     // --- pool data
//     // @ts-ignore
//     hookAddress: event.args.hooks,
//     // --- event data
//     // @ts-ignore
//     poolId: event.args.id,
//   })
// })
