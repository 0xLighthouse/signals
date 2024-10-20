export type Lock = {
  tokenAmount: number;
  lockDuration: number;
  created: number;
  withdrawn: boolean;
}

export type InitiativeDetails = {
  created: number;
  lockInterval: number;
  decayCurveType: number;
  decayCurveParameters: number[];
}

// Weight is a list of chart points, in which key is the X-axis (unix timestamp) and value is the Y-axis (weight)
export type Weight = Array<{ key: number; value: number }>;

// Populate initiative details and array of locks from the smart contract. Make sure all numbers are presented as decimals.
// From and until are unix timestamps to show the range of the data requested (optional). Period is the interval between each point in the chart in seconds.
export function calculateWeight(initiativeDetails: InitiativeDetails, locks: Lock[], from: number, until: number, period: number): Weight {
  if (!from) from = initiativeDetails.created;

  let intervals: number[] = [0];
  let labels: number[] = [from];
  
  locks.forEach((lock) => {
    // Get the first period after the lock was created
    let start = (lock.created - from) % period + lock.created;

    // How many periods is that from the start?
    let startp = (start - from) / period;

    // Make sure we have enough labels and intervals to start
    for (let i = labels.length - 1; i <= startp; i++) {
      labels.push(from + i * period);
      intervals.push(0);
    }

    let w = lock.tokenAmount * lock.lockDuration;
    for (let i = startp; w > 0 && (until ? labels[i] <= until : true); i++) {
      // Make sure we have enough to continue
      if (labels.length <= i) {
        labels.push(from + i * period);
        intervals.push(0);
      }

      // Get lock interval
      let lockInterval = Math.floor((labels[i] - lock.created) / period);
      switch (initiativeDetails.decayCurveType) {
        case 0:
          w = linear(initiativeDetails.decayCurveParameters, lock.tokenAmount, lockInterval, lock.lockDuration, lock.withdrawn);
          break;
        case 1:
          w = exponential(initiativeDetails.decayCurveParameters, lock.tokenAmount, lockInterval, lock.lockDuration, lock.withdrawn);
          break;
        default:
          break;
      }
      intervals[i] += w;
    }
  });

  // Fill in empties until until
  for (let i = labels.length - 1; until ? labels[i] <= until : true; i++) {
    labels.push(from + i * period);
    intervals.push(0);
  }

  return labels.map((key, i) => ({ key, value: intervals[i] }));
}

function linear(parameters: number[], amount: number, duration: number, interval: number, withdrawn: boolean): number {
  if (duration <= interval && withdrawn) return 0;
  let w = amount * duration - amount * interval * parameters[0];
  return Math.max(w, amount);
}

function exponential(parameters: number[], amount: number, duration: number, interval: number, withdrawn: boolean): number {
  if (duration <= interval && withdrawn) return 0;
  let w = amount * duration * Math.pow(parameters[0], interval);
  return Math.max(w, amount);
}