import { db } from 'ponder:api'
import schema from 'ponder:schema'
import { Hono } from 'hono'
import { client, graphql } from 'ponder'
import { getLocks } from './get.locks'
import { getInitiatives } from './get.initiatives'
import { getInitiativeLocks } from './get.initiative-locks'
import { getAccountLocks } from './get.account-locks'
import { getStats } from './get.stats'

const app = new Hono()

app.use('/sql/*', client({ db, schema }))

/**
 * @returns List initiatives for a given chainId and board address
 * @example http://localhost:42069/initiatives/31337/0xBoardAddress
 */
app.get('/initiatives/:chainId/:address', getInitiatives)

/**
 * @returns List locks for a given chainId, board address, and account address
 */
app.get('/locks/account/:chainId/:address/:accountAddress', getAccountLocks)

/**
 * @returns List locks for a given chainId, board address, and initiativeId
 */
app.get('/locks/:chainId/:address/:initiativeId', getInitiativeLocks)

/**
 * @returns List bonds owned by supporter for a given chainId and board address
 */
app.get('/bonds/:chainId/:address/:supporter', getLocks)

/**
 * @returns Board stats for a given chainId and board address
 */
app.get('/stats/:chainId/:address', getStats)

// Optionally expose GraphQL if needed by clients
app.use('/', graphql({ db, schema }))
app.use('/graphql', graphql({ db, schema }))

export default app
