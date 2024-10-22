import { describe } from 'node:test'
import { InitiativeDetails, Lock } from '../curves'
import { generateTicks, ChartOptions } from '../chart'
import { DateTime } from 'luxon'

const DECAY_TYPE_LINEAR = 0
const LINEAR_DECAY_RATE = 1.2
const DECAY_TYPE_EXPONENTIAL = 1
const EXPONENTIAL_DECAY_RATE = 0.75
const LOCK_INTERVAL = 60 * 60 * 24
const INITIATIVE_CREATED_AT = DateTime.fromISO('2024-10-21T00:00:00.000Z')
const CHART_OPTIONS: ChartOptions = {
  initiative: {
    createdAt: INITIATIVE_CREATED_AT.toUnixInteger(),
    lockInterval: LOCK_INTERVAL,
    decayCurveType: DECAY_TYPE_LINEAR,
    decayCurveParameters: [LINEAR_DECAY_RATE],
  },
  acceptanceThreshold: 500_000,
  chartInterval: LOCK_INTERVAL,
  minTimeWindow: 60 * 60 * 24 * 7,
  maxTimeWindow: 60 * 60 * 24 * 60,
}
const EXISTING_DATA: Lock[] = [
  {
    tokenAmount: 50_000,
    lockDuration: 10,
    createdAt: INITIATIVE_CREATED_AT.plus({day: 1}).toUnixInteger(),
    isWithdrawn: false,
  },
  {
    tokenAmount: 40_000,
    lockDuration: 10,
    createdAt: INITIATIVE_CREATED_AT.plus({day: 2}).toUnixInteger(),
    isWithdrawn: false,
  },
  {
    tokenAmount: 30_000,
    lockDuration: 10,
    createdAt: INITIATIVE_CREATED_AT.plus({day: 3}).toUnixInteger(),
    isWithdrawn: false,
  },
]

describe('chart', () => {
  it('generates basic chart data', () => {
    const initiative: InitiativeDetails = {
      createdAt: INITIATIVE_CREATED_AT.toUnixInteger(),
      lockInterval: LOCK_INTERVAL,
      decayCurveType: DECAY_TYPE_LINEAR,
      decayCurveParameters: [LINEAR_DECAY_RATE],
    }

    const ticks = generateTicks(EXISTING_DATA, CHART_OPTIONS)

    console.log(ticks)
    // expect(weights[0].y).toEqual(500_000)
    // expect(weights[1].y).toEqual(500_000 - 50_000 * LINEAR_DECAY_RATE)
    // expect(weights[10].y).toEqual(50_000)
  })

  it('generates chart data with passing threshold', () => {
    const initiative: InitiativeDetails = {
      createdAt: INITIATIVE_CREATED_AT.toUnixInteger(),
      lockInterval: LOCK_INTERVAL,
      decayCurveType: DECAY_TYPE_LINEAR,
      decayCurveParameters: [LINEAR_DECAY_RATE],
    }

    const ticks = generateTicks(EXISTING_DATA, CHART_OPTIONS)

    console.log(ticks)
    // expect(weights[0].y).toEqual(500_000)
    // expect(weights[1].y).toEqual(500_000 - 50_000 * LINEAR_DECAY_RATE)
    // expect(weights[10].y).toEqual(50_000)
  })

  it('generates chart data with input preview', () => {
    const initiative: InitiativeDetails = {
      createdAt: INITIATIVE_CREATED_AT.toUnixInteger(),
      lockInterval: LOCK_INTERVAL,
      decayCurveType: DECAY_TYPE_LINEAR,
      decayCurveParameters: [LINEAR_DECAY_RATE],
    }

    const ticks = generateTicks(EXISTING_DATA, CHART_OPTIONS, [{
      tokenAmount: 50_000,
      lockDuration: 20,
      createdAt: INITIATIVE_CREATED_AT.plus({day: 2}).toUnixInteger(),
      isWithdrawn: false,
    }])

    console.log(ticks)
    // expect(weights[0].y).toEqual(500_000)
    // expect(weights[1].y).toEqual(500_000 - 50_000 * LINEAR_DECAY_RATE)
    // expect(weights[10].y).toEqual(50_000)
  })
})
