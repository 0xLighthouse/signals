'use client'

import { CircleAlert, Eclipse } from 'lucide-react'
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
import { useEffect, useState } from 'react'
import { Alert, AlertDescription, AlertTitle } from '../ui/alert'
import { NormalisedInitiative } from '@/app/api/initiatives/route'
import { TokenSelector } from '../token-selector'
import {
  INCENTIVES,
  INCENTIVES_ABI,
  readClient,
  SIGNALS_PROTOCOL,
  USDC_ADDRESS,
} from '@/config/web3'
import { useApproveTokens } from '@/hooks/useApproveTokens'
import { useIncentives } from '@/contexts/IncentivesContext'
import { useAccount } from '@/hooks/useAccount'
import { createWalletClient, custom } from 'viem'
import { arbitrumSepolia, hardhat } from 'viem/chains'

interface Props {
  initiative: NormalisedInitiative
}

export function IncentiveDrawer({ initiative }: Props) {
  const { address } = useAccount()
  const { address: incentivesAddress, version, receivers, allocations } = useIncentives()
  const [amount, setAmount] = useState<number | null>(null)
  const [shares, setShares] = useState<number[]>([])
  const [isDrawerOpen, setIsDrawerOpen] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)

  const { isApproving, hasAllowance, handleApprove } = useApproveTokens({
    amount,
    actor: address,
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
      setIsSubmitting(true)
      const nonce = await readClient.getTransactionCount({ address })

      const signer = createWalletClient({
        chain: process.env.NEXT_PUBLIC_SIGNALS_ENV === 'dev' ? hardhat : arbitrumSepolia,
        transport: custom(window.ethereum),
      })

      // Define the token address and other required parameters
      const tokenAddress = USDC_ADDRESS // Replace with the selected token if dynamic
      const expiresAt = 0
      const terms = 0

      const { request } = await readClient.simulateContract({
        account: address,
        address: INCENTIVES,
        abi: INCENTIVES_ABI,
        functionName: 'addIncentive',
        nonce,
        args: [
          initiative.initiativeId,
          tokenAddress,
          ethers.utils.parseUnits(amount.toString(), 18),
          expiresAt,
          terms,
        ],
      })

      const hash = await signer.writeContract(request)

      const receipt = await readClient.waitForTransactionReceipt({
        hash,
        confirmations: 2,
        pollingInterval: 2000,
      })
      console.log('Receipt:', receipt)
      setIsDrawerOpen(false)
      resetFormState()
      toast('Incentive added successfully!')
    } catch (error) {
      console.error(error)
      // @ts-ignore
      if (error?.message?.includes('User rejected the request')) {
        toast('User rejected the request')
      } else {
        toast('Error submitting incentive :(')
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
      <Button disabled={!amount} onClick={handleAddIncentive} isLoading={isSubmitting}>
        {isSubmitting ? 'Submitting...' : 'Submit'}
      </Button>
    )
  }

  useEffect(() => {
    if (allocations && amount) {
      const shares = []
      for (const allocation of allocations) {
        shares.push((amount * Number(allocation)) / 100)
      }
      setShares(shares)
    }
  }, [allocations, amount])

  return (
    <Drawer open={isDrawerOpen} onOpenChange={handleOnOpenChange}>
      <DrawerTrigger asChild>
        <Button
          variant="outline"
          full
          size="md"
          onClick={() => setIsDrawerOpen(true)}
          className="flex flex-col items-center min-w-[80px]"
        >
          <Eclipse className="h-4 w-4" />
          <span className="text-xs mt-1">{initiative.weight.toFixed(0)}</span>
        </Button>
      </DrawerTrigger>
      <DrawerContent>
        <div className="p-8 rounded-t-[10px] flex-1 overflow-y-auto flex flex-col gap-4">
          <DrawerHeader>
            <DrawerTitle>Provide incentives</DrawerTitle>
            <Alert className="bg-blue-50 dark:bg-neutral-800">
              <CircleAlert style={{ height: 22, width: 22, marginRight: 8 }} />
              <AlertTitle>
                Select a token you would like to contibute towards this initiative.
              </AlertTitle>
              <AlertDescription>
                Any USDC you contribute will only be used once initiative is accepted.
              </AlertDescription>
              <div>
                Based on this the boards current configuration. Your USDC incentive will be
                distributed accordingly.
                <ul>
                  <li>
                    <strong>Signals Protocol: {Number(allocations?.[0])}% </strong>
                  </li>
                  <li>
                    <strong>Voter Rewards: {Number(allocations?.[1])}% </strong>
                  </li>
                  <li>
                    <strong>Treasury: {Number(allocations?.[2])}% </strong>
                  </li>
                </ul>
              </div>
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
          <div>
            Your USDC incentive will be distributed accordingly.
            <ul>
              <li>
                Signals Protocol: ({receivers?.[0]}): {Number(shares?.[0])}
              </li>
              <li>
                Voter Rewards: ({receivers?.[1]}): {Number(shares?.[1])}
              </li>
              <li>
                Treasury: ({receivers?.[2]}): {Number(shares?.[2])}
              </li>
            </ul>
          </div>
          <div className="flex justify-end mt-8">{resolveAction()}</div>
        </div>
      </DrawerContent>
    </Drawer>
  )
}
