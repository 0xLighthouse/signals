import { Abi, erc20Abi } from 'viem'

const EDGE_CITY_ENV = process.env.NEXT_PUBLIC_EDGE_CITY?.toLowerCase() === 'true'

const EDGE_CITY_TOKEN_ADDRESS = process.env.NEXT_PUBLIC_EDGE_CITY_TOKEN_ADDRESS

const EDGE_CITY_CUSTOM_ABI: Abi = [
  ...erc20Abi,
  {
    name: 'claim',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'to', type: 'address', internalType: 'address' },
      { name: 'participantId', type: 'uint256', internalType: 'uint256' },
      { name: 'amount', type: 'uint256', internalType: 'uint256' },
      { name: 'deadline', type: 'uint256', internalType: 'uint256' },
      { name: 'signature', type: 'bytes', internalType: 'bytes' },
    ],
    outputs: [],
  },
]

export const edgeCityConfig = {
  enabled: EDGE_CITY_ENV,
  token: EDGE_CITY_TOKEN_ADDRESS as `0x${string}` | undefined,
  claimFunction: 'claim' as const,
  minCities: 1,
  maxCities: 3,
  abi: EDGE_CITY_CUSTOM_ABI,
} as const

export type EdgeCityProfile = {
  primary_email: string
  secondary_email: string | null
  email_validated: boolean
  first_name: string
  last_name: string
  x_user: string | null
  telegram: string | null
  gender: string | null
  role: string | null
  organization: string | null
  picture_url: string | null
  created_at: string
  updated_at: string
  id: number
  popups: Array<{
    id: number
    popup_name: string
    start_date: string
    end_date: string
    total_days: number
    location: string | null
    image_url: string | null
    application: {
      id: number
      residence: string | null
      personal_goals: string | null
    } | null
  }>
  total_days: number
  referral_count: number
}

export type EdgeCityLoginResponse = {
  access_token: string
  token_type: string
}

export type EdgeCityAllowance = {
  participantId: number
  to: `0x${string}`
  amount: string
  deadline: number
  signature: `0x${string}`
}
