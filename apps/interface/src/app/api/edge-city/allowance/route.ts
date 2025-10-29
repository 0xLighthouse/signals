import { NextResponse } from 'next/server'
import { isAddress } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'

import { edgeCityConfig, EdgeCityProfile } from '@/config/edge-city'
import { readClient } from '@/config/web3'
import { EdgeOSClient } from '@/lib/server/edgeos-client'

const DEFAULT_TTL_SECONDS = 60 * 60 * 24 // 24h

const CLAIM_TYPES = {
  Claim: [
    { name: 'to', type: 'address' },
    { name: 'participantId', type: 'uint256' },
    { name: 'amount', type: 'uint256' },
    { name: 'deadline', type: 'uint256' },
  ],
} as const

type AllowanceRequest = {
  address?: string
}

type AllowanceResponse = {
  participantId: number
  to: `0x${string}`
  amount: string
  deadline: number
  signature: `0x${string}`
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
    const recipient = body.address?.toLowerCase()

    if (!recipient || !isAddress(recipient)) {
      return NextResponse.json({ error: 'Valid wallet address is required' }, { status: 400 })
    }

    const signerKey = process.env.EDGE_CITY_SIGNER_PRIVATE_KEY
    if (!signerKey) {
      throw new Error('EDGE_CITY_SIGNER_PRIVATE_KEY is not configured')
    }

    const defaultAmountEnv = process.env.EDGE_CITY_DEFAULT_CLAIM_AMOUNT_WEI
    if (!defaultAmountEnv) {
      throw new Error('EDGE_CITY_DEFAULT_CLAIM_AMOUNT_WEI is not configured')
    }

    const perDayAmountEnv = process.env.EDGE_CITY_AMOUNT_PER_DAY_WEI
    const ttlSeconds = Number.parseInt(process.env.EDGE_CITY_ALLOWANCE_TTL_SECONDS ?? '', 10)
    const allowanceTtl = Number.isFinite(ttlSeconds) && ttlSeconds > 0 ? ttlSeconds : DEFAULT_TTL_SECONDS

    const client = new EdgeOSClient()
    const profile = (await client.getProfile(token)) as EdgeCityProfile

    if (!profile.email_validated) {
      return NextResponse.json({ error: 'Primary email is not validated' }, { status: 403 })
    }

    if (edgeCityConfig.requiredPopups.length > 0) {
      const hasEligiblePopup = profile.popups?.some((popup) =>
        edgeCityConfig.requiredPopups.includes(String(popup.id)),
      )
      if (!hasEligiblePopup) {
        return NextResponse.json({ error: 'No eligible Edge City residency found' }, { status: 403 })
      }
    } else if (!profile.total_days || profile.total_days <= 0) {
      return NextResponse.json({ error: 'Residency requires at least one completed day' }, { status: 403 })
    }

    let amountWei = BigInt(defaultAmountEnv)
    if (perDayAmountEnv) {
      const perDay = BigInt(perDayAmountEnv)
      const totalDays = BigInt(profile.total_days ?? 0)
      const calculated = perDay * totalDays
      if (calculated > 0) {
        amountWei = calculated
      }
    }

    const deadline = Math.floor(Date.now() / 1000) + allowanceTtl

    const account = privateKeyToAccount(signerKey as `0x${string}`)
    const signature = await account.signTypedData({
      domain: {
        name: 'ExperimentToken',
        version: '1',
        chainId: readClient.chain.id,
        verifyingContract: edgeCityConfig.token,
      },
      types: CLAIM_TYPES,
      primaryType: 'Claim',
      message: {
        to: recipient as `0x${string}`,
        participantId: BigInt(profile.id),
        amount: amountWei,
        deadline: BigInt(deadline),
      },
    })

    const payload: AllowanceResponse = {
      participantId: profile.id,
      to: recipient as `0x${string}`,
      amount: amountWei.toString(),
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
