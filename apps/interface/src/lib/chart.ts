import { Lock, InitiativeDetails, Weight, getDefaultEnd, calculateWeight } from './curves'
import { DateTime } from 'luxon'

export interface ChartTick {
  label: string
  existingBase: number
  existingThreshold?: number
  inputBase?: number
  inputThreshold?: number
}

export interface ChartOptions {
  initiative: InitiativeDetails
  acceptanceThreshold: number
  chartInterval: number
  maxTimeWindow: number
  minTimeWindow: number
}

const normaliseWeights = (weights: Weight) => {
  return weights.map((w) => ({
    ...w,
    weight: Math.round(w.y),
    label: DateTime.fromSeconds(w.x).toRelative(),
  }))
}

export function generateTicks(
  existingData: Lock[],
  {
    initiative,
    acceptanceThreshold,
    chartInterval,
    maxTimeWindow,
    minTimeWindow,
  }: ChartOptions,
  newLock: Lock[] = [],
): ChartTick[] {
  if (!initiative.lockInterval || initiative.lockInterval === 0) {
    throw new Error('Lock interval is not set')
  }

  console.log('existingData', existingData)

  const startTime: number = DateTime.now().toUnixInteger()
  const latestEndTime: number = Math.max(
    getDefaultEnd(existingData, initiative.lockInterval),
    getDefaultEnd(newLock, initiative.lockInterval),
  )

  const endTime: number = Math.max(Math.min(latestEndTime, startTime + maxTimeWindow), startTime + minTimeWindow)

  const normalisedExistingData = normaliseWeights(
    calculateWeight(initiative, existingData, chartInterval, startTime, endTime),
  )
  const normalisedInputData = normaliseWeights(
    calculateWeight(initiative, newLock, chartInterval, startTime, endTime),
  )

  const ticks: ChartTick[] = []
  for (let i = 0; i < normalisedExistingData.length; i++) {
    const tick: ChartTick = {
      label: normalisedExistingData[i].label,
      existingBase: normalisedExistingData[i].weight,
    }
    if (newLock.length > 0) {
      tick.inputBase = normalisedInputData[i].weight
    }
    ticks.push(tick)
  }

  // NOTE: The following is for segmenting portions above and below the threshold line into separate areas.
  // The library we are using right now doesn't look very good that way, so we are using a more simple version for now but may return to this later.

  // let hasExistingThreshold = false
  // let hasInputBase = false
  // let hasInputThreshold = false

  // for (let i = 0; i < normalisedExistingData.length; i++) {
  //   const existingWeight = normalisedExistingData[i].y
  //   const inputWeight = normalisedInputData[i].y

  //   const tick: ChartTick = {
  //     label: normalisedExistingData[i].label,
  //     existingBase: 0,
  //   }

  //   // If the existing weight is above the acceptance threshold, we need to split it
  //   if (existingWeight > acceptanceThreshold) {
  //     tick.existingBase = acceptanceThreshold
  //     tick.existingThreshold = existingWeight - acceptanceThreshold
  //     hasExistingThreshold = true

  //     // If there is input weight, it must all be above the threshold
  //     if (inputWeight > 0) {
  //       tick.inputThreshold = inputWeight
  //       hasInputThreshold = true
  //     }

  //   } else {
  //     // Otherwise, all existing weight is below the threshold
  //     tick.existingBase = existingWeight

  //     // If there is input weight, we need to split it
  //     if (inputWeight > 0) {
  //       const remainingThreshold = acceptanceThreshold - existingWeight

  //       if (inputWeight > remainingThreshold) {
  //         tick.inputBase = remainingThreshold
  //         tick.inputThreshold = inputWeight - remainingThreshold
  //         hasInputBase = true
  //         hasInputThreshold = true
  //       } else {
  //         tick.inputBase = inputWeight
  //         hasInputBase = true
  //       }
  //     }
  //   }

  //   ticks.push(tick)
  // }

  // // Fill in zeros for all areas we have
  // for (let i = 0; i < ticks.length; i++) {
  //   if (hasExistingThreshold) ticks[i].existingThreshold = ticks[i].existingThreshold || 0
  //   if (hasInputBase) ticks[i].inputBase = ticks[i].inputBase || 0
  //   if (hasInputThreshold) ticks[i].inputThreshold = ticks[i].inputThreshold || 0
  // }

  return ticks
}
