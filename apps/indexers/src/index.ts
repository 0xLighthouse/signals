import { ponder } from 'ponder:registry'
import schema from 'ponder:schema'
import { SignalsABI } from '../../../packages/abis'
import { IAuthorizer } from '../../../packages/abis/interfaces'
import { replaceBigInts } from "@ponder/utils";


ponder.on('ExperimentTokenFactory:TokenDeployed', async ({ event, context }) => {
  // Persist newly deployed token metadata
  await context.db.insert(schema.Token).values({
    id: event.id,
    chainId: context.chain.id,
    blockTimestamp: event.block.timestamp,
    transactionHash: event.transaction.hash,
    contractAddress: event.args.token as `0x${string}`,
    name: event.args.name,
    symbol: event.args.symbol,
  })
})

ponder.on('SignalsBoard:InitiativeProposed', async ({ event, context }) => {
  await context.db.insert(schema.Initiative).values({
    id: event.id,
    chainId: context.chain.id,
    contractAddress: event.log.address,
    blockTimestamp: event.block.timestamp,
    transactionHash: event.transaction.hash,
    initiativeId: Number(event.args.initiativeId),
    proposer: event.args.proposer,
    title: event.args.title,
    body: event.args.body,
    attachments:
      event.args.attachments?.map((attachment) => ({
        uri: attachment.uri,
        mimeType: attachment.mimeType,
        description: attachment.description,
      })) ?? [],
  })
})

// ponder.on('Incentives:IncentiveAdded', async ({ event, context }) => {
//   await context.db.insert(schema.Incentive).values({
//     id: event.id,
//     chainId: context.network.chainId,
//     contractAddress: event.log.address,
//     blockTimestamp: event.block.timestamp,
//     transactionHash: event.transaction.hash,
//     initiativeId: event.args.initiativeId,
//     incentiveId: event.args.incentiveId,
//     token: event.args.token,
//     amount: event.args.amount,
//     expiresAt: event.args.expiresAt,
//     terms: event.args.terms,
//   })
// })

ponder.on('SignalsBoard:Transfer', async ({ event, context }) => {
  console.log('SignalsBoard:Transfer', event)

  const { from, to, tokenId } = event.args

  // Create transfer record
  // FIXME: Not really needed, but we can use it to track the history of the bond
  await context.db.insert(schema.Transfer).values({
    id: event.id,
    chainId: context.chain.id,
    blockTimestamp: event.block.timestamp,
    transactionHash: event.transaction.hash,
    contractAddress: event.log.address,
    // --- attributes
    from: from as `0x${string}`,
    to: to as `0x${string}`,
    tokenId: tokenId,
  })

  const key = `${context.chain.id}:${event.log.address}:${tokenId}`

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
    chainId: context.chain.id,
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

  const key = `${context.chain.id}:${event.log.address}:${event.args.tokenId}`

  // Register the bond NFT separately, so we can track ownership
  await context.db.insert(schema.Bond).values({
    id: key,
    chainId: context.chain.id,
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

  const proposerRequirements: IAuthorizer.ParticipantRequirements = (await context.client.readContract({
    address: event.args.board,
    abi: SignalsABI,
    functionName: 'getProposerRequirements',
  })) as IAuthorizer.ParticipantRequirements


  const participantRequirements: IAuthorizer.ParticipantRequirements = (await context.client.readContract({
    address: event.args.board,
    abi: SignalsABI,
    functionName: 'getParticipantRequirements',
  })) as IAuthorizer.ParticipantRequirements

  console.log('proposerRequirements', proposerRequirements)
  console.log('participantRequirements', participantRequirements)

  const acceptanceThreshold: bigint = (await context.client.readContract({
    address: event.args.board,
    abi: SignalsABI,
    functionName: 'getAcceptanceThreshold',
  })) as bigint

  const underlyingToken: `0x${string}` = (await context.client.readContract({
    address: event.args.board,
    abi: SignalsABI,
    functionName: 'underlyingToken',
  })) as `0x${string}`

  await context.db.insert(schema.Board).values({
    id: event.id,
    chainId: context.chain.id,
    blockTimestamp: event.block.timestamp,
    transactionHash: event.transaction.hash,
    contractAddress: event.args.board,
    owner: event.args.owner,
    title: event.args.boardMetadata.title,
    body: event.args.boardMetadata.body,
    proposerRequirements: replaceBigInts(proposerRequirements, (x) => x.toString()),
    participantRequirements: replaceBigInts(participantRequirements, (x) => x.toString()),
    acceptanceThreshold: acceptanceThreshold,
    underlyingToken: underlyingToken as `0x${string}`,
  })
})
