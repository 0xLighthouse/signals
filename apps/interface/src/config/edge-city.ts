import { Abi, erc20Abi } from 'viem'
import { ERC20WithFaucetABI } from './web3'

const EDGE_CITY_ENV = process.env.NEXT_PUBLIC_EDGE_CITY?.toLowerCase() === 'true'

const EDGE_CITY_TOKEN_ADDRESS = process.env.NEXT_PUBLIC_EDGE_CITY_TOKEN_ADDRESS
const EDGE_CITY_CLAIM_FUNCTION = process.env.NEXT_PUBLIC_EDGE_CITY_CLAIM_FUNCTION ?? 'faucet'
const EDGE_CITY_CLAIM_AMOUNT = process.env.NEXT_PUBLIC_EDGE_CITY_CLAIM_AMOUNT
const EDGE_CITY_REQUIRED_POPUPS =
  process.env.NEXT_PUBLIC_EDGE_CITY_REQUIRED_POPUPS?.split(',').map((id) => id.trim()).filter(Boolean) ?? []

const EDGE_CITY_CUSTOM_ABI =
  EDGE_CITY_CLAIM_FUNCTION === 'claim'
    ? ([
        ...erc20Abi,
        {
          inputs: [
            { internalType: 'address', name: 'to', type: 'address' },
            { internalType: 'uint256', name: 'amount', type: 'uint256' },
          ],
          name: 'claim',
          outputs: [],
          stateMutability: 'nonpayable',
          type: 'function',
        },
      ] satisfies Abi)
    : (ERC20WithFaucetABI as Abi)

export const edgeCityConfig = {
  enabled: EDGE_CITY_ENV,
  token: EDGE_CITY_TOKEN_ADDRESS as `0x${string}` | undefined,
  claimFunction: EDGE_CITY_CLAIM_FUNCTION,
  claimAmount: EDGE_CITY_CLAIM_AMOUNT ? BigInt(EDGE_CITY_CLAIM_AMOUNT) : undefined,
  requiredPopups: EDGE_CITY_REQUIRED_POPUPS,
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
