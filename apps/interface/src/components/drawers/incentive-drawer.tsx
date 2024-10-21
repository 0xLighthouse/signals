'use client'

import { CircleAlert, DollarSign } from 'lucide-react'
import { toast } from 'sonner'
import { ethers } from 'ethers'

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
import { useAccount } from 'wagmi'
import { useState } from 'react'
import { Alert, AlertDescription, AlertTitle } from '../ui/alert'
import { NormalisedInitiative } from '@/app/api/initiatives/route'
import { TokenSelector } from '../token-selector'
import { INCENTIVES, INCENTIVES_ABI, SIGNALS_PROTOCOL, USDC_ADDRESS } from '@/config/web3'
import { useApproveTokens } from '@/hooks/useApproveTokens'
import { useCheckAllowance } from '@/hooks/useCheckAllowance'

interface Props {
  initiative: NormalisedInitiative
}

export function IncentiveDrawer({ initiative }: Props) {
  const { address } = useAccount()
  const [amount, setAmount] = useState<number | null>(null)
  const [isDrawerOpen, setIsDrawerOpen] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)

  const { isApproving, handleApprove } = useApproveTokens({
    actor: address,
    spenderAddress: SIGNALS_PROTOCOL,
    tokenAddress: USDC_ADDRESS,
  })

  const hasAllowance = useCheckAllowance({
    actor: address,
    amount,
    spenderAddress: SIGNALS_PROTOCOL,
    tokenAddress: USDC_ADDRESS,
  })

  const resetFormState = () => {
    setAmount(null)
  }

  const handleOnOpenChange = (open: boolean) => {
    if (!open) resetFormState()
    setIsDrawerOpen(open)
  }

  const handleAddIncentive = async () => {
    if (!address) throw new Error('Address not available.')
    if (!amount) {
      return toast('Please enter an amount to lock')
    }

    try {
      const provider = new ethers.providers.Web3Provider(window.ethereum)
      const signer = provider.getSigner()
      const incentivesContract = new ethers.Contract(INCENTIVES, INCENTIVES_ABI, signer)

      const initiativeId = initiative.initiativeId
      const rewardToken = USDC_ADDRESS
      const expiresAt = 0
      const conditions = 0

      const tx = await incentivesContract.addIncentive(
        initiativeId,
        rewardToken,
        ethers.utils.parseUnits(amount.toString(), 6), // Assuming USDC with 6 decimals
        expiresAt,
        conditions,
      )

      await tx.wait()
      toast('Incentive added successfully!')
    } catch (error) {
      toast('Error adding incentive :(')
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
      <Button disabled={!amount} onClick={handleAddIncentive} isLoading={isSubmitting}>
        {isSubmitting ? 'Submitting...' : 'Submit'}
      </Button>
    )
  }

  return (
    <Drawer open={isDrawerOpen} onOpenChange={handleOnOpenChange}>
      <DrawerTrigger asChild>
        <Button variant="outline" size="sm" onClick={() => setIsDrawerOpen(true)}>
          <DollarSign className="mr-1 h-4 w-4" />
          Add incentive
        </Button>
      </DrawerTrigger>
      <DrawerContent className="h-[60%] lg:h-[35%]">
        <div className="p-8 rounded-t-[10px] flex-1 overflow-y-auto flex flex-col gap-4">
          <DrawerHeader>
            <DrawerTitle>Propose a new incentive</DrawerTitle>
            <Alert className="bg-blue-50 dark:bg-neutral-800">
              <CircleAlert style={{ height: 22, width: 22, marginRight: 8 }} />
              <AlertTitle>Please provide the amount you wish to incentivize.</AlertTitle>
              <AlertDescription>Your incentive will be processed accordingly.</AlertDescription>
            </Alert>
          </DrawerHeader>
          <div className="flex items-center">
            <Label className="w-1/5 flex items-center" htmlFor="amount">
              Amount
            </Label>
            <div className="w-4/5 flex flex-col">
              <Input
                id="amount"
                type="number"
                value={amount ?? ''}
                onChange={(e) => setAmount(e.target.value ? Number(e.target.value) : null)}
                min="0"
              />
              {!amount && (
                <Label className="text-red-500 mt-2">Please enter an amount to lock</Label>
              )}
            </div>
          </div>
          <div className="flex items-center">
            <Label className="w-1/5 flex items-center" htmlFor="token">
              Token
            </Label>
            <div className="w-4/5">
              <TokenSelector
                onTokenSelect={(token) => {
                  console.log('selected token!', token)
                }}
              />
            </div>
          </div>
          <div className="flex justify-end mt-8">{resolveAction()}</div>
        </div>
      </DrawerContent>
    </Drawer>
  )
}
