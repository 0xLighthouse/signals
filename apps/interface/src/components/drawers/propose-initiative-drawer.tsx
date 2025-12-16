'use client'

import { useEffect, useMemo, useState } from 'react'
import { CircleAlert, Loader2, PlusIcon, Trash2 } from 'lucide-react'
import { useWeb3 } from '@/contexts/WalletProvider'
import { toast } from 'sonner'
import { DateTime } from 'luxon'
import { parseUnits } from 'viem'
import { Button } from '@/components/ui/button'
import {
  Drawer,
  DrawerContent,
  DrawerHeader,
  DrawerTitle,
  DrawerTrigger,
} from '@/components/ui/drawer'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { Switch } from '@/components/ui/switch'
import { Slider } from '@/components/ui/slider'
import { useSignals } from '@/hooks/use-signals'
import { useInitiativesStore } from '@/stores/useInitiativesStore'
import { useApproveTokens } from '@/hooks/useApproveTokens'
import { SubmissionLockDetails } from '../containers/submission-lock-details'
import { SwitchContainer } from '../ui/switch-container'
import { useAccount } from '@/hooks/useAccount'
import { usePrivy } from '@privy-io/react-auth'
import { Typography } from '../ui/typography'
import { useRouteStore } from '@/stores/useRouteStore'
import { SignalsABI } from '../../../../../packages/abis'
import { useBalanceOf } from '@/hooks/useBalanceOf'
import { usePublicClient } from '@/contexts/ChainProvider'
import { useWalletClient } from '@/hooks/use-wallet-client'
import { Alert, AlertDescription } from '../ui/alert'

type AttachmentDraft = {
  uri: string
  mimeType: string
  description: string
}

