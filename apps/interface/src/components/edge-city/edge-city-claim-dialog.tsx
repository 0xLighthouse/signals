'use client'

import { useEffect, useMemo, useState } from 'react'
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
import { edgeCityConfig, EdgeCityProfile } from '@/config/edge-city'
import { useAccount } from '@/hooks/useAccount'
import { useWeb3 } from '@/contexts/Web3Provider'

type ClaimStep = 'email' | 'code' | 'review' | 'completed'

const initialState = {
  email: '',
  code: '',
  profile: null as EdgeCityProfile | null,
  step: 'email' as ClaimStep,
  isRequestingCode: false,
  isVerifyingCode: false,
  isClaiming: false,
}

const evaluateEligibility = (profile: EdgeCityProfile) => {
  if (!profile.email_validated) {
    return { eligible: false, reason: 'Primary email is not validated' }
  }

  if (edgeCityConfig.requiredPopups.length > 0) {
    const hasMatch = profile.popups?.some((popup) =>
      edgeCityConfig.requiredPopups.includes(String(popup.id)),
    )
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

const buildClaimArgs = (address: `0x${string}`) => {
  if (edgeCityConfig.claimFunction === 'claim' && edgeCityConfig.claimAmount) {
    return [address, edgeCityConfig.claimAmount]
  }

  return [address]
}

export const EdgeCityClaimDialog = () => {
  const { authenticated, login, ready } = usePrivy()
  const { address } = useAccount()
  const { walletClient } = useWeb3()

  const [open, setOpen] = useState(false)
  const [state, setState] = useState(initialState)

  const { email, code, profile, step, isRequestingCode, isVerifyingCode, isClaiming } = state

  const eligibility = useMemo(() => {
    if (!profile) return { eligible: false, reason: '' }
    return evaluateEligibility(profile)
  }, [profile])

  useEffect(() => {
    if (!open) {
      setState(initialState)
    }
  }, [open])

  useEffect(() => {
    if (edgeCityConfig.enabled && !edgeCityConfig.token) {
      console.warn(
        'Edge City feature enabled but NEXT_PUBLIC_EDGE_CITY_TOKEN_ADDRESS is not configured',
      )
    }
  }, [])

  if (!edgeCityConfig.enabled || !edgeCityConfig.token) {
    return null
  }

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

      const payload = (await response.json()) as { profile: EdgeCityProfile }

      setState((prev) => ({
        ...prev,
        profile: payload.profile,
        step: 'review',
      }))
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

    setState((prev) => ({ ...prev, isClaiming: true }))
    try {
      const txHash = await walletClient.writeContract({
        chain: walletClient.chain,
        account: address,
        address: edgeCityConfig.token,
        abi: edgeCityConfig.abi,
        functionName: edgeCityConfig.claimFunction,
        args: buildClaimArgs(address as `0x${string}`),
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
      } else {
        toast(error instanceof Error ? error.message : 'Failed to submit claim')
      }
    } finally {
      setState((prev) => ({ ...prev, isClaiming: false }))
    }
  }

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
          <div className="space-y-4">
            <div className="rounded-lg border border-neutral-200 dark:border-neutral-700 bg-neutral-50 dark:bg-neutral-900 p-4 space-y-2">
              <p className="text-sm font-semibold">
                {profile?.first_name} {profile?.last_name}
              </p>
              <p className="text-sm text-muted-foreground">{profile?.primary_email}</p>
              {profile?.popups?.length ? (
                <div className="text-sm">
                  <p className="font-medium">Edge City residencies ({profile.popups.length})</p>
                  <p className="text-muted-foreground">{profile.popups.length}</p>
                </div>
              ) : null}
            </div>
            {!eligibility.eligible && eligibility.reason ? (
              <p className="text-sm text-red-500">{eligibility.reason}</p>
            ) : (
              <p className="text-sm text-muted-foreground">
                Wallet {address?.slice(0, 6)}…{address?.slice(-4)} is eligible to claim tokens.
              </p>
            )}
            <Button
              className="w-full"
              onClick={handleClaim}
              disabled={!eligibility.eligible}
              isLoading={isClaiming}
            >
              Claim tokens
            </Button>
          </div>
        )
      case 'completed':
        return (
          <div className="space-y-4">
            <p className="text-sm text-muted-foreground">
              Claim transaction submitted. Tokens will appear once the transaction confirms.
            </p>
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
          <DialogTitle>Signals Experiment Claim</DialogTitle>
          <DialogDescription>
            Authenticate with your Edge City account to claim tokens to participate in the Signals
            Experiment.
          </DialogDescription>
        </DialogHeader>
        {renderContent()}
        <DialogFooter />
      </DialogContent>
    </Dialog>
  )
}
