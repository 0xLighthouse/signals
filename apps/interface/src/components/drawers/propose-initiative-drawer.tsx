'use client'

import { useEffect, useMemo, useRef, useState } from 'react'
import { motion, AnimatePresence } from 'motion/react'
import useMeasure from 'react-use-measure'
import { PlusIcon } from 'lucide-react'
import { useWeb3 } from '@/contexts/WalletProvider'
import { toast } from 'sonner'
import { DateTime } from 'luxon'
import { parseUnits } from 'viem'
import { Button } from '@/components/ui/button'
import {
  Drawer,
  DrawerFooter,
  DrawerHeader,
  DrawerOverlay,
  DrawerPortal,
  DrawerTitle,
  DrawerTrigger,
} from '@/components/ui/drawer'
import { Drawer as DrawerPrimitive } from 'vaul'
import { useSignals } from '@/hooks/use-signals'
import { useInitiativesStore } from '@/stores/useInitiativesStore'
import { useApproveTokens } from '@/hooks/useApproveTokens'
import { AcceptanceProgressChart } from '../acceptance-progress-chart'
import { useAccount } from '@/hooks/useAccount'
import { usePrivy } from '@privy-io/react-auth'
import { useRouteStore } from '@/stores/useRouteStore'
import { SignalsABI } from '../../../../../packages/abis'
import { useBalanceOf } from '@/hooks/useBalanceOf'
import { usePublicClient } from '@/contexts/ChainProvider'
import { useWalletClient } from '@/hooks/use-wallet-client'
import {
  InitiativeFormFields,
  type AttachmentDraft,
  MAX_ATTACHMENTS,
} from './propose-initiative-drawer/InitiativeFormFields'
import { InitiativeLockTokens } from './propose-initiative-drawer/InitiativeLockTokens'
import { InsufficientTokensMessage } from './propose-initiative-drawer/InsufficientTokensMessage'

type Step = 'details' | 'lock' | 'summary'
const STEPS: Step[] = ['details', 'lock', 'summary']
const STEP_LABELS: Record<Step, string> = {
  details: 'Details',
  lock: 'Lock Tokens',
  summary: 'Review & Submit',
}

const stepVariants = {
  enter: (direction: number) => ({ x: direction > 0 ? 40 : -40, opacity: 0 }),
  center: { x: 0, opacity: 1 },
  exit: (direction: number) => ({ x: direction > 0 ? -40 : 40, opacity: 0 }),
}

type ProposeInitiativeDrawerProps = {
  open?: boolean
  onOpenChange?: (open: boolean) => void
  showTrigger?: boolean
}