const MAX_ATTACHMENTS = 5

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
    if (board?.maxLockIntervals && board.maxLockIntervals > 0) return board.maxLockIntervals
    return 30
  }, [board?.maxLockIntervals])

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
        <div className="overflow-y-auto flex p-8 space-x-8">
          <div className="flex flex-col mx-auto lg:w-3/5">
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
              <div className="flex flex-col items-center justify-center py-12 text-center">
                <CircleAlert className="h-12 w-12 text-orange-500 mb-4" />
                <Typography variant="h3" className="mb-2">
                  Insufficient tokens
                </Typography>
                <Typography variant="body" className="text-muted-foreground max-w-md">
                  You need at least {formatter(board.proposalThreshold)} {symbol} tokens to propose
                  an initiative. Please acquire more tokens before trying again.
                </Typography>
                {isBalanceLoading ? (
                  <div className="mt-3 flex items-center gap-2 text-muted-foreground">
                    <Loader2 className="h-4 w-4 animate-spin" />
                    <Typography variant="body-sm">Fetching your balance…</Typography>
                  </div>
                ) : (
                  <Typography variant="body-sm" className="text-muted-foreground mt-3">
                    Your balance: {formatter(Number(balance ?? 0))} {symbol}
                  </Typography>
                )}
              </div>
            ) : (
              <>
                <div className="my-2">
                  <Label htmlFor="title">Title</Label>
                  <Input
                    id="title"
                    placeholder='For example, "On-chain forums"'
                    value={title}
                    onChange={(e) => setTitle(e.target.value)}
                  />
                </div>
                <div className="my-2">
                  <Label htmlFor="description">Description</Label>
                  <Textarea
                    id="description"
                    placeholder="Include details of your initiative. Remember to search for existing ideas first."
                    required
                    value={description}
                    onChange={(e) => setDescription(e.target.value)}
                    style={{ resize: 'none', height: '200px' }}
                  />
                </div>
                <div className="my-4">
                  <Label>Attachments</Label>
                  <p className="text-sm text-muted-foreground mb-2">
                    Optional supporting links or files. Provide a URI along with an optional MIME
                    type and description.
                  </p>
                  {attachments.map((attachment, index) => (
                    <div key={`attachment-${index}`} className="mb-4 rounded-md border p-4">
                      <div className="flex flex-col gap-2 md:flex-row md:items-start md:gap-4">
                        <div className="flex-1">
                          <Label htmlFor={`attachment-uri-${index}`}>URI</Label>
                          <Input
                            id={`attachment-uri-${index}`}
                            placeholder="https:// or ipfs://"
                            value={attachment.uri}
                            onChange={(e) => handleAttachmentChange(index, 'uri', e.target.value)}
                          />
                        </div>
                        <Button
                          type="button"
                          variant="ghost"
                          size="icon"
                          className="mt-2 self-start text-muted-foreground hover:text-foreground"
                          onClick={() => handleRemoveAttachment(index)}
                          aria-label="Remove attachment"
                        >
                          <Trash2 size={16} />
                        </Button>
                      </div>
                      <div className="mt-2 grid gap-2 md:grid-cols-2">
                        <div>
                          <Label htmlFor={`attachment-mime-${index}`}>MIME type</Label>
                          <Input
                            id={`attachment-mime-${index}`}
                            placeholder="application/pdf"
                            value={attachment.mimeType}
                            onChange={(e) =>
                              handleAttachmentChange(index, 'mimeType', e.target.value)
                            }
                          />
                        </div>
                        <div>
                          <Label htmlFor={`attachment-description-${index}`}>Description</Label>
                          <Input
                            id={`attachment-description-${index}`}
                            placeholder="Short description"
                            value={attachment.description}
                            onChange={(e) =>
                              handleAttachmentChange(index, 'description', e.target.value)
                            }
                          />
                        </div>
                      </div>
                    </div>
                  ))}
                  <Button
                    type="button"
                    variant="outline"
                    onClick={handleAddAttachment}
                    disabled={attachments.length >= MAX_ATTACHMENTS}
                  >
                    Add attachment
                  </Button>
                </div>
                <SwitchContainer>
                  <Switch
                    id="lock-tokens"
                    checked={lockTokens}
                    onCheckedChange={handleToggleLockTokens}
                  />
                  <Label htmlFor="lock-tokens">Also lock tokens to add support</Label>
                </SwitchContainer>
                {lockTokens && (
                  <div className="flex flex-col gap-8 my-2">
                    <div className="flex items-center">
                      <Label className="w-1/5 flex items-center" htmlFor="amount">
                        Amount
                      </Label>
                      <div className="w-4/5 flex flex-col">
                        <Input
                          id="amount"
                          type="number"
                          value={amount ?? ''}
                          onChange={(e) => setAmount(e.target.value ? Number(e.target.value) : 0)}
                          min={minProposerLockAmount ?? 0}
                        />
                        {lockTokens && !amount && (
                          <Label className="text-red-500 mt-2">
                            Please enter an amount to lock
                          </Label>
                        )}
                        {lockTokens &&
                          minProposerLockAmount != null &&
                          minProposerLockAmount > 0 && (
                            <Label className="text-sm text-muted-foreground mt-2">
                              Minimum to propose: {minProposerLockAmount.toLocaleString()} {symbol}
                            </Label>
                          )}
                        {lockAmountBelowMinimum && minProposerLockAmount != null && (
                          <Label className="text-red-500 mt-2">
                            Enter at least {minProposerLockAmount.toLocaleString()} {symbol} to meet
                            proposer requirements
                          </Label>
                        )}
                      </div>
                    </div>
                    <div className="flex items-center">
                      <Label className="w-1/5 flex items-center" htmlFor="duration">
                        Duration
                      </Label>
                      <div className="w-4/5 flex items-center justify-center whitespace-nowrap">
                        <Slider
                          value={[duration]}
                          step={1}
                          min={1}
                          max={maxLockIntervals}
                          onValueChange={(value) => setDuration(value[0])}
                        />
                        <p className="ml-4">
                          {`${duration} interval${duration !== 1 ? 's' : ''}`}
                          {board.lockInterval
                            ? ` (${formatDurationLabel(duration * board.lockInterval)})`
                            : ''}
                        </p>
                      </div>
                    </div>
                    <div className="block lg:hidden">
                      <SubmissionLockDetails
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
                )}
              </>
            )}

            <div className="flex justify-end py-8">{resolveAction()}</div>
          </div>
          <div className="hidden lg:block w-2/5 lg:mt-6">
            <SubmissionLockDetails
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
      </DrawerContent>
    </Drawer>
  )
}
