'use client'

import {
  CartesianGrid,
  Label,
  LabelList,
  AreaChart,
  ReferenceLine,
  XAxis,
  YAxis,
  Area,
} from 'recharts'

import {
  ChartConfig,
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
} from '@/components/ui/chart'
import { calculateWeight, getDefaultEnd, InitiativeDetails, Lock, Weight } from '@/lib/curves'
import { DateTime } from 'luxon'
import { use, useEffect, useState } from 'react'

export const description = 'A line chart with a custom label'

const chartConfig = {
  existingBase: {
    label: 'Current Weight',
    color: 'hsl(var(--chart-1))',
  },
  existingThreshold: {
    label: 'Weight Exceeding Threshold',
    color: 'hsl(var(--chart-2))',
  },
  inputBase: {
    label: 'New Weight',
    color: 'hsl(var(--chart-3))',
  },
  inputThreshold: {
    label: 'New Weight Exceeding Threshold',
    color: 'hsl(var(--chart-4))',
  },
} satisfies ChartConfig

/**
 * Given a round number  eg. 1000000, 500000, 20000
 * Normalise to 1M, 500k, 20k, etc
 */
const normaliseNumber = (value: number) => {
  const suffixes = ['', 'k', 'M', 'B', 'T']
  const suffixIndex = Math.floor(Math.log10(value) / 3)
  const suffix = suffixes[suffixIndex]
  // biome-ignore lint/style/useExponentiationOperator: <explanation>
  const normalisedValue = value / Math.pow(10, suffixIndex * 3)
  if (!normalisedValue) return ''
  return `${normalisedValue}${suffix}`
}

const normaliseWeights = (weights: Weight) => {
  return weights.map((w) => ({
    ...w,
    weight: Math.round(w.y),
    label: DateTime.fromSeconds(w.x).toRelative(),
  }))
}

interface chartItem {
  label: string
  existingBase: number
  existingThreshold ?: number
  inputBase ?: number
  inputThreshold ?: number
}

type chartData = Array<chartItem>

interface Props {
  initiative: InitiativeDetails
  locks: Lock[]
  chartInterval: number
  acceptanceThreshold?: number | null
  amountInput?: number
  durationInput?: number
}

export const Chart: React.FC<Props> = ({ initiative, locks, chartInterval, acceptanceThreshold, amountInput, durationInput }) => {
  acceptanceThreshold = acceptanceThreshold || Infinity
  const [data, setData] = useState<chartData>([])

  useEffect(() => {
    // Update chart if input data is provided
    let lockInput: Lock[] = []
    if (amountInput && durationInput) {
      lockInput.push({
        tokenAmount: amountInput,
        lockDuration: durationInput,
        createdAt: DateTime.now().toUnixInteger(),
        withdrawn: false,
      })
    }

    const startTime: number = DateTime.now().toUnixInteger() - chartInterval * 2
    const endTime: number = Math.max(getDefaultEnd(locks, initiative.lockInterval), getDefaultEnd(lockInput, initiative.lockInterval))

    const existingData = normaliseWeights(calculateWeight(initiative, locks, chartInterval, startTime, endTime))
    const inputData = normaliseWeights(calculateWeight(initiative, lockInput, chartInterval, startTime, endTime))

    let chartData: chartData = []
    for (let i = 0; i < existingData.length; i++) {
      const existingWeight = existingData[i].y
      const inputWeight = inputData[i].y

      let entry: chartItem = {
        label: existingData[i].label,
        existingBase: 0,
      }

      // If the existing weight is above the acceptance threshold, we need to split it
      if (existingWeight > acceptanceThreshold) {
        entry.existingBase = acceptanceThreshold
        entry.existingThreshold = existingWeight - acceptanceThreshold

        // If there is input weight, it must all be above the threshold
        if (inputWeight > 0) {
          entry.inputThreshold = inputWeight
        }
      } else { // Otherwise, all existing weight is below the threshold
        entry.existingBase = existingWeight

        // If there is input weight, we need to split it
        if (inputWeight > 0) {
          if (existingWeight + inputWeight > acceptanceThreshold) {
            entry.inputBase = acceptanceThreshold - existingWeight
            entry.inputThreshold = existingWeight + inputWeight - acceptanceThreshold - entry.inputBase
          } else {
            entry.inputBase = inputWeight
          }
        }
      }

      chartData.push(entry)
    }
    
    setData(chartData)
  }, [amountInput, durationInput])

  return (
    <ChartContainer config={chartConfig}>
      <AreaChart accessibilityLayer data={data}>
        <ChartTooltip
          cursor={false}
          content={<ChartTooltipContent indicator="line" nameKey="visitors" hideLabel />}
        />
        <ReferenceLine y={acceptanceThreshold} strokeDasharray="3 3" strokeWidth={2}>
          <Label
            position="insideTopLeft"
            value={acceptanceThreshold}
            fill="red"
            offset={10}
            startOffset={100}
          />
        </ReferenceLine>
        <CartesianGrid strokeDasharray="3 3" />
        <XAxis dataKey="label" />
        <YAxis tickFormatter={normaliseNumber} />

        <Area
          dataKey="existingBase"
          type="natural"
          strokeWidth={2}
          activeDot={{
            r: 6,
          }}
        >
        </Area>
        <Area
          dataKey="existingThreshold"
          type="natural"
          strokeWidth={2}
          activeDot={{
            r: 6,
          }}
        >
        </Area>
        <Area
          dataKey="inputBase"
          type="natural"
          strokeWidth={2}
          activeDot={{
            r: 6,
          }}
        >
        </Area>
        <Area
          dataKey="inputThreshold"
          type="natural"
          strokeWidth={2}
          activeDot={{
            r: 6,
          }}
        >
        </Area>
      </AreaChart>
    </ChartContainer>
  )
}
