import { clsx, type ClassValue } from 'clsx'
import { DateTime } from 'luxon'
import { twMerge } from 'tailwind-merge'

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export function timeAgoWords(timestamp: number | string) {
  return DateTime.fromSeconds(Number(timestamp)).toRelative()
}

export function flatten<T>(arr: T[][]): T[] {
  return arr.flat()
}

export const shortAddress = (address?: string): string => {
  if (!address) return ''
  return `${address?.slice(0, 5)}...${address?.slice(37)}`
}

export const resolveAvatar = (address?: string, size?: string | number) => {
  if (!address) return
  return `https://cdn.stamp.fyi/avatar/${address}${size ? `?s=${size}` : ''}`
}

/**
 * Given a round number  eg. 1000000, 500000, 20000
 * Normalise to 1M, 500k, 20k, etc
 */
export const normaliseNumber = (value: number) => {
  const suffixes = ['', 'k', 'M', 'B', 'T']
  const suffixIndex = Math.floor(Math.log10(value) / 3)
  const suffix = suffixes[suffixIndex]
  // biome-ignore lint/style/useExponentiationOperator: <explanation>
  const normalisedValue = value / Math.pow(10, suffixIndex * 3)
  if (!normalisedValue) return ''
  return `${normalisedValue}${suffix}`
}

type FormatNumberOptions = {
  decimals?: number
  currency?: boolean
  abbreviate?: boolean
  symbol?: string
}

export const formatNumber = (
  value: number, 
  options: FormatNumberOptions = {}
): string => {
  const { 
    decimals = 2, 
    currency = false, 
    abbreviate = false,
    symbol = 'USDC'
  } = options

  if (value === 0 || !value) {
    return currency ? `0 ${symbol}` : '0'
  }

  if (abbreviate && value >= 1000) {
    const formatted = normaliseNumber(value)
    return currency ? `${formatted} ${symbol}` : formatted
  }

  const formatter = new Intl.NumberFormat('en-US', {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals
  })

  const formatted = formatter.format(value)
  return currency ? `${formatted} ${symbol}` : formatted
}
