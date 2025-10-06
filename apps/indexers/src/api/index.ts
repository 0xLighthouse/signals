import { db } from 'ponder:api'
import schema from 'ponder:schema'
import { Hono } from 'hono'
import { client, graphql } from 'ponder'
import { getLocks } from './get.locks'
import { getInitiatives } from './get.initiatives'
import { getInitiativeLocks } from './get.initiative-locks'

const app = new Hono()

app.use('/sql/*', client({ db, schema }))

app.use('/', graphql({ db, schema }))
app.use('/graphql', graphql({ db, schema }))

/**
 * @returns List initiatives for a given chainId and address
 * @example http://localhost:42069/initiatives/421614/0x7E00a6dfF783649fB3017151652448647600D47E
 */
app.get('/initiatives/:chainId/:address', getInitiatives)
app.get('/locks/:chainId/:address/:initiativeId', getInitiativeLocks)

/**
 * @returns List bonds for a given chainId and address
 */
app.get('/bonds/:chainId/:address/:supporter', getLocks)

export default app
