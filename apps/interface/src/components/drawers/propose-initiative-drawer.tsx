'use client'

import { useEffect, useMemo, useState } from 'react'
import { PlusIcon } from 'lucide-react'
import { useWeb3 } from '@/contexts/WalletProvider'
import { toast } from 'sonner'
import { DateTime } from 'luxon'
import { parseUnits } from 'viem'
import { Button } from '@/components/ui/button'
import {
  Drawer,
  DrawerContent,
  DrawerFooter,
  DrawerHeader,
  DrawerTitle,
  DrawerTrigger,
} from '@/components/ui/drawer'
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
import { Alert, AlertDescription } from '../ui/alert'
import { InitiativeFormFields, type AttachmentDraft, MAX_ATTACHMENTS } from './propose-initiative-drawer/InitiativeFormFields'
import { InitiativeLockTokens } from './propose-initiative-drawer/InitiativeLockTokens'
import { InsufficientTokensMessage } from './propose-initiative-drawer/InsufficientTokensMessage'

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
  const [lockTokens, setLockTokens] = useState(false)
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [attachments, setAttachments] = useState<AttachmentDraft[]>([])
  const [internalDrawerOpen, setInternalDrawerOpen] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)

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

  const requiresMinLockAmount =
    lockTokens && minProposerLockAmount != null && minProposerLockAmount > 0

  const lockAmountBelowMinimum =
    requiresMinLockAmount && (amount == null || amount < minProposerLockAmount)

  const { balance, isLoading: isBalanceLoading } = useBalanceOf(
    address,
    board?.underlyingToken,
    isDrawerOpen,
  )

  const { isApproving, hasAllowance, handleApprove } = useApproveTokens({
    amount,
    actor: address,
    spender: board?.contractAddress,
    tokenAddress: board?.underlyingToken,
    tokenDecimals: board?.underlyingTokenDecimals ?? 18,
    enabled: isDrawerOpen,
  })

  const fetchInitiatives = useInitiativesStore((state) => state.fetchInitiatives)

  const resetFormState = () => {
    setAmount(0)
    setLockTokens(false)
    setTitle('')
    setDescription('')
    setAttachments([])
    setDuration(1)
    setIsSubmitting(false)
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

  const handleToggleLockTokens = () => {
    const nextValue = !lockTokens
    setLockTokens(nextValue)
    if (nextValue) {
      setAmount(minProposerLockAmount ?? 0)
    } else {
      setAmount(0)
      setDuration(1)
    }
  }

  // This is used to set the amount to the minimum proposer lock amount when the lock tokens toggle is enabled
  useEffect(() => {
    if (lockTokens && minProposerLockAmount != null && amount < minProposerLockAmount) {
      setAmount(minProposerLockAmount)
    }
    // We intentionally omit `amount` to avoid loops; this only reacts to new requirements/toggle state
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [lockTokens, minProposerLockAmount])

  const handleAddAttachment = () => {
    if (attachments.length >= MAX_ATTACHMENTS) {
      toast(`You can add up to ${MAX_ATTACHMENTS} attachments`)
      return
    }

    setAttachments((prev) => [...prev, { uri: '', mimeType: '', description: '' }])
  }

  const handleAttachmentChange = (index: number, field: keyof AttachmentDraft, value: string) => {
    setAttachments((prev) =>
      prev.map((attachment, idx) =>
        idx === index ? { ...attachment, [field]: value } : attachment,
      ),
    )
  }

  const handleRemoveAttachment = (index: number) => {
    setAttachments((prev) => prev.filter((_, idx) => idx !== index))
  }

  const handleSubmit = async () => {
    if (!address) throw new Error('Address not available.')
    if (lockTokens) {
      if (!amount) {
        toast('Please enter an amount to lock')
        return
      }
      if (lockAmountBelowMinimum && minProposerLockAmount != null) {
        toast(
          `This board requires at least ${minProposerLockAmount.toLocaleString()} ${symbol ?? ''} to propose.`,
        )
        return
      }
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
      const functionName = amount ? 'proposeInitiativeWithLock' : 'proposeInitiative'
      const args = amount
        ? [metadata, parseUnits(String(amount), board?.underlyingTokenDecimals ?? 18), duration]
        : [metadata]

      const { request } = await publicClient.simulateContract({
        account: address,
        address: board?.contractAddress,
        abi: SignalsABI,
        functionName,
        nonce,
        args,
      })

      const hash = await walletClient.writeContract(request)

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
        disabled={
          (lockTokens && (!amount || lockAmountBelowMinimum)) ||
          !title ||
          !description ||
          !publicClient ||
          !isInitialized
        }
        onClick={handleSubmit}
        isLoading={isSubmitting}
      >
        {isSubmitting ? 'Submitting...' : 'Submit'}
      </Button>
    )
  }

  return (
    <Drawer
      dismissible={!isSubmitting && !isApproving}
      open={isDrawerOpen}
      onOpenChange={handleOnOpenChange}
    >
      {showTrigger && (
        <DrawerTrigger asChild>
          <Button variant="icon" size="icon" onClick={handleTriggerDrawer}>
            <PlusIcon size={18} />
          </Button>
        </DrawerTrigger>
      )}
      <DrawerContent>
        <div className="overflow-y-auto p-8">
          <DrawerHeader>
            <DrawerTitle>Propose a new initiative</DrawerTitle>
            <Alert className="bg-amber-50 dark:bg-neutral-800">
              <AlertDescription>
                Signals is not a vote system. Lock only if you care enough to trade time or tokens
                for the outcome.
              </AlertDescription>
            </Alert>
          </DrawerHeader>

          {!meetsProposalThreshold(Number(balance ?? 0)) ? (
            <InsufficientTokensMessage
              requiredAmount={formatter(board.proposalThreshold)}
              symbol={symbol}
              balance={formatter(Number(balance ?? 0))}
              isBalanceLoading={isBalanceLoading}
            />
          ) : (
            <>
              <div className="flex flex-col lg:flex-row gap-8">
                {/* Left side: Title, Description, Attachments */}
                <div className="flex flex-col flex-1 lg:w-1/2">
                  <InitiativeFormFields
                    title={title}
                    description={description}
                    attachments={attachments}
                    onTitleChange={setTitle}
                    onDescriptionChange={setDescription}
                    onAddAttachment={handleAddAttachment}
                    onAttachmentChange={handleAttachmentChange}
                    onRemoveAttachment={handleRemoveAttachment}
                  />
                </div>

                {/* Right side: Lock Tokens and Preview */}
                <div className="flex flex-col flex-1 lg:w-1/2 gap-6">
                  <InitiativeLockTokens
                    lockTokens={lockTokens}
                    amount={amount}
                    duration={duration}
                    minProposerLockAmount={minProposerLockAmount}
                    lockAmountBelowMinimum={lockAmountBelowMinimum}
                    maxLockIntervals={maxLockIntervals}
                    symbol={symbol}
                    board={{
                      lockInterval: board.lockInterval,
                      acceptanceThreshold: board.acceptanceThreshold,
                      decayCurveType: board.decayCurveType,
                      decayCurveParameters: board.decayCurveParameters,
                    }}
                    formatter={formatter}
                    onToggleLock={handleToggleLockTokens}
                    onAmountChange={setAmount}
                    onDurationChange={setDuration}
                    formatDurationLabel={formatDurationLabel}
                  />

                  {/* Preview Chart */}
                  <div className="hidden lg:block">
                    <AcceptanceProgressChart
                      amount={amount}
                      duration={duration}
                      threshold={formatter(board.acceptanceThreshold)}
                      initiative={{
                        createdAt: DateTime.now().toSeconds(),
                        lockInterval: board.lockInterval,
                        decayCurveType: board.decayCurveType,
                        decayCurveParameters: board.decayCurveParameters,
                      }}
                      existingLocks={[]}
                      proposeNewInitiative={true}
                      supportInitiative={lockTokens}
                    />
                  </div>
                </div>
              </div>

            </>
          )}
        </div>
        {meetsProposalThreshold(Number(balance ?? 0)) && (
          <DrawerFooter>
            <div className="flex justify-end">{resolveAction()}</div>
          </DrawerFooter>
        )}
      </DrawerContent>
    </Drawer>
  )
}
