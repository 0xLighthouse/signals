import { createClient } from '@ponder/client'
import * as ponderSchema from '../../../indexers/ponder.schema'

// https://signals-production-6591.up.railway.app/
const ENDPOINT = 'https://signals-production-6591.up.railway.app'

export const schema = ponderSchema
export const client = createClient(`${ENDPOINT}/sql`, { schema })
