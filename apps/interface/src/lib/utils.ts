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
 * Left for legacy support, but we should updated to use normaliseBigNumber
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

export const normaliseBigNumber = (value: number, decimals?: number) => {
  const suffixes = ['', 'k', 'M', 'B', 'T']
  let suffixIndex = Math.floor(Math.log10(value) / 3)
  if (suffixIndex > 4) {
    suffixIndex = 4
  }
  const suffix = suffixes[suffixIndex]
  // biome-ignore lint/style/useExponentiationOperator: <explanation>
  const normalisedValue = value / Math.pow(10, suffixIndex * 3)
  if (!normalisedValue) return ''
  return decimals ? `${normalisedValue.toFixed(decimals)}${suffix}` : `${normalisedValue}${suffix}`
}

type FormatNumberOptions = {
  decimals?: number
  currency?: boolean
  abbreviate?: boolean
  symbol?: string
  wad?: number
}

export const formatNumber = (
  value: number, 
  options: FormatNumberOptions = {}
): string => {
  const { 
    decimals, 
    currency = false, 
    abbreviate = false,
    symbol = 'USDC',
    wad = 1 // Wei Adjusted Decimal => divide by 1e18, etc
  } = options

  if (value === 0 || !value) {
    return currency ? `0 ${symbol}` : '0'
  }

  const adjustedValue = value / 10 ** wad

  if (abbreviate && adjustedValue >= 1000) {
    // Here for legacy support, but we should updated to use normaliseBigNumber
    const formatted = decimals ? normaliseBigNumber(adjustedValue, decimals) : normaliseNumber(adjustedValue)
    return currency ? `${formatted} ${symbol}` : formatted
  }

  const formatter = new Intl.NumberFormat('en-US', {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals
  })

  const formatted = formatter.format(adjustedValue)
  return currency ? `${formatted} ${symbol}` : formatted
}
