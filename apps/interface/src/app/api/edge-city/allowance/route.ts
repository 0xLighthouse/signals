import { NextResponse } from 'next/server'
import { formatUnits, isAddress, parseEther } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'

import { edgeCityConfig, EdgeCityProfile } from '@/config/edge-city'
import { getNetworkConfig } from '@/config/web3'
import { EdgeOSClient } from '@/lib/server/edgeos-client'
import { EDGE_CITY_SIGNER_PRIVATE_KEY } from '../../secrets'
import { MAX_ADDITIONAL_CITIES, DEFAULT_ALLOCATION_AMOUNT_INT } from '../constants'

const DEFAULT_TTL_SECONDS = 60 * 60 // 1h

const CLAIM_TYPES = {
  Claim: [
    { name: 'to', type: 'address' },
    { name: 'participantId', type: 'uint256' },
    { name: 'amount', type: 'uint256' },
    { name: 'deadline', type: 'uint256' },
  ],
} as const

type AllowanceRequest = {
  chainId: number
  recipient: `0x${string}`
}

type AllowanceResponse = {
  to: `0x${string}`
  participantId: number
  amount: string
  deadline: number
  signature: `0x${string}`
}


const calculateAllowance = async (defaultAlloc: number, additionalCitiesAttended: number) => {
  const maxAdditionalCities = additionalCitiesAttended >= MAX_ADDITIONAL_CITIES ? MAX_ADDITIONAL_CITIES : additionalCitiesAttended
  return defaultAlloc + (maxAdditionalCities * defaultAlloc)
}

export async function POST(request: Request) {
  try {
    const authorization = request.headers.get('authorization')
    const token = authorization?.startsWith('Bearer ') ? authorization.slice(7) : null

    if (!token) {
      return NextResponse.json({ error: 'Missing authorization token' }, { status: 401 })
    }

    if (!edgeCityConfig.token) {
      return NextResponse.json({ error: 'Edge City token configuration missing' }, { status: 500 })
    }

    const body = (await request.json()) as AllowanceRequest
    const recipientRaw = body.recipient?.toLowerCase()
    if (!recipientRaw || !isAddress(recipientRaw)) {
      return NextResponse.json({ error: 'Valid wallet address is required' }, { status: 400 })
    }
    const recipient = recipientRaw as `0x${string}`

    // Load our private signer
    const client = new EdgeOSClient()
    const profile = (await client.getProfile(token)) as EdgeCityProfile

    console.log('profile', JSON.stringify(profile, null, 2))

    if (profile.popups?.length === 0) {
      return NextResponse.json({ error: 'No eligible Edge City residency found' }, { status: 403 })
    }

    const totalCities = profile.popups?.length
    const additionalCitiesAttended = totalCities - 1
    const allowanceAmount = calculateAllowance(DEFAULT_ALLOCATION_AMOUNT_INT, additionalCitiesAttended)
    const allowanceAmountWei = parseEther(allowanceAmount.toString())
    const deadline = Math.floor(Date.now() / 1000) + DEFAULT_TTL_SECONDS


    const account = privateKeyToAccount(EDGE_CITY_SIGNER_PRIVATE_KEY)
    const signature = await account.signTypedData({
      domain: {
        name: 'ExperimentToken',
        version: '1',
        chainId: getNetworkConfig().chain.id,
        verifyingContract: edgeCityConfig.token,
      },
      types: CLAIM_TYPES,
      primaryType: 'Claim',
      message: {
        to: recipient,
        participantId: BigInt(profile.id),
        amount: allowanceAmountWei,
        deadline: BigInt(deadline),
      },
    })

    const payload: AllowanceResponse = {
      participantId: profile.id,
      to: recipient,
      amount: formatUnits(allowanceAmountWei, 18), //
      deadline,
      signature,
    }

    return NextResponse.json(payload)
  } catch (error) {
    console.error(error)
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'Unknown error issuing allowance' },
      { status: 500 },
    )
  }
}
