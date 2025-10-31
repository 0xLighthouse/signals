import { useState } from 'react'
import { CircleAlert, PlusIcon, Trash2 } from 'lucide-react'
import { useWeb3 } from '@/contexts/Web3Provider'
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
import { useUnderlying } from '@/contexts/ContractContext'
import { useSignals } from '@/contexts/SignalsContext'
import { useInitiativesStore } from '@/stores/useInitiativesStore'
import { useApproveTokens } from '@/hooks/useApproveTokens'
import { SubmissionLockDetails } from '../containers/submission-lock-details'
import { SwitchContainer } from '../ui/switch-container'
import { useAccount } from '@/hooks/useAccount'
import { usePrivy } from '@privy-io/react-auth'
import { Typography } from '../ui/typography'
import { useNetwork } from '@/hooks/useNetwork'

type AttachmentDraft = {
  uri: string
  mimeType: string
  description: string
}

const MAX_ATTACHMENTS = 5

export function CreateInitiativeDrawer() {
  const { balance, symbol, fetchContractMetadata } = useUnderlying()
  const { address } = useAccount()
  const { walletClient, publicClient } = useWeb3()
  const { authenticated, login } = usePrivy()
  const { formatter, board } = useSignals()
  const { config } = useNetwork()
  const signalsContract = config.contracts.SignalsProtocol
  const underlyingContract = config.contracts.BoardUnderlyingToken

  const [duration, setDuration] = useState(1)
  const [amount, setAmount] = useState<number>(0)
  const [lockTokens, setLockTokens] = useState(false)
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [attachments, setAttachments] = useState<AttachmentDraft[]>([])
  const [isDrawerOpen, setIsDrawerOpen] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)

  const { isApproving, hasAllowance, handleApprove } = useApproveTokens({
    amount,
    actor: address,
    spender: signalsContract?.address,
    tokenAddress: underlyingContract?.address,
    tokenDecimals: underlyingContract?.decimals ?? 18,
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

  const handleAddAttachment = () => {
    if (attachments.length >= MAX_ATTACHMENTS) {
      toast(`You can add up to ${MAX_ATTACHMENTS} attachments`)
      return
    }

    setAttachments((prev) => [...prev, { uri: '', mimeType: '', description: '' }])
  }

  const handleAttachmentChange = (index: number, field: keyof AttachmentDraft, value: string) => {
    setAttachments((prev) =>
      prev.map((attachment, idx) => (idx === index ? { ...attachment, [field]: value } : attachment)),
    )
  }

  const handleRemoveAttachment = (index: number) => {
    setAttachments((prev) => prev.filter((_, idx) => idx !== index))
  }

  const handleSubmit = async () => {
    if (!address) throw new Error('Address not available.')
    if (lockTokens && !amount) {
      toast('Please enter an amount to lock')
      return
    }

    const trimmedAttachments = attachments.map((attachment) => ({
      uri: attachment.uri.trim(),
      mimeType: attachment.mimeType.trim(),
      description: attachment.description.trim(),
    }))

    const hasInvalidAttachment = trimmedAttachments.some(
      (attachment) =>
        attachment.uri.length === 0 && (attachment.mimeType.length > 0 || attachment.description.length > 0),
    )

    if (hasInvalidAttachment) {
      toast('Attachment URI is required when providing attachment details')
      return
    }

    const preparedAttachments = trimmedAttachments.filter((attachment) => attachment.uri.length > 0)

    try {
      if (!walletClient) {
        toast('Wallet not connected')
        return
      }
      if (!signalsContract) {
        toast('Network is missing Signals configuration. Please try again later.')
        return
      }

      setIsSubmitting(true)
      const nonce = await publicClient.getTransactionCount({ address })

      const functionName = amount ? 'proposeInitiativeWithLock' : 'proposeInitiative'
      const args = amount
        ? [
            title,
            description,
            parseUnits(
              String(amount),
              underlyingContract?.decimals ?? 18,
            ),
            duration,
            preparedAttachments,
          ]
        : [title, description, preparedAttachments]

      const { request } = await publicClient.simulateContract({
        account: address,
        address: signalsContract.address,
        abi: signalsContract.abi,
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
      fetchInitiatives()
      fetchContractMetadata()
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
    if (!board.meetsThreshold) {
      return <Button disabled>Insufficient tokens</Button>
    }

    if (!hasAllowance && amount) {
      return (
        <Button onClick={() => handleApprove(amount)} isLoading={isApproving}>
          {isApproving ? 'Confirming approval...' : 'Approve'}
        </Button>
      )
    }
    return (
      <Button
        disabled={(lockTokens && !amount) || !title || !description}
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
      <DrawerTrigger asChild>
        <Button variant="icon" size="icon" onClick={handleTriggerDrawer}>
          <PlusIcon size={18} />
        </Button>
      </DrawerTrigger>
      <DrawerContent>
        <div className="overflow-y-auto flex p-8 space-x-8">
          <div className="flex flex-col mx-auto lg:w-3/5">
            <DrawerHeader>
              <DrawerTitle>
                <Typography variant="h2">Propose a new initiative</Typography>
              </DrawerTitle>
            </DrawerHeader>

            {!board.meetsThreshold ? (
              <div className="flex flex-col items-center justify-center py-12 text-center">
                <CircleAlert className="h-12 w-12 text-orange-500 mb-4" />
                <Typography variant="h3" className="mb-2">
                  Insufficient tokens
                </Typography>
                <Typography variant="body" className="text-muted-foreground max-w-md">
                  You need at least {formatter(board.proposalThreshold)} {symbol} tokens to propose
                  an initiative. Please acquire more tokens before trying again.
                </Typography>
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
                    Optional supporting links or files. Provide a URI along with an optional MIME type and description.
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
                            onChange={(e) => handleAttachmentChange(index, 'mimeType', e.target.value)}
                          />
                        </div>
                        <div>
                          <Label htmlFor={`attachment-description-${index}`}>Description</Label>
                          <Input
                            id={`attachment-description-${index}`}
                            placeholder="Short description"
                            value={attachment.description}
                            onChange={(e) => handleAttachmentChange(index, 'description', e.target.value)}
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
                    onCheckedChange={() => {
                      setLockTokens(!lockTokens)
                      setAmount(0)
                      setDuration(1)
                    }}
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
                          min="0"
                        />
                        {lockTokens && !amount && (
                          <Label className="text-red-500 mt-2">
                            Please enter an amount to lock
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
                          defaultValue={[1]}
                          step={1}
                          min={1}
                          max={30}
                          onValueChange={(value) => setDuration(value[0])}
                        />
                        <p className="ml-4">{`${duration} day${duration !== 1 ? 's' : ''}`}</p>
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
