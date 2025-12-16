import { db, publicClients } from 'ponder:api'
import { Context } from 'hono'
import { SignalsABI } from '../../../../packages/abis'
import { getClientByChainId } from '../utils/get-client-by-chain-id'
import { transform } from '../utils/transform'

/**
 * @route GET /stats/:chainId/:address
 * @returns Basic board stats: active initiatives, unique supporters, and total locked (humanized)
 */
export const getStats = async (c: Context) => {
  const chainId = Number(c.req.param('chainId'))
  const address = c.req.param('address').toLowerCase() as `0x${string}`

  const board = await db.query.Board.findFirst({
    where: (board, { and, eq }) =>
      and(eq(board.chainId, chainId), eq(board.contractAddress, address)),
  })

  if (!board) {
    return c.json({ error: 'Board not found' }, 404)
  }

  const client = getClientByChainId(publicClients, chainId)
  if (!client) {
    return c.json({ error: `Unsupported chainId: ${chainId}` }, 400)
  }

  const initiatives = await db.query.Initiative.findMany({
    where: (initiative, { and, eq }) =>
      and(eq(initiative.chainId, chainId), eq(initiative.contractAddress, address)),
  })

  const initiativeStates = await Promise.all(
    initiatives.map(async (initiative) => {
      const initiativeState = (await client.readContract({
        address,
        abi: SignalsABI,
        functionName: 'getInitiative',
        args: [BigInt(initiative.initiativeId)],
      })) as { state: number }

      return initiativeState.state
    }),
  )

  const activeInitiativeCount = initiativeStates.filter((state) => state === 0).length

  const locks = await db.query.Lock.findMany({
    where: (lock, { and, eq }) =>
      and(
        eq(lock.chainId, chainId),
        eq(lock.contractAddress, address),
        eq(lock.isActive, true),
      ),
  })

  const uniqueSupporters = new Set(locks.map((lock) => lock.owner.toLowerCase())).size
  const totalLockedRaw = locks.reduce((sum, lock) => sum + lock.nominalValue, 0n)
  const totalLocked =
    Number(totalLockedRaw) / 10 ** (board.underlyingTokenDecimals ?? 18)

  return c.json(
    transform({
      activeInitiativeCount,
      uniqueSupporters,
      totalLocked,
    }),
  )
}
