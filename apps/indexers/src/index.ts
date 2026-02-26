import { ponder } from 'ponder:registry'
import schema from 'ponder:schema'
import { SignalsABI, Erc20ABI } from '../../../packages/abis'
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
  const initiativeKey = `${context.chain.id}:${event.log.address}:${event.args.initiativeId}`

  await context.db.insert(schema.Initiative).values({
    id: initiativeKey,
    chainId: context.chain.id,
    contractAddress: event.log.address,
    blockTimestamp: event.block.timestamp,
    transactionHash: event.transaction.hash,
    initiativeId: Number(event.args.initiativeId),
    proposer: event.args.proposer,
    state: 'Proposed',
    title: event.args.metadata.title,
    body: event.args.metadata.body,
    attachments:
      event.args.metadata.attachments?.map((attachment) => ({
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
    await context.db.update(schema.Lock, { id: key }).set({
      burnedAt: event.block.timestamp,
      burnedTransactionHash: event.transaction.hash,
      isActive: false,
    })
  }
  // Handle regular transfer
  else {
    // Update NFT owner
    await context.db.update(schema.Lock, { id: key }).set({
      owner: to as `0x${string}`,
    })
  }
})

ponder.on('SignalsBoard:Redeemed', async ({ event, context }) => {
  const key = `${context.chain.id}:${event.log.address}:${event.args.tokenId}`

  await context.db.update(schema.Lock, { id: key }).set({
    burnedAt: event.block.timestamp,
    burnedTransactionHash: event.transaction.hash,
    isActive: false,
  })
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
  await context.db.insert(schema.Lock).values({
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

/**
 * Index the opensAt timestamp change event
 */
ponder.on('SignalsBoard:OpensAtChanged', async ({ event, context }) => {
  const boardKey = `${context.chain.id}:${event.log.address}`

  await context.db.update(schema.Board, { id: boardKey }).set({
    opensAt: event.args.opensAt,
  })
})

/**
 * Index the initiative accepted event
 */
ponder.on('SignalsBoard:InitiativeAccepted', async ({ event, context }) => {
  console.log('SignalsBoard:InitiativeAccepted', event)
  const initiativeKey = `${context.chain.id}:${event.log.address}:${event.args.initiativeId}`

  await context.db.update(schema.Initiative, { id: initiativeKey }).set({
    state: 'Accepted',
    acceptedAt: event.block.timestamp,
    acceptedBy: event.args.actor as `0x${string}`,
  })
})

ponder.on('SignalsFactory:BoardCreated', async ({ event, context }) => {
  const boardKey = `${context.chain.id}:${event.args.board}`

  // Read version
  const version: string = (await context.client.readContract({
    address: event.args.board,
    abi: SignalsABI,
    functionName: 'version',
  })) as string

  // Read underlyingToken
  const underlyingToken: `0x${string}` = (await context.client.readContract({
    address: event.args.board,
    abi: SignalsABI,
    functionName: 'underlyingToken',
  })) as `0x${string}`

  // Read underlyingToken metadata
  const underlyingTokenSymbol: string = (await context.client.readContract({
    address: underlyingToken,
    abi: Erc20ABI,
    functionName: 'symbol',
  })) as string

  const underlyingTokenDecimals: number = (await context.client.readContract({
    address: underlyingToken,
    abi: Erc20ABI,
    functionName: 'decimals',
  })) as number

  const underlyingTokenName: string = (await context.client.readContract({
    address: underlyingToken,
    abi: Erc20ABI,
    functionName: 'name',
  })) as string

  // Read opensAt and closesAt
  const opensAt: bigint = (await context.client.readContract({
    address: event.args.board,
    abi: SignalsABI,
    functionName: 'opensAt',
  })) as bigint

  const closesAt: bigint = (await context.client.readContract({
    address: event.args.board,
    abi: SignalsABI,
    functionName: 'closesAt',
  })) as bigint

  // Read acceptanceCriteria (full struct)
  const acceptanceCriteria = (await context.client.readContract({
    address: event.args.board,
    abi: SignalsABI,
    functionName: 'getAcceptanceCriteria',
  })) as any

  // Read proposerRequirements
  const proposerRequirements = await context.client.readContract({
    address: event.args.board,
    abi: SignalsABI,
    functionName: 'getProposerRequirements',
  })

  // Read supporterRequirements (was called participantRequirements)
  const supporterRequirements = await context.client.readContract({
    address: event.args.board,
    abi: SignalsABI,
    functionName: 'getParticipantRequirements',
  })

  // Read lockingConfig fields
  const lockInterval: bigint = (await context.client.readContract({
    address: event.args.board,
    abi: SignalsABI,
    functionName: 'lockInterval',
  })) as bigint

  const maxLockIntervals: bigint = (await context.client.readContract({
    address: event.args.board,
    abi: SignalsABI,
    functionName: 'maxLockIntervals',
  })) as bigint

  const releaseLockDuration: bigint = (await context.client.readContract({
    address: event.args.board,
    abi: SignalsABI,
    functionName: 'releaseLockDuration',
  })) as bigint

  const inactivityTimeout: bigint = (await context.client.readContract({
    address: event.args.board,
    abi: SignalsABI,
    functionName: 'inactivityTimeout',
  })) as bigint

  // Read decayConfig fields
  const decayCurveType: number = (await context.client.readContract({
    address: event.args.board,
    abi: SignalsABI,
    functionName: 'decayCurveType',
  })) as unknown as number

  const decayCurveParameters: number = (await context.client.readContract({
    address: event.args.board,
    abi: SignalsABI,
    functionName: 'decayCurveParameters',
    args: [0n] as const,
  })) as unknown as number

  // Insert board record with full BoardConfig
  await context.db.insert(schema.Board).values({
    id: boardKey,
    chainId: context.chain.id,
    blockTimestamp: event.block.timestamp,
    transactionHash: event.transaction.hash,
    contractAddress: event.args.board,
    // BoardConfig fields
    version: version,
    owner: event.args.owner,
    underlyingToken: underlyingToken,
    underlyingTokenSymbol: underlyingTokenSymbol,
    underlyingTokenDecimals: underlyingTokenDecimals,
    underlyingTokenName: underlyingTokenName,
    opensAt: opensAt,
    closesAt: closesAt,
    boardMetadata: {
      title: event.args.boardMetadata.title,
      body: event.args.boardMetadata.body,
      attachments: event.args.boardMetadata.attachments?.map((attachment) => ({
        uri: attachment.uri,
        mimeType: attachment.mimeType,
        description: attachment.description,
      })) ?? [],
    },
    acceptanceCriteria: replaceBigInts(acceptanceCriteria, (x) => x.toString()),
    proposerRequirements: replaceBigInts(proposerRequirements, (x) => x.toString()),
    supporterRequirements: replaceBigInts(supporterRequirements, (x) => x.toString()),
    lockingConfig: {
      lockInterval: lockInterval.toString(),
      maxLockIntervals: maxLockIntervals.toString(),
      releaseLockDuration: releaseLockDuration.toString(),
      inactivityTimeout: inactivityTimeout.toString(),
    },
    decayConfig: {
      curveType: decayCurveType,
      params: [decayCurveParameters.toString()],
    },
  })
})
