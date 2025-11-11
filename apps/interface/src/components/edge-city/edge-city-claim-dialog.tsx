'use client'

import { useCallback, useEffect, useMemo, useState } from 'react'
import { usePrivy } from '@privy-io/react-auth'
import { toast } from 'sonner'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog'
import { Label } from '@/components/ui/label'
import { Badge } from '@/components/ui/badge'
import { Avatar, AvatarFallback } from '@/components/ui/avatar'
import { edgeCityConfig, EdgeCityProfile, EdgeCityAllowance } from '@/config/edge-city'
import { formatUnits } from 'viem'
import { useAccount } from '@/hooks/useAccount'
import { useWeb3 } from '@/contexts/Web3Provider'
import { useNetwork } from '@/hooks/useNetwork'
import { ensureWalletNetwork } from '@/lib/wallet-network'
import { CheckCircle2, Clock3, Sparkles, Wallet2 } from 'lucide-react'

type ClaimStep = 'email' | 'code' | 'review' | 'completed'

type ClaimState = {
  email: string
  code: string
  profile: EdgeCityProfile | null
  accessToken: string | null
  allowance: EdgeCityAllowance | null
  step: ClaimStep
  isRequestingCode: boolean
  isVerifyingCode: boolean
  isClaiming: boolean
  isLoadingAllowance: boolean
}

const initialState: ClaimState = {
  email: '',
  code: '',
  profile: null,
  accessToken: null,
  allowance: null,
  step: 'email',
  isRequestingCode: false,
  isVerifyingCode: false,
  isClaiming: false,
  isLoadingAllowance: false,
}

const EDGE_CITY_TOKEN_STORAGE_KEY = 'edgeCityAccessToken'
const EDGE_CITY_PROFILE_STORAGE_KEY = 'edgeCityProfile'

const createInitialClaimState = (): ClaimState => ({
  ...initialState,
})

const evaluateEligibility = (profile: EdgeCityProfile) => {
  if (!profile.email_validated) {
    return { eligible: false, reason: 'Primary email is not validated' }
  }

  if (Array.isArray(edgeCityConfig.minCities) && edgeCityConfig.minCities.length > 0) {
    const minCitiesArray = edgeCityConfig.minCities as unknown as readonly unknown[]
    const hasMatch = profile.popups?.some((popup) => minCitiesArray.includes(String(popup.id)))
    if (!hasMatch) {
      return {
        eligible: false,
        reason: 'No eligible Edge City residency found for this account',
      }
    }
  } else if (!profile.total_days || profile.total_days <= 0) {
    return { eligible: false, reason: 'Residency must include at least one completed day' }
  }

  return { eligible: true, reason: '' }
}

const buildClaimArgs = (
  address: `0x${string}`,
  participantId: bigint,
  allowance?: EdgeCityAllowance,
) => {
  if (!allowance) {
    throw new Error('Claim allowance missing')
  }
  return [
    address,
    participantId,
    BigInt(allowance.amount),
    BigInt(allowance.deadline),
    allowance.signature,
  ] as const
}

