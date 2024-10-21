import { describe } from 'node:test'
import { calculateWeight, InitiativeDetails, Lock } from '../curves'
import { DateTime } from 'luxon'

const LINEAR_DECAY_RATE = [1.1]
const DECAY_TYPE_LINEAR = 0

/**
 * yarn jest apps/interface/src/lib/__tests__/curves.test.ts
 */
describe('curves', () => {
  it('calculates weights as expected', () => {
    const createdAt = DateTime.fromISO('2024-10-21T00:00:00.000Z')

    const initiative: InitiativeDetails = {
      createdAt: createdAt.toUnixInteger(),
      lockInterval: 10,
      decayCurveType: DECAY_TYPE_LINEAR,
      decayCurveParameters: LINEAR_DECAY_RATE,
    }

    const locks: Lock[] = []
    locks.push({
      tokenAmount: 50_000, // Lock 50,000 Gov tokens
      lockDuration: 10,
      createdAt: createdAt.plus({ days: 2 }).toUnixInteger(),
      withdrawn: false,
    })
    locks.push({
      tokenAmount: 50_000, // Lock 50,000 Gov tokens
      lockDuration: 10,
      createdAt: createdAt.plus({ days: 5 }).toUnixInteger(),
      withdrawn: false,
    })

    const startsAt = createdAt.toUnixInteger()
    const endsAt = createdAt.plus({ days: 10 }).toUnixInteger()
    const chartInterval = 10

    const weights = calculateWeight(initiative, locks, startsAt, endsAt, chartInterval)
    console.log(weights)
  })
})
