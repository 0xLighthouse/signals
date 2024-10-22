import { clsx, type ClassValue } from 'clsx'
import { DateTime } from 'luxon'
import { twMerge } from 'tailwind-merge'

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export function timeAgoWords(timestamp: number) {
  return DateTime.fromSeconds(timestamp).toRelative()
}

export function flatten<T>(arr: T[][]): T[] {
  return arr.flat()
}

export const shortAddress = (address?: string): string => {
  if (!address) return ''
  return `${address?.slice(0, 5)}...${address?.slice(37)}`
}
