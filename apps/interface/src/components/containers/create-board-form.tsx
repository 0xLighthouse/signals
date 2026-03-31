'use client'

import { useState, useEffect, useCallback } from 'react'
import { erc20Abi } from 'viem'
import { toast } from 'sonner'
import { usePublicClient } from '@/contexts/ChainProvider'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { useAccount } from '@/hooks/useAccount'
import { usePrivy } from '@privy-io/react-auth'
import {
  useCreateBoard,
  BOARD_DEFAULTS,
  toWei,
  percentToWAD,
  type CreateBoardParams,
} from '@/hooks/useCreateBoard'

type Step = 1 | 2 | 3 | 4
const STEPS: Step[] = [1, 2, 3, 4]
const STEP_LABELS: Record<Step, string> = {
  1: 'Board Details',
  2: 'Acceptance',
  3: 'Locking & Decay',
  4: 'Review',
}

const initialForm = (address?: string) => ({
  title: '',
  body: '',
  underlyingToken: '',
  owner: address ?? '',
  permissions: BOARD_DEFAULTS.permissions,
  thresholdOverride: BOARD_DEFAULTS.thresholdOverride,
  thresholdPercent: BOARD_DEFAULTS.thresholdPercent,
  minThreshold: BOARD_DEFAULTS.minThreshold,
  proposerMinBalance: BOARD_DEFAULTS.proposerMinBalance,
  proposerMinLock: BOARD_DEFAULTS.proposerMinLock,
  supporterMinBalance: BOARD_DEFAULTS.supporterMinBalance,
  supporterMinLock: BOARD_DEFAULTS.supporterMinLock,
  lockInterval: BOARD_DEFAULTS.lockInterval,
  maxLockIntervals: BOARD_DEFAULTS.maxLockIntervals,
  releaseLockDuration: BOARD_DEFAULTS.releaseLockDuration,
  inactivityTimeout: BOARD_DEFAULTS.inactivityTimeout,
  decayCurveType: BOARD_DEFAULTS.decayCurveType,
  decayParam: BOARD_DEFAULTS.decayParam,
  opensNow: true,
  closesNever: false,
  closesInDays: 90,
})

type TokenMeta = {
  name: string
  symbol: string
  decimals: number
  totalSupply: bigint
} | null

