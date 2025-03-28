import { InitiativeLock } from '@/indexers/api/types'
import { ChartLock } from './chart'

// FIXME: This type needs to be merged into our indexer types
export interface InitiativeDetails {
  createdAt: number // unix timestamp of when the initative was created
  lockInterval: number | null // lock interval in seconds
  decayCurveType: number | null // decay curve type
  decayCurveParameters: number[] | null // decay curve parameters
}

// Weight is a list of chart points, in which key is the X-axis (unix timestamp) and value is the Y-axis (weight)
export type Weight = Array<{ x: number; y: number }>

// Populate initiative details and array of locks from the smart contract. Make sure all numbers are presented as decimals.
// From and until are unix timestamps to show the range of the data requested (optional). ChartInterval is the difference in seconds between each point on the x-axis.
export function calculateWeight(
  initiative: InitiativeDetails,
  locks: ChartLock[],
  chartInterval: number,
  startsAt?: number,
  endsAt?: number,
): Weight {
  if (!initiative.lockInterval || initiative.lockInterval === 0) {
    throw new Error('Lock interval is not set')
  }
  if (!initiative.decayCurveParameters || initiative.decayCurveParameters.length === 0) {
    throw new Error('Decay curve parameters is not set')
  }
  // If there is no start time, use the creation time of the initiative
  if (!startsAt) startsAt = initiative.createdAt
  // If there is no end time, find the lock that lasts the longest and set that as the end time
  if (!endsAt) {
    endsAt = getDefaultEnd(locks, initiative.lockInterval)
  }

  // Create the arrays to hold the x and y values
  const xvals: number[] = []
  const yvals: number[] = []
  for (let i = startsAt; i <= endsAt; i += chartInterval) {
    xvals.push(i)
    yvals.push(0)
  }

  for (const lock of locks) {
    for (let i = 0; i < xvals.length; i++) {
      if (lock.createdAt > xvals[i]) continue

      const interval = Math.floor((xvals[i] - Number(lock.createdAt)) / initiative.lockInterval)
      let weightAtInterval = 0
      switch (initiative.decayCurveType) {
        case 0:
          weightAtInterval = _linear(
            initiative.decayCurveParameters,
            Number(lock.nominalValueAsWAD),
            Number(lock.durationAsIntervals),
            interval,
            lock.isRedeemed,
          )
          break
        case 1:
          weightAtInterval = _exponential(
            initiative.decayCurveParameters,
            Number(lock.nominalValueAsWAD),
            Number(lock.durationAsIntervals),
            interval,
            lock.isRedeemed,
          )
          break
        default:
          break
      }
      yvals[i] += weightAtInterval
    }
  }

  return xvals.map((key, i) => ({ x: key, y: yvals[i] }))
}

// FIXME: We should use BigInt here
export function getDefaultEnd(locks: InitiativeLock[] | ChartLock[], lockInterval: number): number {
  return locks.reduce(
    (max, lock) =>
      Math.max(max, Number(lock.createdAt) + Number(lock.durationAsIntervals) * lockInterval),
    0,
  )
}

function _linear(
  parameters: number[],
  amount: number,
  duration: number,
  interval: number,
  withdrawn: boolean,
): number {
  if (duration <= interval && withdrawn) return 0
  const w = amount * duration - amount * interval * parameters[0]
  return Math.max(w, amount)
}

function _exponential(
  parameters: number[],
  amount: number,
  duration: number,
  interval: number,
  withdrawn: boolean,
): number {
  if (duration <= interval && withdrawn) return 0
  const w = amount * duration * Math.pow(parameters[0], interval)
  return Math.max(w, amount)
}
