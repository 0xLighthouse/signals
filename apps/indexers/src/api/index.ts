import { db } from 'ponder:api'
import schema from 'ponder:schema'
import { Hono } from 'hono'
import { client, graphql } from 'ponder'
import { getLocks } from './get.locks'
import { getInitiatives } from './get.initiatives'
import { getPools } from './get.pools'
import { getPoolState } from './get.pool-state'
import { getQuote } from './get.quote'

const app = new Hono()

app.use('/sql/*', client({ db, schema }))

app.use('/', graphql({ db, schema }))
app.use('/graphql', graphql({ db, schema }))

/**
 * @returns List initiatives for a given chainId and address
 * @example http://localhost:42069/initiatives/421614/0x7E00a6dfF783649fB3017151652448647600D47E
 */
app.get('/initiatives/:chainId/:address', getInitiatives)

/**
 * @returns List locks for a given chainId and address
 * @example http://localhost:42069/locks/421614/0x844c0dd2995cd430aab7ddd1dca3fb15836674bc/0x0000000000000000000000000000000000000000
 */
app.get('/locks/:chainId/:address/:supporter', getLocks)

/**
 * @returns List pools for a given chainId and currency
 * @example http://localhost:42069/pools/421614/0x75e8927FFabD709D7e55Ed44C7a19166A0B215A7
 */
app.get('/pools/:chainId/:currency', getPools)

/**
 * @returns Pool state for a given poolId
 */
app.get('/pool-state/:chainId/:poolId', getPoolState)

/**
 * @returns Quote for a given poolId and tokenId
 * @example http://localhost:42069/quote/421614/0xA429a75F874B899Ee6b0ea080d7281544506b8c0/1?type=user-buy
 * @example http://localhost:42069/quote/421614/0xA429a75F874B899Ee6b0ea080d7281544506b8c0/1?type=user-sell
 */
app.get('/quote/:chainId/:address/:tokenId', getQuote)

export default app
