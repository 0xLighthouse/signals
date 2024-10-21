import { Lock, InitiativeDetails, Weight, getDefaultEnd, calculateWeight } from './curves'
import { DateTime } from 'luxon'

export interface ChartTick {
  label: string
  existingBase: number
  existingThreshold?: number
  inputBase?: number
  inputThreshold?: number
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
  {initiative, acceptanceThreshold, chartInterval}: { initiative: InitiativeDetails, acceptanceThreshold: number, chartInterval: number },
  newLock: Lock[] = []
): ChartTick[] {

  const startTime: number = DateTime.now().toUnixInteger() - chartInterval * 2
  const endTime: number = Math.max(
    getDefaultEnd(existingData, initiative.lockInterval),
    getDefaultEnd(newLock, initiative.lockInterval),
  )

  const normalisedExistingData = normaliseWeights(
    calculateWeight(initiative, existingData, chartInterval, startTime, endTime),
  )
  const normalisedInputData = normaliseWeights(
    calculateWeight(initiative, newLock, chartInterval, startTime, endTime),
  )

  const ticks: ChartTick[] = []

  for (let i = 0; i < normalisedExistingData.length; i++) {
    const existingWeight = normalisedExistingData[i].y
    const inputWeight = normalisedInputData[i].y

    const tick: ChartTick = {
      label: normalisedExistingData[i].label,
      existingBase: 0,
    }

    // If the existing weight is above the acceptance threshold, we need to split it
    if (existingWeight > acceptanceThreshold) {
      tick.existingBase = acceptanceThreshold
      tick.existingThreshold = existingWeight - acceptanceThreshold

      // If there is input weight, it must all be above the threshold
      if (inputWeight > 0) {
        tick.inputThreshold = inputWeight
      }

    } else {
      // Otherwise, all existing weight is below the threshold
      tick.existingBase = existingWeight

      // If there is input weight, we need to split it
      if (inputWeight > 0) {
        const remainingThreshold = acceptanceThreshold - existingWeight

        if (inputWeight > remainingThreshold) {
          tick.inputBase = remainingThreshold
          tick.inputThreshold = inputWeight - remainingThreshold
        } else {
          tick.inputBase = inputWeight
        }
      }
    }

    ticks.push(tick)
  }

  return ticks
}