export function ProposeInitiativeDrawer({
  open: externalOpen,
  onOpenChange: externalOnOpenChange,
  showTrigger = true,
}: ProposeInitiativeDrawerProps = {}) {
  const { underlyingSymbol: symbol, formatter, board, meetsProposalThreshold } = useSignals()
  const boardAddress = useRouteStore((state) => state.boardAddress)
  const { address } = useAccount()
  const { isInitialized } = useWeb3()
  const publicClient = usePublicClient()
  const walletClient = useWalletClient()
  const { authenticated, login } = usePrivy()

  const [duration, setDuration] = useState(1)
  const [amount, setAmount] = useState<number>(0)
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [attachments, setAttachments] = useState<AttachmentDraft[]>([])
  const [internalDrawerOpen, setInternalDrawerOpen] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [step, setStep] = useState<Step>('details')
  const [direction, setDirection] = useState(1)
  const [measureRef, bounds] = useMeasure()

  // Tracks whether the amount field has been initialized with the board minimum for this session
  const amountInitializedRef = useRef(false)

  const isDrawerOpen = externalOpen !== undefined ? externalOpen : internalDrawerOpen
  const setIsDrawerOpen = externalOnOpenChange || setInternalDrawerOpen

  const maxLockIntervals = useMemo(() => {
    if (board?.lockingConfig?.maxLockIntervals && Number(board.lockingConfig.maxLockIntervals) > 0)
      return Number(board.lockingConfig.maxLockIntervals)
    return 30
  }, [board?.lockingConfig?.maxLockIntervals])

  const formatDurationLabel = (seconds: number) => {
    if (!seconds || seconds < 60) return `${seconds}s`
    const days = seconds / 86400
    if (days >= 1) {
      const rounded = Math.round(days * 10) / 10
      return `${rounded} day${rounded !== 1 ? 's' : ''}`
    }
    const hours = seconds / 3600
    const rounded = Math.round(hours * 10) / 10
    return `${rounded} hour${rounded !== 1 ? 's' : ''}`
  }

  const parseRequirement = (value?: string | null): number | null => {
    if (!value) return null
    try {
      return Number(BigInt(value))
    } catch {
      const parsed = Number(value)
      return Number.isFinite(parsed) ? parsed : null
    }
  }

  const minProposerLockAmountRaw = useMemo(
    () => parseRequirement(board?.proposerRequirements?.minLockAmount),
    [board?.proposerRequirements?.minLockAmount],
  )

  const minProposerLockAmount = useMemo(() => {
    if (minProposerLockAmountRaw == null) return null
    return formatter(minProposerLockAmountRaw)
  }, [formatter, minProposerLockAmountRaw])

  // True when the board enforces a minimum lock to propose
  const boardRequiresLocking = minProposerLockAmount != null && minProposerLockAmount > 0

  // True when the user has entered an amount below the required minimum
  const lockAmountBelowMinimum =
    amount > 0 && boardRequiresLocking && amount < minProposerLockAmount!

  // Whether the current amount input is invalid for submission
  const isAmountInvalid =
    (boardRequiresLocking && amount === 0) || // board mandates locking but user entered 0
    lockAmountBelowMinimum

  const { balance, isLoading: isBalanceLoading } = useBalanceOf(
    address,
    board?.underlyingToken,
    isDrawerOpen,
  )

  const { isApproving, hasAllowance, handleApprove } = useApproveTokens({
    amount,
    actor: address,
    spender: board?.contractAddress ?? undefined,
    tokenAddress: board?.underlyingToken ?? undefined,
    tokenDecimals: board?.underlyingTokenDecimals ?? 18,
    enabled: isDrawerOpen,
  })

  const fetchInitiatives = useInitiativesStore((state) => state.fetchInitiatives)

  // Pre-fill the amount with the board minimum when drawer opens or board data loads
  useEffect(() => {
    if (isDrawerOpen && !amountInitializedRef.current && minProposerLockAmount !== null) {
      setAmount(minProposerLockAmount)
      amountInitializedRef.current = true
    }
    if (!isDrawerOpen) {
      amountInitializedRef.current = false
    }
  }, [isDrawerOpen, minProposerLockAmount])

  const resetFormState = () => {
    setAmount(minProposerLockAmount ?? 0)
    setTitle('')
    setDescription('')
    setAttachments([])
    setDuration(1)
    setIsSubmitting(false)
    setStep('details')
    setDirection(1)
  }

  const handleTriggerDrawer = (ev: React.MouseEvent<HTMLButtonElement>) => {
    ev.preventDefault()
    if (!authenticated) {
      login()
      return
    }
    if (!address) {
      toast('Please connect a wallet')
      return
    }
    setIsDrawerOpen(true)
  }

  const handleOnOpenChange = (open: boolean) => {
    if (!open) resetFormState()
    setIsDrawerOpen(open)
  }

  const handleAddAttachment = (attachment: AttachmentDraft) => {
    if (attachments.length >= MAX_ATTACHMENTS) {
      toast(`You can add up to ${MAX_ATTACHMENTS} attachments`)
      return
    }
    setAttachments((prev) => [...prev, attachment])
  }

  const handleRemoveAttachment = (index: number) => {
    setAttachments((prev) => prev.filter((_, idx) => idx !== index))
  }

  const goToStep = (target: Step) => {
    const currentIndex = STEPS.indexOf(step)
    const targetIndex = STEPS.indexOf(target)
    setDirection(targetIndex > currentIndex ? 1 : -1)
    setStep(target)
  }

  const goNext = () => {
    const currentIndex = STEPS.indexOf(step)
    if (currentIndex < STEPS.length - 1) {
      goToStep(STEPS[currentIndex + 1])
    }
  }

  const goBack = () => {
    const currentIndex = STEPS.indexOf(step)
    if (currentIndex > 0) {
      goToStep(STEPS[currentIndex - 1])
    }
  }

  const handleSubmit = async () => {
    if (!address) throw new Error('Address not available.')

    // Validate amount
    if (boardRequiresLocking && amount === 0) {
      toast(
        `This board requires at least ${minProposerLockAmount!.toLocaleString()} ${symbol ?? ''} to propose.`,
      )
      return
    }
    if (lockAmountBelowMinimum && minProposerLockAmount != null) {
      toast(
        `This board requires at least ${minProposerLockAmount.toLocaleString()} ${symbol ?? ''} to propose.`,
      )
      return
    }

    const trimmedAttachments = attachments.map((attachment) => ({
      uri: attachment.uri.trim(),
      mimeType: attachment.mimeType.trim(),
      description: attachment.description.trim(),
    }))

    const hasInvalidAttachment = trimmedAttachments.some(
      (attachment) =>
        attachment.uri.length === 0 &&
        (attachment.mimeType.length > 0 || attachment.description.length > 0),
    )

    if (hasInvalidAttachment) {
      toast('Attachment URI is required when providing attachment details')
      return
    }

    const preparedAttachments = trimmedAttachments.filter((attachment) => attachment.uri.length > 0)

    try {
      if (!isInitialized || !publicClient) {
        toast('Web3 is still initializing. Please try again in a moment.')
        return
      }
      if (!walletClient) {
        toast('Wallet not connected')
        return
      }

      setIsSubmitting(true)
      const nonce = await publicClient.getTransactionCount({ address })

      const metadata = {
        title,
        body: description,
        attachments: preparedAttachments,
      }
      const functionName = amount
        ? ('proposeInitiativeWithLock' as const)
        : ('proposeInitiative' as const)
      const args = amount
        ? ([
            metadata,
            parseUnits(String(amount), board?.underlyingTokenDecimals ?? 18),
            duration,
          ] as const)
        : ([metadata] as const)

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const { request } = await publicClient.simulateContract({
        account: address,
        address: board!.contractAddress!,
        abi: SignalsABI,
        functionName,
        nonce,
        args,
      } as any)

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const hash = await walletClient.writeContract(request as any)

      const receipt = await publicClient.waitForTransactionReceipt({
        hash,
        confirmations: 2,
        pollingInterval: 2000,
      })
      console.log('Receipt:', receipt)
      setIsDrawerOpen(false)
      resetFormState()
      toast('Initiative submitted!')
      if (boardAddress) {
        fetchInitiatives(boardAddress)
      }
    } catch (error) {
      console.error(error)
      if ((error as Error)?.message?.includes('User rejected the request')) {
        toast('User rejected the request')
      } else {
        toast('Error submitting initiative :(')
      }
      setIsSubmitting(false)
    }
  }

  const resolveAction = () => {
    if (!hasAllowance && amount) {
      return (
        <Button onClick={() => handleApprove(amount)} isLoading={isApproving}>
          {isApproving ? 'Confirming approval...' : 'Approve'}
        </Button>
      )
    }
    return (
      <Button
        disabled={isAmountInvalid || !title || !description || !publicClient || !isInitialized}
        onClick={handleSubmit}
        isLoading={isSubmitting}
      >
        {isSubmitting ? 'Submitting...' : 'Submit'}
      </Button>
    )
  }

  const canProceedFromDetails = title.trim().length > 0 && description.trim().length > 0

  const renderStepContent = () => {
    switch (step) {
      case 'details':
        return (
          <InitiativeFormFields
            title={title}
            description={description}
            attachments={attachments}
            onTitleChange={setTitle}
            onDescriptionChange={setDescription}
            onAddAttachment={handleAddAttachment}
            onRemoveAttachment={handleRemoveAttachment}
          />
        )
      case 'lock':
        return (
          <div className="flex flex-col lg:flex-row gap-8">
            <div className="flex-1 lg:w-1/2">
              <InitiativeLockTokens
                amount={amount}
                duration={duration}
                minProposerLockAmount={minProposerLockAmount}
                lockAmountBelowMinimum={lockAmountBelowMinimum}
                maxLockIntervals={maxLockIntervals}
                symbol={symbol ?? undefined}
                board={{
                  lockInterval: board.lockInterval ?? 0,
                  acceptanceThreshold: BigInt(board.acceptanceThreshold ?? 0),
                  decayCurveType: board.decayCurveType ?? 0,
                  decayCurveParameters: String(board.decayCurveParameters?.[0] ?? '0'),
                }}
                onAmountChange={setAmount}
                onDurationChange={setDuration}
                formatDurationLabel={formatDurationLabel}
              />
            </div>
            <div className="flex-1 lg:w-1/2">
              <AcceptanceProgressChart
                amount={amount}
                duration={duration}
                threshold={formatter(Number(board.acceptanceThreshold ?? 0))}
                initiative={{
                  createdAt: DateTime.now().toSeconds(),
                  lockInterval: board.lockInterval,
                  decayCurveType: board.decayCurveType,
                  decayCurveParameters: board.decayCurveParameters,
                }}
                existingLocks={[]}
                proposeNewInitiative={true}
                supportInitiative={amount > 0}
              />
            </div>
          </div>
        )
      case 'summary': {
        const lockInterval = board.lockInterval ?? 0
        const unlockDate =
          amount > 0 && lockInterval > 0
            ? DateTime.now().plus({ seconds: duration * lockInterval })
            : null
        const acceptanceThreshold = formatter(Number(board.acceptanceThreshold ?? 0))
        const initialWeight = amount > 0 ? amount * duration : 0
        const contributionPct =
          acceptanceThreshold > 0 ? Math.min((initialWeight / acceptanceThreshold) * 100, 100) : 0

        return (
          <div className="flex flex-col gap-4">
            <div className="rounded-md border border-stone-200 dark:border-stone-700 p-4 space-y-2">
              <p className="text-body-sm text-muted-foreground">Title</p>
              <p className="text-body font-medium">{title}</p>
            </div>
            <div className="rounded-md border border-stone-200 dark:border-stone-700 p-4 space-y-2">
              <p className="text-body-sm text-muted-foreground">Description</p>
              <p className="text-body whitespace-pre-wrap">{description}</p>
            </div>
            {attachments.length > 0 && (
              <div className="rounded-md border border-stone-200 dark:border-stone-700 p-4 space-y-2">
                <p className="text-body-sm text-muted-foreground">Attachments</p>
                <ul className="text-body-sm space-y-1">
                  {attachments.map((a, i) => (
                    <li key={i} className="truncate">
                      {a.uri}
                      {a.description ? ` — ${a.description}` : ''}
                    </li>
                  ))}
                </ul>
              </div>
            )}
            {amount > 0 && (
              <div className="rounded-md border border-stone-200 dark:border-stone-700 p-4 space-y-2">
                <p className="text-body-sm text-muted-foreground">Token Lock</p>
                <div className="space-y-1">
                  <p className="text-body font-medium">
                    {amount.toLocaleString()} {symbol ?? ''} for {duration} interval
                    {duration !== 1 ? 's' : ''}
                  </p>
                  {unlockDate && (
                    <p className="text-body-sm text-muted-foreground">
                      Tokens unlock {unlockDate.toRelative()} (
                      {unlockDate.toLocaleString(DateTime.DATE_MED)})
                    </p>
                  )}
                  {contributionPct > 0 && (
                    <p className="text-body-sm text-muted-foreground">
                      Initial contribution: {contributionPct.toFixed(1)}% of acceptance threshold
                    </p>
                  )}
                </div>
              </div>
            )}
          </div>
        )
      }
    }
  }

  const renderFooter = () => {
    if (!meetsProposalThreshold(Number(balance ?? 0))) return null

    switch (step) {
      case 'details':
        return (
          <DrawerFooter>
            <div className="flex justify-end">
              <Button onClick={goNext} disabled={!canProceedFromDetails}>
                Next
              </Button>
            </div>
          </DrawerFooter>
        )
      case 'lock':
        return (
          <DrawerFooter>
            <div className="flex justify-between">
              <Button variant="ghost" onClick={goBack}>
                Back
              </Button>
              <Button onClick={goNext}>Next</Button>
            </div>
          </DrawerFooter>
        )
      case 'summary':
        return (
          <DrawerFooter>
            <div className="flex justify-between">
              <Button variant="ghost" onClick={goBack}>
                Back
              </Button>
              {resolveAction()}
            </div>
          </DrawerFooter>
        )
    }
  }

  const currentStepIndex = STEPS.indexOf(step)

  return (
    <Drawer
      dismissible={!isSubmitting && !isApproving}
      open={isDrawerOpen}
      onOpenChange={handleOnOpenChange}
    >
      {showTrigger && (
        <DrawerTrigger asChild>
          <Button variant="ghost" size="icon" onClick={handleTriggerDrawer}>
            <PlusIcon size={18} />
          </Button>
        </DrawerTrigger>
      )}
      <DrawerPortal>
        <DrawerOverlay />
        <DrawerPrimitive.Content asChild>
          <motion.div
            className="group/drawer-content bg-background fixed inset-x-0 bottom-0 z-[80] mx-auto mb-16 flex flex-col overflow-hidden rounded-xl border border-stone-200 dark:border-stone-700 max-w-7xl px-0"
            animate={{
              height: bounds.height > 0 ? bounds.height : 'auto',
            }}
            transition={{
              duration: 0.27,
              ease: [0.25, 1, 0.5, 1],
            }}
            style={{ maxHeight: 'calc(80vh - 2rem)' }}
          >
            <div ref={measureRef}>
              <div className="bg-muted mx-auto mt-4 h-2 w-[100px] shrink-0 rounded-full" />
              <AnimatePresence mode="popLayout" custom={direction}>
                <motion.div
                  key={step}
                  custom={direction}
                  variants={stepVariants}
                  initial="enter"
                  animate="center"
                  exit="exit"
                  transition={{
                    duration: 0.2,
                    ease: [0.26, 0.08, 0.25, 1],
                  }}
                >
                  <div className="overflow-y-auto p-8" style={{ maxHeight: 'calc(80vh - 2rem)' }}>
                    <DrawerHeader className="flex flex-row items-center justify-between">
                      <DrawerTitle>Propose a new initiative</DrawerTitle>
                      <div className="flex items-center gap-2">
                        {STEPS.map((s, i) => (
                          <button
                            key={s}
                            type="button"
                            onClick={() => {
                              if (
                                i < currentStepIndex ||
                                (i === 1 && canProceedFromDetails) ||
                                (i === 2 && canProceedFromDetails)
                              ) {
                                goToStep(s)
                              }
                            }}
                            className={`flex items-center gap-1.5 text-xs transition-colors ${
                              s === step
                                ? 'text-foreground font-medium'
                                : i < currentStepIndex
                                  ? 'text-muted-foreground cursor-pointer hover:text-foreground'
                                  : 'text-muted-foreground/50 cursor-default'
                            }`}
                          >
                            <span
                              className={`flex h-5 w-5 items-center justify-center rounded-full text-[10px] font-medium transition-colors ${
                                s === step
                                  ? 'bg-foreground text-background'
                                  : i < currentStepIndex
                                    ? 'bg-muted-foreground/20 text-muted-foreground'
                                    : 'bg-muted-foreground/10 text-muted-foreground/50'
                              }`}
                            >
                              {i + 1}
                            </span>
                            <span className="hidden sm:inline">{STEP_LABELS[s]}</span>
                            {i < STEPS.length - 1 && (
                              <span className="text-muted-foreground/30 ml-1">/</span>
                            )}
                          </button>
                        ))}
                      </div>
                    </DrawerHeader>

                    {!meetsProposalThreshold(Number(balance ?? 0)) ? (
                      <InsufficientTokensMessage
                        requiredAmount={formatter(board.proposalThreshold)}
                        symbol={symbol ?? undefined}
                        balance={formatter(Number(balance ?? 0))}
                        isBalanceLoading={isBalanceLoading}
                      />
                    ) : (
                      renderStepContent()
                    )}
                  </div>
                  {renderFooter()}
                </motion.div>
              </AnimatePresence>
            </div>
          </motion.div>
        </DrawerPrimitive.Content>
      </DrawerPortal>
    </Drawer>
  )
}
