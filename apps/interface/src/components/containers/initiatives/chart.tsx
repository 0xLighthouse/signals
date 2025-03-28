'use client'

import { CartesianGrid, Label, AreaChart, ReferenceLine, XAxis, YAxis, Area } from 'recharts'

import {
  ChartConfig,
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
} from '@/components/ui/chart'
import { InitiativeDetails } from '@/lib/curves'
import { ChartTick, generateTicks, ChartOptions } from '@/lib/chart'
import { DateTime } from 'luxon'
import { useEffect, useState } from 'react'
import { normaliseNumber } from '@/lib/utils'
import { Lock } from '@/indexers/api/types'

export const description = 'A line chart with a custom label'

const chartConfig = {
  existingBase: {
    label: 'Current Weight',
    color: 'hsl(var(--chart-1))',
  },
  inputBase: {
    label: 'New Weight',
    color: 'hsl(var(--chart-3))',
  },
} satisfies ChartConfig

interface Props {
  initiative?: InitiativeDetails
  existingLocks: Lock[]
  acceptanceThreshold?: number | null
  amountInput?: number | null
  durationInput?: number
}

export const Chart: React.FC<Props> = ({
  initiative,
  existingLocks,
  acceptanceThreshold,
  amountInput,
  durationInput,
}) => {
  const [data, setData] = useState<ChartTick[]>([])
  const [chartZoom, setChartZoom] = useState<[number, number]>([0, 1])

  useEffect(() => {
    if (!initiative || !acceptanceThreshold) return

    const options: ChartOptions = {
      initiative,
      acceptanceThreshold,
      chartInterval: initiative.lockInterval || 60 * 60,
      maxTimeWindow: 60 * 60 * 24 * 60,
      minTimeWindow: 60 * 60 * 24 * 7,
    }

    const _locks = existingLocks.map((lock) => ({
      tokenAmount: Number(lock.metadata.nominalValue),
      lockDuration: Number(lock.duration),
      createdAt: lock.blockTimestamp,
      isWithdrawn: false,
    }))

    // console.log('options', options)
    // console.log('locks', _locks)
    // console.log('newLock', {
    //   amountInput,
    //   durationInput,
    // })

    // Update chart if input data is provided
    const chartData =
      amountInput && durationInput
        ? generateTicks(_locks, options, [
            {
              tokenAmount: amountInput,
              lockDuration: durationInput,
              createdAt: DateTime.now().toUnixInteger(),
              isWithdrawn: false,
            },
          ])
        : generateTicks(_locks, options)
    setData(chartData)
  }, [initiative, existingLocks, amountInput, durationInput, acceptanceThreshold])

  return (
    <ChartContainer config={chartConfig}>
      <AreaChart accessibilityLayer data={data}>
        <ChartTooltip
          cursor={false}
          content={<ChartTooltipContent indicator="line" nameKey="label" hideLabel />}
        />
        <ReferenceLine
          y={acceptanceThreshold || 0}
          strokeWidth={2}
          strokeDasharray="3 3"
          stroke="green"
        >
          <Label position={'left'} value={normaliseNumber(acceptanceThreshold || 0)} fill="green" />
        </ReferenceLine>
        <CartesianGrid strokeDasharray="3 3" />
        <XAxis dataKey="label" />
        <YAxis
          tickFormatter={normaliseNumber}
          domain={acceptanceThreshold ? [0, acceptanceThreshold * 1.2] : [0, 1_000_000]}
        />
        <Area
          dataKey="existingBase"
          name="Current Weight"
          type="monotone"
          stackId="1"
          fill="#7d9aad"
          strokeWidth={2}
          activeDot={{
            r: 3,
          }}
        />
        <Area
          dataKey="inputBase"
          name="New Weight"
          type="monotone"
          stackId="1"
          strokeWidth={2}
          activeDot={{
            r: 3,
          }}
        />
      </AreaChart>
    </ChartContainer>
  )
}
