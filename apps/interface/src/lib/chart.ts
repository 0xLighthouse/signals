import { InitiativeLock } from '@/indexers/api/types'
import { InitiativeDetails, Weight, getDefaultEnd, calculateWeight } from './curves'
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

export type ChartLock = Omit<InitiativeLock, 'initiativeId' | 'tokenId'> & {
  nominalValueAsWAD: number
}

export function InitiativeLocksToChartLocks(locks: InitiativeLock[], decimals: number): ChartLock[] {
  return locks.map((lock) => ({
    ...lock,
    nominalValueAsWAD: Number(lock.nominalValue) / 10 ** decimals,
  }))
}

export function generateTicks(
  existingData: ChartLock[],
  { initiative, chartInterval, maxTimeWindow, minTimeWindow }: ChartOptions,
  newLock: ChartLock[] = [],
): ChartTick[] {
  if (!initiative.lockInterval || initiative.lockInterval === 0) {
    throw new Error('Lock interval is not set')
  }

  console.log('generateTicks()', existingData)

  const startTime: number = DateTime.now().toUnixInteger()
  const latestEndTime: number = Math.max(
    getDefaultEnd(existingData, initiative.lockInterval),
    getDefaultEnd(newLock, initiative.lockInterval),
  )

  const endTime: number = Math.max(
    Math.min(latestEndTime, startTime + maxTimeWindow),
    startTime + minTimeWindow,
  )

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

  return ticks
}
