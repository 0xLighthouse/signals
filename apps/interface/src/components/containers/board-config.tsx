'use client'

import React from 'react'

import { useSignals } from '@/hooks/use-signals'
import { normaliseNumber, shortAddress } from '@/lib/utils'
import { NETWORKS } from '@/config/networks'

const DECAY_CURVE_LABELS: Record<number, string> = {
  0: 'Linear decay',
  1: 'Exponential decay',
}

const STUB_LOCK_INTERVAL_SECONDS = 7 * 24 * 60 * 60 // 7 days
const STUB_TOKEN_NAME = 'Signals Token'
const STUB_TOKEN_SYMBOL = 'SIG'
const STUB_DECAY_LABEL = `${DECAY_CURVE_LABELS[0]} (stub)`

const formatLockInterval = (seconds?: number | null) => {
  const value = seconds ?? STUB_LOCK_INTERVAL_SECONDS
  if (!value) return '—'

  const days = Math.round(value / 86400)
  if (seconds == null) {
    return `${days} ${days === 1 ? 'day' : 'days'} (stub)`
  }

  if (days >= 1) {
    return `${days} ${days === 1 ? 'day' : 'days'}`
  }

  const hours = Math.round(value / 3600)
  return `${hours} ${hours === 1 ? 'hour' : 'hours'}`
}

export const BoardConfig = () => {
  const {
    board,
    boardAddress,
    network,
    underlyingName,
    underlyingSymbol,
    underlyingDecimals,
    underlyingTotalSupply,
    formatter,
  } = useSignals()

  const canFormatTokenValues = underlyingDecimals != null

  const formatTokenAmount = (value?: number | null) => {
    if (value == null || !canFormatTokenValues) {
      return '—'
    }

    const adjusted = formatter(value)
    if (!Number.isFinite(adjusted)) {
      return '—'
    }

    if (adjusted === 0) {
      return '0'
    }

    if (adjusted >= 1000) {
      return normaliseNumber(adjusted)
    }

    return adjusted.toLocaleString('en-US')
  }

  const withSymbol = (value: string) => {
    if (value === '—' || !underlyingSymbol) return value
    return `${value} ${underlyingSymbol}`
  }

  const boardTitle = board.name ?? 'Untitled board'
  const addressLabel = boardAddress ? shortAddress(boardAddress) : 'Deploying soon (stub)'
  const networkLabel = network ? (NETWORKS[network]?.chain.name ?? network) : 'Unknown network'
  const proposalThreshold = withSymbol(formatTokenAmount(board.proposalThreshold))
  const acceptanceThreshold = withSymbol(formatTokenAmount(board.acceptanceThreshold))
  const lockInterval = formatLockInterval(board.lockInterval)
  const decayCurve =
    board.decayCurveType != null
      ? (DECAY_CURVE_LABELS[board.decayCurveType] ?? 'Custom curve')
      : STUB_DECAY_LABEL

  const totalSupply = withSymbol(formatTokenAmount(underlyingTotalSupply))
  const tokenName =
    underlyingName ??
    (underlyingSymbol ? `${underlyingSymbol} Token (stub)` : `${STUB_TOKEN_NAME} (stub)`)
  const tokenSymbol = underlyingSymbol ?? `${STUB_TOKEN_SYMBOL} (stub)`
  const tokenDecimals = underlyingDecimals?.toString() ?? '18 (stub)'

  const statusLabel = board.meetsThreshold ? 'Ready to propose' : 'Needs more tokens'
  const statusStyles = board.meetsThreshold
    ? 'bg-emerald-100 text-emerald-700 dark:bg-emerald-500/10 dark:text-emerald-300'
    : 'bg-amber-100 text-amber-700 dark:bg-amber-500/10 dark:text-amber-300'

  const governanceConfig = [
    { label: 'Proposal threshold', value: proposalThreshold },
    { label: 'Acceptance threshold', value: acceptanceThreshold },
    { label: 'Lock interval', value: lockInterval },
    { label: 'Decay curve', value: decayCurve },
  ]

  const tokenConfig = [
    { label: 'Underlying token', value: tokenName },
    { label: 'Symbol', value: tokenSymbol },
    { label: 'Total supply', value: totalSupply },
    { label: 'Decimals', value: tokenDecimals },
  ]

  return (
    <section className="rounded-2xl border border-neutral-200 bg-white p-6 text-neutral-900 shadow-sm dark:border-neutral-800 dark:bg-neutral-950 dark:text-white">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <p className="text-xs uppercase tracking-wide text-neutral-500 dark:text-neutral-400">
            Board overview
          </p>
          <h2 className="text-2xl font-semibold">{boardTitle}</h2>
          <p className="text-sm text-neutral-500 dark:text-neutral-400">
            {addressLabel} • {networkLabel}
          </p>
        </div>
        <span className={`w-fit rounded-full px-3 py-1 text-xs font-medium ${statusStyles}`}>
          {statusLabel}
        </span>
      </div>

      <div className="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-2">
        {governanceConfig.map(({ label, value }) => (
          <div
            key={label}
            className="rounded-xl border border-neutral-100 bg-neutral-50 p-4 dark:border-neutral-800 dark:bg-neutral-900"
          >
            <p className="text-xs uppercase tracking-wide text-neutral-500 dark:text-neutral-400">
              {label}
            </p>
            <p className="text-lg font-semibold text-neutral-900 dark:text-white">{value}</p>
          </div>
        ))}
      </div>

      {/* <div className="mt-6 rounded-2xl border border-neutral-100 bg-neutral-50 p-4 dark:border-neutral-800 dark:bg-neutral-900">
        <p className="text-xs uppercase tracking-wide text-neutral-500 dark:text-neutral-400">
          Token configuration
        </p>
        <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2">
          {tokenConfig.map(({ label, value }) => (
            <div key={label}>
              <p className="text-xs uppercase tracking-wide text-neutral-500 dark:text-neutral-400">
                {label}
              </p>
              <p className="text-base font-semibold text-neutral-900 dark:text-white">{value}</p>
            </div>
          ))}
        </div>
      </div> */}
    </section>
  )
}
