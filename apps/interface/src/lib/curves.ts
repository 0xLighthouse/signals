export interface Lock {
  tokenAmount: number // amount of toekens, as a decimal
  lockDuration: number // duration of the lock in intervals
  createdAt: number // unix timestamp of when the lock was created
  withdrawn: boolean // if the lock has been withdrawn
}

export interface InitiativeDetails {
  createdAt: number // unix timestamp of when the initative was created
  lockInterval: number // lock interval in seconds
  decayCurveType: number // decay curve type
  decayCurveParameters: number[] // decay curve parameters
}

// Weight is a list of chart points, in which key is the X-axis (unix timestamp) and value is the Y-axis (weight)
export type Weight = Array<{ x: number; y: number }>

// Populate initiative details and array of locks from the smart contract. Make sure all numbers are presented as decimals.
// From and until are unix timestamps to show the range of the data requested (optional). ChartInterval is the difference in seconds between each point on the x-axis.
export function calculateWeight(
  initiative: InitiativeDetails,
  locks: Lock[],
  chartInterval: number,
  startsAt?: number,
  endsAt?: number,
): Weight {
  // If there is no start time, use the creation time of the initiative
  if (!startsAt) startsAt = initiative.createdAt
  // If there is no end time, find the lock that lasts the longest and set that as the end time
  if (!endsAt) {
    endsAt = getDefaultEnd(locks, initiative.lockInterval)
  }

  // Create the arrays to hold the x and y values
  let xvals: number[] = []
  let yvals: number[] = []
  for (let i = startsAt; i <= endsAt; i += chartInterval) {
    xvals.push(i)
    yvals.push(0)
  }

  for (const lock of locks) {
    // Get the timestamp of the first x-axis tick after the lock was created
    const firstTickTime = ((lock.createdAt - startsAt) % chartInterval) + lock.createdAt

    // How many ticks is that from the start of the data?
    const tickIndex = Math.floor((firstTickTime - startsAt) / chartInterval)

    // temp sanity check
    if (xvals.length < tickIndex || xvals[tickIndex] !== firstTickTime) {
      console.error('Error in calculateWeight: xvals and firstTickTime do not match')
      console.log('xvals:', xvals)
      console.log('firstTickTime:', firstTickTime)
      console.log('tickIndex:', tickIndex)
      console.log('xval length', xvals.length)
      return []
    }

    for (let i = tickIndex; i < xvals.length; i++) {
      // For the timestamp of each tick, find the corresponding lock interval
      const lockInterval = _timeToLockInterval(lock, xvals[i], initiative.lockInterval)
      // Find the weight value for that lock interval
      let weightAtInterval = 0
      switch (initiative.decayCurveType) {
        case 0:
          weightAtInterval = _linear(
            initiative.decayCurveParameters,
            lock.tokenAmount,
            lock.lockDuration,
            lockInterval,
            lock.withdrawn,
          )
          break
        case 1:
          weightAtInterval = _exponential(
            initiative.decayCurveParameters,
            lock.tokenAmount,
            lock.lockDuration,
            lockInterval,
            lock.withdrawn,
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

export function getDefaultEnd(locks: Lock[], lockInterval: number): number {
  return locks.reduce(
    (max, lock) => Math.max(max, lock.createdAt + lock.lockDuration * lockInterval),
    0,
  )
}

function _timeToLockInterval(lock: Lock, timestamp: number, lockInterval: number): number {
  return Math.floor((timestamp - lock.createdAt) / lockInterval)
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
  let w = amount * duration * Math.pow(parameters[0], interval)
  return Math.max(w, amount)
}
