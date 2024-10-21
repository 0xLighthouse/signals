export interface Lock {
  tokenAmount: number
  lockDuration: number
  createdAt: number
  withdrawn: boolean
}

export interface InitiativeDetails {
  createdAt: number
  lockInterval: number
  decayCurveType: number
  decayCurveParameters: number[]
}

// Weight is a list of chart points, in which key is the X-axis (unix timestamp) and value is the Y-axis (weight)
export type Weight = Array<{ key: number; value: number }>

// Populate initiative details and array of locks from the smart contract. Make sure all numbers are presented as decimals.
// From and until are unix timestamps to show the range of the data requested (optional). Period is the interval between each point in the chart in seconds.
export function calculateWeight(
  initiative: InitiativeDetails,
  locks: Lock[],
  startsAt: number,
  endsAt: number,
  chartInterval: number,
): Weight {
  if (!startsAt) startsAt = initiative.createdAt

  let intervals: number[] = [0]
  let labels: number[] = [startsAt]

  for (const lock of locks) {
    // Get the first period after the lock was created
    let start = ((lock.createdAt - startsAt) % chartInterval) + lock.createdAt

    // How many periods is that from the start?
    let startPeriod = (start - startsAt) / chartInterval

    // Make sure we have enough labels and intervals to start
    for (let i = labels.length - 1; i <= startPeriod; i++) {
      labels.push(startsAt + i * chartInterval)
      intervals.push(0)
    }

    let w = lock.tokenAmount * lock.lockDuration
    for (let i = startPeriod; w > 0 && (endsAt ? labels[i] <= endsAt : true); i++) {
      // Make sure we have enough to continue
      if (labels.length <= i) {
        labels.push(startsAt + i * chartInterval)
        intervals.push(0)
      }

      // Get lock interval
      let lockInterval = Math.floor((labels[i] - lock.createdAt) / chartInterval)
      switch (initiative.decayCurveType) {
        case 0:
          w = _linear(
            initiative.decayCurveParameters,
            lock.tokenAmount,
            lockInterval,
            lock.lockDuration,
            lock.withdrawn,
          )
          break
        case 1:
          w = _exponential(
            initiative.decayCurveParameters,
            lock.tokenAmount,
            lockInterval,
            lock.lockDuration,
            lock.withdrawn,
          )
          break
        default:
          break
      }
      intervals[i] += w
    }
  }

  // Fill in empties until until
  for (let i = labels.length - 1; endsAt ? labels[i] <= endsAt : true; i++) {
    labels.push(startsAt + i * chartInterval)
    intervals.push(0)
  }

  return labels.map((key, i) => ({ key, value: intervals[i] }))
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