export const EdgeCityClaimDialog = () => {
  const { authenticated, login, ready } = usePrivy()
  const { address } = useAccount()
  const { walletClient } = useWeb3()
  const { config } = useNetwork()

  const [open, setOpen] = useState(false)
  const [state, setState] = useState<ClaimState>(initialState)

  const {
    email,
    code,
    profile,
    accessToken,
    allowance,
    step,
    isRequestingCode,
    isVerifyingCode,
    isClaiming,
    isLoadingAllowance,
  } = state

  const persistEdgeCitySession = useCallback((token: string, profile: EdgeCityProfile) => {
    if (typeof window === 'undefined') {
      return
    }
    try {
      window.localStorage.setItem(EDGE_CITY_TOKEN_STORAGE_KEY, token)
      window.localStorage.setItem(EDGE_CITY_PROFILE_STORAGE_KEY, JSON.stringify(profile))
    } catch (error) {
      console.error('Failed to persist Edge City session', error)
    }
  }, [])

  const clearEdgeCitySession = useCallback((message?: string) => {
    if (typeof window !== 'undefined') {
      try {
        window.localStorage.removeItem(EDGE_CITY_TOKEN_STORAGE_KEY)
        window.localStorage.removeItem(EDGE_CITY_PROFILE_STORAGE_KEY)
      } catch (error) {
        console.error('Failed to clear Edge City session', error)
      }
    }
    setState(createInitialClaimState())
    if (message) {
      toast(message)
    }
  }, [])

  const eligibility = useMemo(() => {
    if (!profile) return { eligible: false, reason: '' }
    return evaluateEligibility(profile)
  }, [profile])

  const profileInitials = useMemo(() => {
    if (!profile) return 'EC'
    const first = profile.first_name?.[0] ?? ''
    const last = profile.last_name?.[0] ?? profile.primary_email?.[0] ?? ''
    const initials = `${first}${last}`.trim()
    return initials ? initials.toUpperCase() : 'EC'
  }, [profile])

  const truncatedAddress = useMemo(() => {
    if (!address) return ''
    return `${address.slice(0, 6)}…${address.slice(-4)}`
  }, [address])

  const allowanceDeadlineLabel = useMemo(() => {
    if (!allowance) return ''
    return new Date(allowance.deadline * 1000).toLocaleString()
  }, [allowance])

  const allowanceAmountLabel = useMemo(() => {
    if (!allowance) return ''
    return formatUnits(BigInt(allowance.amount), 18)
  }, [allowance])

  const restoreEdgeCitySession = useCallback(() => {
    if (typeof window === 'undefined') {
      return
    }
    const storedToken = window.localStorage.getItem(EDGE_CITY_TOKEN_STORAGE_KEY)
    const storedProfileRaw = window.localStorage.getItem(EDGE_CITY_PROFILE_STORAGE_KEY)

    if (!storedToken || !storedProfileRaw) {
      return
    }

    try {
      const storedProfile = JSON.parse(storedProfileRaw) as EdgeCityProfile
      setState((prev) => ({
        ...prev,
        accessToken: storedToken,
        profile: storedProfile,
        allowance: null,
        step: 'review',
      }))
    } catch (error) {
      console.error('Failed to parse stored Edge City profile', error)
      window.localStorage.removeItem(EDGE_CITY_PROFILE_STORAGE_KEY)
    }
  }, [])

  useEffect(() => {
    if (!open) {
      setState(createInitialClaimState())
      return
    }
    restoreEdgeCitySession()
  }, [open, restoreEdgeCitySession])
  // Get the Edge Experiment token address from the active network configuration
  const edgeExperimentTokenAddress = config.contracts.EdgeExperimentToken?.address

  if (!edgeCityConfig.enabled || !edgeExperimentTokenAddress) {
    return null
  }

  const fetchAllowance = useCallback(
    async (token: string, wallet: `0x${string}`) => {
      setState((prev) => ({ ...prev, isLoadingAllowance: true }))
      try {
        const response = await fetch('/api/edge-city/allowance', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${token}`,
          },
          body: JSON.stringify({ address: wallet, tokenAddress: edgeExperimentTokenAddress }),
        })

        if (!response.ok) {
          if (response.status === 401 || response.status === 403) {
            clearEdgeCitySession('Edge City session expired. Please log in again.')
            return
          }
          let errorMessage = 'Unexpected response fetching allowance'
          try {
            const { error } = (await response.json()) as { error?: string }
            errorMessage = error ?? errorMessage
          } catch (parseError) {
            console.error('Failed to parse allowance error response', parseError)
          }
          throw new Error(errorMessage)
        }

        const payload = (await response.json()) as EdgeCityAllowance
        setState((prev) => ({ ...prev, allowance: payload }))
      } catch (error) {
        console.error(error)
        toast(error instanceof Error ? error.message : 'Failed to load claim allowance')
        setState((prev) => ({ ...prev, allowance: null }))
      } finally {
        setState((prev) => ({ ...prev, isLoadingAllowance: false }))
      }
    },
    [clearEdgeCitySession, edgeExperimentTokenAddress],
  )

  const handleRequestCode = async () => {
    if (!email) {
      toast('Enter an email to continue')
      return
    }

    setState((prev) => ({ ...prev, isRequestingCode: true }))
    try {
      const response = await fetch('/api/edge-city/request-code', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ email }),
      })

      if (!response.ok) {
        const { error } = await response.json()
        throw new Error(error ?? 'Unexpected response requesting code')
      }

      toast('Verification code sent to your email')
      setState((prev) => ({ ...prev, step: 'code' }))
    } catch (error) {
      console.error(error)
      toast(error instanceof Error ? error.message : 'Failed to request verification code')
    } finally {
      setState((prev) => ({ ...prev, isRequestingCode: false }))
    }
  }

  const handleVerifyCode = async () => {
    if (!email || !code) {
      toast('Enter your email and verification code')
      return
    }

    setState((prev) => ({ ...prev, isVerifyingCode: true }))
    try {
      const response = await fetch('/api/edge-city/login', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ email, code }),
      })

      if (!response.ok) {
        const { error } = await response.json()
        throw new Error(error ?? 'Unexpected response during verification')
      }

      const payload = (await response.json()) as { accessToken: string; profile: EdgeCityProfile }

      setState((prev) => ({
        ...prev,
        accessToken: payload.accessToken,
        profile: payload.profile,
        allowance: null,
        step: 'review',
      }))
      persistEdgeCitySession(payload.accessToken, payload.profile)

      // If a wallet is connected, trigger allowance fetch immediately
      if (address) {
        void fetchAllowance(payload.accessToken, address as `0x${string}`)
      }
    } catch (error) {
      console.error(error)
      toast(error instanceof Error ? error.message : 'Failed to verify your code')
    } finally {
      setState((prev) => ({ ...prev, isVerifyingCode: false }))
    }
  }

  const handleClaim = async () => {
    if (!profile) {
      toast('Authenticate before claiming tokens')
      return
    }

    if (!address) {
      toast('Connect a wallet to claim tokens')
      return
    }

    if (!walletClient) {
      toast('Wallet client is not available yet')
      return
    }

    if (!eligibility.eligible) {
      toast(eligibility.reason || 'Profile is not eligible')
      return
    }

    if (!allowance) {
      toast('No claim allowance available for this participant')
      return
    }

    setState((prev) => ({ ...prev, isClaiming: true }))
    try {
      const ensureResult = await ensureWalletNetwork({
        walletClient,
        network: config,
      })
      if (!ensureResult.success) {
        throw new Error(
          ensureResult.error?.message ??
            `Switch your wallet to ${config.chain.name} and try again.`,
        )
      }

      const participantId = BigInt(profile.id)
      const claimArgs = buildClaimArgs(address as `0x${string}`, participantId, allowance!)

      if (!edgeExperimentTokenAddress) {
        toast('Token address not available')
        setState((prev) => ({ ...prev, isClaiming: false }))
        return
      }

      const txHash = await walletClient.writeContract({
        chain: walletClient.chain,
        account: address,
        address: edgeExperimentTokenAddress as `0x${string}`,
        abi: edgeCityConfig.abi,
        functionName: edgeCityConfig.claimFunction,
        args: claimArgs as unknown as readonly unknown[],
      })

      toast(`Claim transaction submitted: ${txHash}`)
      setState((prev) => ({
        ...prev,
        step: 'completed',
      }))
    } catch (error) {
      console.error(error)
      if (error instanceof Error && error.message.includes('User rejected')) {
        toast('Transaction rejected')
      } else if (error instanceof Error && error.message.includes('ParticipantAlreadyClaimed')) {
        toast('Edge City participant has already claimed their allocation')
      } else if (error instanceof Error && error.message.includes('InvalidRecipient')) {
        toast('Recipient wallet is invalid')
      } else if (error instanceof Error && error.message.includes('SignatureExpired')) {
        toast('Allowance signature expired. Refresh and try again')
      } else if (error instanceof Error && error.message.includes('InvalidSignature')) {
        toast('Allowance signature invalid. Contact support if this persists')
      } else {
        toast(error instanceof Error ? error.message : 'Failed to submit claim')
      }
    } finally {
      setState((prev) => ({ ...prev, isClaiming: false }))
    }
  }

  useEffect(() => {
    if (step !== 'review') return
    if (!address || !accessToken) return
    if (allowance && allowance.to.toLowerCase() === address.toLowerCase()) return
    if (isLoadingAllowance) return

    void fetchAllowance(accessToken, address as `0x${string}`)
  }, [accessToken, address, allowance, fetchAllowance, isLoadingAllowance, step])

  useEffect(() => {
    if (!address) {
      setState((prev) => ({ ...prev, allowance: null }))
    }
  }, [address])

  const renderContent = () => {
    if (!ready) {
      return <p className="text-sm text-muted-foreground">Initializing authentication...</p>
    }

    if (!authenticated) {
      return (
        <div className="space-y-4">
          <p className="text-sm text-muted-foreground">
            Connect your wallet to begin Edge City verification and claim.
          </p>
          <Button onClick={login}>Connect with Privy</Button>
        </div>
      )
    }

    switch (step) {
      case 'email':
        return (
          <div className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="edge-city-email">Email</Label>
              <Input
                id="edge-city-email"
                type="email"
                placeholder="you@example.com"
                value={email}
                onChange={(event) => setState((prev) => ({ ...prev, email: event.target.value }))}
                autoComplete="email"
              />
            </div>
            <Button className="w-full" onClick={handleRequestCode} isLoading={isRequestingCode}>
              Send verification code
            </Button>
          </div>
        )
      case 'code':
        return (
          <div className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="edge-city-code">Verification code</Label>
              <Input
                id="edge-city-code"
                placeholder="Enter the 6-digit code"
                value={code}
                onChange={(event) => setState((prev) => ({ ...prev, code: event.target.value }))}
                autoComplete="one-time-code"
              />
            </div>
            <Button className="w-full" onClick={handleVerifyCode} isLoading={isVerifyingCode}>
              Verify and continue
            </Button>
            <Button
              variant="ghost"
              className="w-full"
              onClick={() => setState((prev) => ({ ...prev, step: 'email', code: '' }))}
            >
              Resend code
            </Button>
          </div>
        )
      case 'review':
        return (
          <div className="space-y-5">
            <div className="rounded-xl border border-border bg-card p-5">
              <div className="flex items-start gap-4">
                <Avatar className="h-12 w-12 border border-border">
                  <AvatarFallback className="bg-muted text-sm font-semibold">
                    {profileInitials}
                  </AvatarFallback>
                </Avatar>
                <div className="flex-1 space-y-1">
                  <p className="text-base font-semibold leading-tight">
                    {profile?.first_name} {profile?.last_name}
                  </p>
                  <p className="text-sm text-muted-foreground">{profile?.primary_email}</p>
                </div>
                {profile?.total_days ? (
                  <Badge variant="secondary" className="text-[0.65rem] uppercase tracking-wide shrink-0">
                    {profile.total_days} days in residence
                  </Badge>
                ) : null}
              </div>
              {profile?.popups?.length ? (
                <div className="mt-5 space-y-2.5">
                  <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                    Residencies
                  </p>
                  <div className="flex flex-wrap gap-2">
                    {profile.popups.map((popup) => (
                      <Badge
                        key={popup.id}
                        variant="outline"
                        className="border-border bg-muted/50 text-[0.75rem] font-medium"
                      >
                        {popup.popup_name}
                        {popup.total_days ? (
                          <span className="ml-1 font-normal text-muted-foreground">
                            • {popup.total_days} days
                          </span>
                        ) : null}
                      </Badge>
                    ))}
                  </div>
                </div>
              ) : null}
            </div>
            <div className="space-y-3">
              <div className="rounded-xl border border-border bg-card p-4">
                <div className="flex items-center gap-3">
                  <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-muted">
                    <Wallet2 className="h-4.5 w-4.5 text-muted-foreground" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-xs uppercase tracking-wide text-muted-foreground">
                      Connected wallet
                    </p>
                    <p className="text-sm font-medium truncate">
                      {address ? truncatedAddress : 'No wallet connected'}
                    </p>
                  </div>
                  <Badge
                    variant={
                      address && eligibility.eligible
                        ? 'secondary'
                        : !address || eligibility.eligible
                          ? 'outline'
                          : 'destructive'
                    }
                    className="shrink-0"
                  >
                    {address
                      ? eligibility.eligible
                        ? 'Eligible'
                        : 'Action needed'
                      : 'Connect'}
                  </Badge>
                </div>
                {(address || eligibility.reason) && (
                  <p
                    className={`mt-3 text-sm ${
                      !eligibility.eligible && eligibility.reason ? 'text-destructive' : 'text-muted-foreground'
                    }`}
                  >
                    {!address
                      ? 'Connect a wallet to continue.'
                      : !eligibility.eligible && eligibility.reason
                        ? eligibility.reason
                        : `Wallet ${truncatedAddress} is eligible to claim tokens.`}
                  </p>
                )}
              </div>
              <div className="rounded-xl border border-border bg-card p-4">
                <div className="flex items-center gap-3">
                  <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-muted">
                    <Sparkles className="h-4.5 w-4.5 text-muted-foreground" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-xs uppercase tracking-wide text-muted-foreground">
                      Claim allowance
                    </p>
                    <p className="text-sm font-medium">
                      {allowance ? 'Ready to claim' : address ? 'Pending signature' : 'Awaiting wallet'}
                    </p>
                  </div>
                  <Badge variant={allowance ? 'secondary' : 'outline'} className="shrink-0">
                    {allowance ? (
                      <span className="flex items-center gap-1">
                        <CheckCircle2 className="h-3.5 w-3.5" />
                        Ready
                      </span>
                    ) : isLoadingAllowance ? (
                      <span className="flex items-center gap-1">
                        <Clock3 className="h-3.5 w-3.5" />
                        Loading
                      </span>
                    ) : (
                      'Not ready'
                    )}
                  </Badge>
                </div>
                {allowance ? (
                  <div className="mt-4 grid gap-4 text-sm sm:grid-cols-2">
                    <div>
                      <p className="text-xs uppercase tracking-wide text-muted-foreground">
                        Amount
                      </p>
                      <p className="mt-1 font-mono text-sm">{allowanceAmountLabel}</p>
                    </div>
                    <div>
                      <p className="text-xs uppercase tracking-wide text-muted-foreground">
                        Expires
                      </p>
                      <p className="mt-1 text-sm font-medium">{allowanceDeadlineLabel}</p>
                    </div>
                  </div>
                ) : (
                  <p className="mt-3 text-sm text-muted-foreground">
                    {address
                      ? isLoadingAllowance
                        ? 'Loading claim allowance…'
                        : 'Fetching claim allowance for this wallet.'
                      : 'Connect a wallet to fetch your claim allowance.'}
                  </p>
                )}
              </div>
            </div>
            <Button
              className="w-full"
              onClick={handleClaim}
              disabled={!eligibility.eligible || !address || !allowance || isLoadingAllowance}
              isLoading={isClaiming}
            >
              Claim tokens
            </Button>
          </div>
        )
      case 'completed':
        return (
          <div className="space-y-5">
            <div className="rounded-xl border border-border bg-card p-5 text-center">
              <div className="mx-auto mb-3 flex h-12 w-12 items-center justify-center rounded-full bg-green-500/10">
                <CheckCircle2 className="h-6 w-6 text-green-600 dark:text-green-500" />
              </div>
              <p className="text-sm font-medium">Transaction submitted</p>
              <p className="mt-2 text-sm text-muted-foreground">
                Tokens will appear once the transaction confirms.
              </p>
            </div>
            <Button className="w-full" onClick={() => setOpen(false)}>
              Close
            </Button>
          </div>
        )
      default:
        return null
    }
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button variant="outline">Edge City Claim</Button>
      </DialogTrigger>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Signals d/acc Governance experiment</DialogTitle>
          <DialogDescription>
            Authenticate with your Edge city account to claim tokens to participate.
          </DialogDescription>
        </DialogHeader>
        {renderContent()}
      </DialogContent>
    </Dialog>
  )
}
