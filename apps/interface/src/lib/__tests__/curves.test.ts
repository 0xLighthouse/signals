import { describe } from 'node:test'
import { calculateWeight, InitiativeDetails, Lock } from '../curves'
import { DateTime } from 'luxon'

const DECAY_TYPE_LINEAR = 0
const LINEAR_DECAY_RATE = 1.2
const DECAY_TYPE_EXPONENTIAL = 1
const EXPONENTIAL_DECAY_RATE = 0.75
const LOCK_INTERVAL = 60 * 60 * 24

/**
 * yarn jest apps/interface/src/lib/__tests__/curves.test.ts
 */
describe('curves', () => {
  it('calculates linear decay as expected', () => {
    const createdAt = DateTime.fromISO('2024-10-21T00:00:00.000Z')

    const initiative: InitiativeDetails = {
      createdAt: createdAt.toUnixInteger(),
      lockInterval: LOCK_INTERVAL,
      decayCurveType: DECAY_TYPE_LINEAR,
      decayCurveParameters: [LINEAR_DECAY_RATE],
    }

    const locks: Lock[] = []
    locks.push({
      tokenAmount: 50_000, // Lock 50,000 Gov tokens
      lockDuration: 10,
      createdAt: createdAt.toUnixInteger(),
      isWithdrawn: false,
    })

    const weights = calculateWeight(initiative, locks, LOCK_INTERVAL)

    expect(weights[0].y).toEqual(500_000)
    expect(weights[1].y).toEqual(500_000 - 50_000 * LINEAR_DECAY_RATE)
    expect(weights[10].y).toEqual(50_000)
  })

  it('calculates exponential decay as expected', () => {
    const createdAt = DateTime.fromISO('2024-10-21T00:00:00.000Z')

    const initiative: InitiativeDetails = {
      createdAt: createdAt.toUnixInteger(),
      lockInterval: LOCK_INTERVAL,
      decayCurveType: DECAY_TYPE_EXPONENTIAL,
      decayCurveParameters: [EXPONENTIAL_DECAY_RATE],
    }

    const locks: Lock[] = []
    locks.push({
      tokenAmount: 50_000, // Lock 50,000 Gov tokens
      lockDuration: 10,
      createdAt: createdAt.toUnixInteger(),
      isWithdrawn: false,
    })

    const weights = calculateWeight(initiative, locks, LOCK_INTERVAL)

    expect(weights[0].y).toEqual(500_000)
    expect(weights[1].y).toEqual(500_000 * EXPONENTIAL_DECAY_RATE)
    expect(weights[10].y).toEqual(50_000)
  })

  it('calculates multiple locks as expected', () => {
    const createdAt = DateTime.fromISO('2024-10-21T00:00:00.000Z')

    const initiative: InitiativeDetails = {
      createdAt: createdAt.toUnixInteger(),
      lockInterval: LOCK_INTERVAL,
      decayCurveType: DECAY_TYPE_EXPONENTIAL,
      decayCurveParameters: [EXPONENTIAL_DECAY_RATE],
    }

    const locks: Lock[] = []
    locks.push({
      tokenAmount: 30_000, // Lock 50,000 Gov tokens
      lockDuration: 10,
      createdAt: createdAt.plus({ day: 1 }).toUnixInteger(),
      isWithdrawn: false,
    })
    locks.push({
      tokenAmount: 40_000, // Lock 50,000 Gov tokens
      lockDuration: 10,
      createdAt: createdAt.plus({ day: 2 }).toUnixInteger(),
      isWithdrawn: false,
    })
    locks.push({
      tokenAmount: 50_000, // Lock 50,000 Gov tokens
      lockDuration: 10,
      createdAt: createdAt.plus({ day: 3 }).toUnixInteger(),
      isWithdrawn: false,
    })

    const weights = calculateWeight(initiative, locks, LOCK_INTERVAL)
    console.log(weights)

    // Total length should be 10 days after lock 3, which started on day 3 (plus 1 for day 0)
    const expectedLength = 14
    expect(weights.length).toEqual(expectedLength)

    // The final weight after all decay should be the sum of the initial lock amounts
    const expectedFinal = 30_000 + 40_000 + 50_000
    expect(weights[expectedLength - 1].y).toEqual(expectedFinal)

    // On day 3, lock 1 should be at interval 2, lock 2 at interval 1, and lock 3 at interval 0
    // The weights start with the multiplier (10x)
    const expected =
      300_000 * EXPONENTIAL_DECAY_RATE ** 2 + 400_000 * EXPONENTIAL_DECAY_RATE + 500_000
    expect(weights[3].y).toEqual(expected)
  })
})
