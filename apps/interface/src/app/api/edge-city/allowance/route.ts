import { NextResponse } from 'next/server'
import { isAddress } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'

import { edgeCityConfig, EdgeCityProfile } from '@/config/edge-city'
import { readClient } from '@/config/web3'
import { EdgeOSClient } from '@/lib/server/edgeos-client'

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
  address?: string
}

type AllowanceResponse = {
  to: `0x${string}`
  participantId: number
  amount: string
  deadline: number
  signature: `0x${string}`
}

export async function POST(request: Request) {
  try {
    // This endpoint only supports the signed EIP-712 allowance flow.
    if (edgeCityConfig.claimFunction !== 'claim') {
      return NextResponse.json({ error: 'Signed allowance is not enabled for this environment' }, { status: 400 })
    }

    const authorization = request.headers.get('authorization')
    const token = authorization?.startsWith('Bearer ') ? authorization.slice(7) : null

    if (!token) {
      return NextResponse.json({ error: 'Missing authorization token' }, { status: 401 })
    }

    if (!edgeCityConfig.token) {
      return NextResponse.json({ error: 'Edge City token configuration missing' }, { status: 500 })
    }

    const body = (await request.json()) as AllowanceRequest
    const recipientRaw = body.address?.toLowerCase()
    if (!recipientRaw || !isAddress(recipientRaw)) {
      return NextResponse.json({ error: 'Valid wallet address is required' }, { status: 400 })
    }
    const recipient = recipientRaw as `0x${string}`

    const signerKey = process.env.EDGE_CITY_SIGNER_PRIVATE_KEY
    if (!signerKey) {
      throw new Error('EDGE_CITY_SIGNER_PRIVATE_KEY is not configured')
    }

    const defaultAmountEnv = process.env.EDGE_CITY_DEFAULT_CLAIM_AMOUNT_WEI
    if (!defaultAmountEnv) {
      throw new Error('EDGE_CITY_DEFAULT_CLAIM_AMOUNT_WEI is not configured')
    }

    // Parse TTL safely and fallback to default if invalid or missing
    const ttlSecondsStr = process.env.EDGE_CITY_ALLOWANCE_TTL_SECONDS
    const ttlSeconds = ttlSecondsStr ? Number.parseInt(ttlSecondsStr, 10) : NaN
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

    // Determine amount: default base + optional per-day increment
    let amountWei = BigInt(defaultAmountEnv)
    const perDayAmountEnv = process.env.EDGE_CITY_AMOUNT_PER_DAY_WEI
    if (perDayAmountEnv) {
      const perDay = BigInt(perDayAmountEnv)
      const totalDays = BigInt(profile.total_days ?? 0)
      amountWei += perDay * totalDays
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
        to: recipient,
        participantId: BigInt(profile.id),
        amount: amountWei,
        deadline: BigInt(deadline),
      },
    })

    const payload: AllowanceResponse = {
      participantId: profile.id,
      to: recipient,
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