export function CreateBoardForm() {
  const { address } = useAccount()
  const { authenticated, login } = usePrivy()
  const { createBoard, isSubmitting } = useCreateBoard()
  const publicClient = usePublicClient()

  const [step, setStep] = useState<Step>(1)
  const [form, setForm] = useState(() => initialForm(address))
  const [tokenMeta, setTokenMeta] = useState<TokenMeta>(null)
  const [tokenLoading, setTokenLoading] = useState(false)

  const fetchTokenMeta = useCallback(async (addr: string) => {
    if (!publicClient || !addr.match(/^0x[a-fA-F0-9]{40}$/)) {
      setTokenMeta(null)
      return
    }
    setTokenLoading(true)
    try {
      const tokenAddr = addr as `0x${string}`
      const [name, symbol, decimals, totalSupply] = await Promise.all([
        publicClient.readContract({ address: tokenAddr, abi: erc20Abi, functionName: 'name' }),
        publicClient.readContract({ address: tokenAddr, abi: erc20Abi, functionName: 'symbol' }),
        publicClient.readContract({ address: tokenAddr, abi: erc20Abi, functionName: 'decimals' }),
        publicClient.readContract({ address: tokenAddr, abi: erc20Abi, functionName: 'totalSupply' }),
      ])
      setTokenMeta({ name: name as string, symbol: symbol as string, decimals: Number(decimals), totalSupply: totalSupply as bigint })
    } catch {
      setTokenMeta(null)
    } finally {
      setTokenLoading(false)
    }
  }, [publicClient])

  useEffect(() => {
    if (form.underlyingToken.match(/^0x[a-fA-F0-9]{40}$/)) {
      fetchTokenMeta(form.underlyingToken)
    } else {
      setTokenMeta(null)
    }
  }, [form.underlyingToken, fetchTokenMeta])

  const sym = tokenMeta?.symbol ?? 'tokens'

  const update = <K extends keyof ReturnType<typeof initialForm>>(
    key: K,
    value: ReturnType<typeof initialForm>[K],
  ) => {
    setForm((prev) => ({ ...prev, [key]: value }))
  }

  // -- Validation --

  const validateStep1 = (): boolean => {
    if (!form.title.trim()) {
      toast('Title is required')
      return false
    }
    if (!form.underlyingToken.trim().startsWith('0x')) {
      toast('Governance token must be a valid 0x address')
      return false
    }
    return true
  }

  const validateStep2 = (): boolean => {
    if (form.proposerMinLock > form.proposerMinBalance) {
      toast('Proposer min lock amount must be <= min balance')
      return false
    }
    if (form.supporterMinLock > form.supporterMinBalance) {
      toast('Supporter min lock amount must be <= min balance')
      return false
    }
    return true
  }

  const validateStep3 = (): boolean => {
    if (form.lockInterval <= 0) {
      toast('Lock interval must be greater than 0')
      return false
    }
    if (form.maxLockIntervals <= 0) {
      toast('Max lock intervals must be greater than 0')
      return false
    }
    return true
  }

  const goNext = () => {
    if (step === 1 && !validateStep1()) return
    if (step === 2 && !validateStep2()) return
    if (step === 3 && !validateStep3()) return
    if (step < 4) setStep((step + 1) as Step)
  }

  const goBack = () => {
    if (step > 1) setStep((step - 1) as Step)
  }

  // -- Submit --

  const handleSubmit = async () => {
    if (!authenticated) {
      login()
      return
    }
    if (!address) {
      toast('Please connect a wallet')
      return
    }

    const params: CreateBoardParams = {
      title: form.title,
      body: form.body,
      owner: (form.owner || address) as `0x${string}`,
      underlyingToken: form.underlyingToken as `0x${string}`,
      opensAt: form.opensNow ? Math.floor(Date.now() / 1000) : Math.floor(Date.now() / 1000),
      closesAt: form.closesNever ? 0 : Math.floor(Date.now() / 1000) + form.closesInDays * 86400,
      permissions: form.permissions,
      thresholdOverride: form.thresholdOverride,
      thresholdPercentTotalSupplyWAD: percentToWAD(form.thresholdPercent),
      minThreshold: toWei(form.minThreshold),
      proposerMinBalance: toWei(form.proposerMinBalance),
      proposerMinHoldingDuration: 0n,
      proposerMinLock: toWei(form.proposerMinLock),
      supporterMinBalance: toWei(form.supporterMinBalance),
      supporterMinHoldingDuration: 0n,
      supporterMinLock: toWei(form.supporterMinLock),
      lockInterval: BigInt(form.lockInterval),
      maxLockIntervals: BigInt(form.maxLockIntervals),
      releaseLockDuration: BigInt(form.releaseLockDuration),
      inactivityTimeout: BigInt(form.inactivityTimeout),
      decayCurveType: form.decayCurveType,
      decayParams: [toWei(form.decayParam)],
    }

    await createBoard(params)
  }

  // -- Step Renderers --

  const renderStepIndicator = () => (
    <div className="flex items-center gap-2">
      {STEPS.map((s, i) => (
        <button
          key={s}
          type="button"
          onClick={() => {
            if (s < step) setStep(s)
          }}
          className={`flex items-center gap-1.5 text-sm transition-colors ${
            s === step
              ? 'text-foreground font-medium'
              : s < step
                ? 'text-muted-foreground cursor-pointer hover:text-foreground'
                : 'text-muted-foreground/50 cursor-default'
          }`}
        >
          <span
            className={`flex h-5 w-5 items-center justify-center rounded-full text-[10px] font-medium transition-colors ${
              s === step
                ? 'bg-foreground text-background'
                : s < step
                  ? 'bg-muted-foreground/20 text-muted-foreground'
                  : 'bg-muted-foreground/10 text-muted-foreground/50'
            }`}
          >
            {s}
          </span>
          <span className="hidden sm:inline">{STEP_LABELS[s]}</span>
          {i < STEPS.length - 1 && (
            <span className="text-muted-foreground/30 ml-1">/</span>
          )}
        </button>
      ))}
    </div>
  )

  const renderStep1 = () => (
    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
      <div className="space-y-6">
        <div className="space-y-2">
          <Label htmlFor="title" className="text-base">Title *</Label>
          <Input
            id="title"
            className="h-11 text-base"
            value={form.title}
            onChange={(e) => update('title', e.target.value)}
            placeholder="My Governance Board"
          />
        </div>

        <div className="space-y-2">
          <Label htmlFor="body" className="text-base">Description</Label>
          <Textarea
            id="body"
            className="text-base"
            value={form.body}
            onChange={(e) => update('body', e.target.value)}
            placeholder="What is this board for?"
            rows={5}
          />
        </div>
      </div>

      <div className="space-y-6">
        <div className="space-y-2">
          <Label htmlFor="underlyingToken" className="text-base">Token *</Label>
          <Input
            id="underlyingToken"
            className="h-11 text-base"
            value={form.underlyingToken}
            onChange={(e) => update('underlyingToken', e.target.value)}
            placeholder="0x..."
          />
          {tokenLoading && (
            <p className="text-sm text-muted-foreground">Loading token info...</p>
          )}
          {tokenMeta && (
            <p className="text-sm text-muted-foreground">
              {tokenMeta.name} ({tokenMeta.symbol}) &middot; {Number(tokenMeta.totalSupply / BigInt(10 ** tokenMeta.decimals)).toLocaleString()} supply
            </p>
          )}
          {!tokenMeta && !tokenLoading && (
            <p className="text-sm text-muted-foreground">
              ERC-20 token address used for locking and governance
            </p>
          )}
        </div>

        <div className="space-y-2">
          <Label htmlFor="owner" className="text-base">Owner</Label>
          <Input
            id="owner"
            className="h-11 text-base"
            value={form.owner}
            onChange={(e) => update('owner', e.target.value)}
            placeholder={address ?? '0x...'}
          />
          <p className="text-sm text-muted-foreground">
            Defaults to your connected wallet if left empty
          </p>
        </div>
      </div>
    </div>
  )

  const renderStep2 = () => (
    <div className="grid grid-cols-1 md:grid-cols-[2fr_3fr] gap-8">
      <div className="space-y-5">
        <div className="space-y-2">
          <Label htmlFor="permissions" className="text-base">Who can accept?</Label>
          <Select
            value={String(form.permissions)}
            onValueChange={(v) => update('permissions', Number(v) as 0 | 1)}
          >
            <SelectTrigger id="permissions" className="h-11 text-base">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="0">Anyone (if threshold met)</SelectItem>
              <SelectItem value="1">Only owner</SelectItem>
            </SelectContent>
          </Select>
        </div>

        <div className="space-y-2">
          <Label htmlFor="thresholdOverride" className="text-base">Owner bypasses threshold?</Label>
          <Select
            value={String(form.thresholdOverride)}
            onValueChange={(v) => update('thresholdOverride', Number(v) as 0 | 1)}
          >
            <SelectTrigger id="thresholdOverride" className="h-11 text-base">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="0">No</SelectItem>
              <SelectItem value="1">Yes</SelectItem>
            </SelectContent>
          </Select>
        </div>

        <div className="space-y-2">
          <Label htmlFor="minThreshold" className="text-base">Acceptance threshold ({sym})</Label>
          <Input
            id="minThreshold"
            className="h-11 text-base"
            type="number"
            value={form.minThreshold}
            onChange={(e) => update('minThreshold', Number(e.target.value))}
          />
          <p className="text-sm text-muted-foreground">
            An initiative can be accepted once it reaches this level of support
          </p>
        </div>
      </div>

      <div className="space-y-5">
        <div className="grid grid-cols-3 gap-4 items-end">
          <div />
          <Label className="text-sm text-muted-foreground">Proposer</Label>
          <Label className="text-sm text-muted-foreground">Supporter</Label>

          <Label className="self-center text-base">Min balance ({sym})</Label>
          <Input
            className="h-11 text-base"
            type="number"
            value={form.proposerMinBalance}
            onChange={(e) => update('proposerMinBalance', Number(e.target.value))}
          />
          <Input
            className="h-11 text-base"
            type="number"
            value={form.supporterMinBalance}
            onChange={(e) => update('supporterMinBalance', Number(e.target.value))}
          />

          <Label className="self-center text-base">Min lock ({sym})</Label>
          <Input
            className="h-11 text-base"
            type="number"
            value={form.proposerMinLock}
            onChange={(e) => update('proposerMinLock', Number(e.target.value))}
          />
          <Input
            className="h-11 text-base"
            type="number"
            value={form.supporterMinLock}
            onChange={(e) => update('supporterMinLock', Number(e.target.value))}
          />
        </div>
        <p className="text-sm text-muted-foreground">
          Min lock must be &le; min balance for each role. Values in {sym}.
        </p>
      </div>
    </div>
  )

  const renderStep3 = () => (
    <div className="space-y-5">
      <h3 className="text-lg font-semibold">Locking & Decay</h3>

      <div className="space-y-2">
        <Label htmlFor="lockInterval" className="text-base">Lock Interval</Label>
        <Select
          value={String(form.lockInterval)}
          onValueChange={(v) => update('lockInterval', Number(v))}
        >
          <SelectTrigger id="lockInterval" className="h-11 text-base">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="3600">1 hour</SelectItem>
            <SelectItem value="86400">1 day</SelectItem>
            <SelectItem value="604800">1 week</SelectItem>
          </SelectContent>
        </Select>
        <p className="text-sm text-muted-foreground">
          Duration of a single lock interval
        </p>
      </div>

      <div className="space-y-2">
        <Label htmlFor="maxLockIntervals" className="text-base">Max Lock Intervals</Label>
        <Input
          id="maxLockIntervals"
          className="h-11 text-base"
          type="number"
          value={form.maxLockIntervals}
          onChange={(e) => update('maxLockIntervals', Number(e.target.value))}
        />
        <p className="text-sm text-muted-foreground">
          Maximum number of intervals tokens can be locked
        </p>
      </div>

      <div className="space-y-2">
        <Label htmlFor="inactivityTimeout" className="text-base">Inactivity Timeout</Label>
        <Select
          value={String(form.inactivityTimeout)}
          onValueChange={(v) => update('inactivityTimeout', Number(v))}
        >
          <SelectTrigger id="inactivityTimeout" className="h-11 text-base">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="86400">1 day</SelectItem>
            <SelectItem value="259200">3 days</SelectItem>
            <SelectItem value="604800">7 days</SelectItem>
            <SelectItem value="1209600">14 days</SelectItem>
          </SelectContent>
        </Select>
        <p className="text-sm text-muted-foreground">
          Time before an initiative is considered inactive
        </p>
      </div>

      <div className="space-y-2">
        <Label htmlFor="releaseLockDuration" className="text-base">Release Lock Duration (seconds)</Label>
        <Input
          id="releaseLockDuration"
          className="h-11 text-base"
          type="number"
          value={form.releaseLockDuration}
          onChange={(e) => update('releaseLockDuration', Number(e.target.value))}
        />
        <p className="text-sm text-muted-foreground">
          Delay before locked tokens can be withdrawn after unlock (0 = immediate)
        </p>
      </div>

      <div className="space-y-2">
        <Label htmlFor="decayCurveType" className="text-base">Decay Curve</Label>
        <Select
          value={String(form.decayCurveType)}
          onValueChange={(v) => update('decayCurveType', Number(v) as 0 | 1)}
        >
          <SelectTrigger id="decayCurveType" className="h-11 text-base">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="0">Linear</SelectItem>
            <SelectItem value="1">Exponential</SelectItem>
          </SelectContent>
        </Select>
      </div>

      <div className="space-y-2">
        <Label htmlFor="decayParam" className="text-base">Decay Parameter</Label>
        <Input
          id="decayParam"
          className="h-11 text-base"
          type="number"
          step="0.01"
          value={form.decayParam}
          onChange={(e) => update('decayParam', Number(e.target.value))}
        />
        <p className="text-sm text-muted-foreground">
          {form.decayCurveType === 0
            ? 'Linear: rate at which weight decays proportional to lock length'
            : 'Exponential: multiplier applied each interval (e.g. 0.92 = 8% decay per interval)'}
        </p>
      </div>

      <h4 className="text-base font-semibold pt-2">Schedule</h4>

      <div className="flex items-center gap-3">
        <input
          id="opensNow"
          type="checkbox"
          checked={form.opensNow}
          onChange={(e) => update('opensNow', e.target.checked)}
          className="h-4 w-4 rounded border-input"
        />
        <Label htmlFor="opensNow" className="text-base">Open immediately</Label>
      </div>

      <div className="flex items-center gap-3">
        <input
          id="closesNever"
          type="checkbox"
          checked={form.closesNever}
          onChange={(e) => update('closesNever', e.target.checked)}
          className="h-4 w-4 rounded border-input"
        />
        <Label htmlFor="closesNever" className="text-base">Never closes</Label>
      </div>

      {!form.closesNever && (
        <div className="space-y-2">
          <Label htmlFor="closesInDays" className="text-base">Closes in (days)</Label>
          <Input
            id="closesInDays"
            className="h-11 text-base"
            type="number"
            value={form.closesInDays}
            onChange={(e) => update('closesInDays', Number(e.target.value))}
          />
        </div>
      )}
    </div>
  )

  const formatLockInterval = (seconds: number): string => {
    if (seconds === 3600) return '1 hour'
    if (seconds === 86400) return '1 day'
    if (seconds === 604800) return '1 week'
    return `${seconds}s`
  }

  const formatTimeout = (seconds: number): string => {
    const days = seconds / 86400
    if (days === 1) return '1 day'
    return `${days} days`
  }

  const renderStep4 = () => (
    <div className="space-y-4">
      <h3 className="text-base font-semibold">Review & Submit</h3>

      <div className="rounded-md border border-stone-200 dark:border-stone-700 p-4 space-y-2">
        <p className="text-xs text-muted-foreground">Title</p>
        <p className="text-sm font-medium">{form.title || '(untitled)'}</p>
        {form.body && (
          <>
            <p className="text-xs text-muted-foreground mt-3">Description</p>
            <p className="text-sm whitespace-pre-wrap">{form.body}</p>
          </>
        )}
      </div>

      <div className="rounded-md border border-stone-200 dark:border-stone-700 p-4 space-y-2">
        <p className="text-xs text-muted-foreground">Token</p>
        <p className="font-mono text-sm break-all">
          {form.underlyingToken}
          {tokenMeta && <span className="font-sans ml-2 text-muted-foreground">({tokenMeta.name})</span>}
        </p>
        <p className="text-xs text-muted-foreground mt-3">Owner</p>
        <p className="font-mono text-sm break-all">{form.owner || address || '(connected wallet)'}</p>
      </div>

      <div className="rounded-md border border-stone-200 dark:border-stone-700 p-4 space-y-1">
        <p className="text-xs text-muted-foreground mb-2">Acceptance</p>
        <p className="text-sm">
          Permissions: {form.permissions === 0 ? 'Permissionless' : 'Only Owner'}
        </p>
        <p className="text-sm">
          Threshold Override: {form.thresholdOverride === 0 ? 'None' : 'Only Owner'}
        </p>
        <p className="text-sm">
          Threshold: {form.thresholdPercent}% of supply (min {form.minThreshold.toLocaleString()} {sym})
        </p>
      </div>

      <div className="rounded-md border border-stone-200 dark:border-stone-700 p-4 space-y-1">
        <p className="text-xs text-muted-foreground mb-2">Participation</p>
        <p className="text-sm">
          Proposer: {form.proposerMinBalance.toLocaleString()} {sym} min balance, {form.proposerMinLock.toLocaleString()} {sym} min lock
        </p>
        <p className="text-sm">
          Supporter: {form.supporterMinBalance.toLocaleString()} {sym} min balance, {form.supporterMinLock.toLocaleString()} {sym} min lock
        </p>
      </div>

      <div className="rounded-md border border-stone-200 dark:border-stone-700 p-4 space-y-1">
        <p className="text-xs text-muted-foreground mb-2">Locking & Decay</p>
        <p className="text-sm">
          Lock: {formatLockInterval(form.lockInterval)} x {form.maxLockIntervals} max intervals
        </p>
        <p className="text-sm">
          Inactivity timeout: {formatTimeout(form.inactivityTimeout)}
        </p>
        <p className="text-sm">
          Release lock duration: {form.releaseLockDuration === 0 ? 'Immediate' : `${form.releaseLockDuration}s`}
        </p>
        <p className="text-sm">
          Decay: {form.decayCurveType === 0 ? 'Linear' : 'Exponential'} ({form.decayParam})
        </p>
      </div>

      <div className="rounded-md border border-stone-200 dark:border-stone-700 p-4 space-y-1">
        <p className="text-xs text-muted-foreground mb-2">Schedule</p>
        <p className="text-sm">
          Opens: {form.opensNow ? 'Immediately' : 'Custom date'}
        </p>
        <p className="text-sm">
          Closes: {form.closesNever ? 'Never' : `In ${form.closesInDays} days`}
        </p>
      </div>
    </div>
  )

  const renderStepContent = () => {
    switch (step) {
      case 1: return renderStep1()
      case 2: return renderStep2()
      case 3: return renderStep3()
      case 4: return renderStep4()
    }
  }

  return (
    <div className="max-w-5xl mx-auto">
      <div className="flex items-center justify-center py-4">
        {renderStepIndicator()}
      </div>

      <div className="py-6">
        {renderStepContent()}
      </div>

      <div className="flex justify-between py-6 border-t border-stone-200 dark:border-stone-700">
        {step > 1 ? (
          <Button variant="ghost" onClick={goBack} disabled={isSubmitting}>
            Back
          </Button>
        ) : (
          <div />
        )}
        {step < 4 ? (
          <Button onClick={goNext}>Next</Button>
        ) : (
          <Button onClick={handleSubmit} isLoading={isSubmitting}>
            {isSubmitting ? 'Creating...' : 'Create Board'}
          </Button>
        )}
      </div>
    </div>
  )
}
