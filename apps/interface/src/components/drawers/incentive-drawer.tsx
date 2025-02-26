'use client'

import { ArrowRight, CircleAlert } from 'lucide-react'
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
import { INCENTIVES, INCENTIVES_ABI, readClient, USDC_ADDRESS } from '@/config/web3'
import { useApproveTokens } from '@/hooks/useApproveTokens'
import { useIncentives } from '@/contexts/IncentivesContext'
import { useAccount } from '@/hooks/useAccount'
import { createWalletClient, custom } from 'viem'
import { arbitrumSepolia, hardhat } from 'viem/chains'
import { UsdcIcon } from '../icons/usdc'
import { useRewardsStore } from '@/stores/useRewardsStore'
import { cn } from '@/lib/utils'
import { usePrivyModal } from '@/contexts/PrivyModalContext'
import { usePrivy } from '@privy-io/react-auth'

interface Props {
  initiative: NormalisedInitiative
}

export function IncentiveDrawer({ initiative }: Props) {
  const { address } = useAccount()
  const { setOpen } = usePrivyModal()
  const { authenticated, login } = usePrivy()
  const { allocations } = useIncentives()
  const { fetch: fetchUSDC } = useRewardsStore()
  const [amount, setAmount] = useState<number | null>(null)
  const [shares, setShares] = useState<number[]>([])
  const [isDrawerOpen, setIsDrawerOpen] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)

  const { isApproving, hasAllowance, handleApprove } = useApproveTokens({
    amount,
    actor: address,
    spenderAddress: INCENTIVES,
    tokenAddress: USDC_ADDRESS,
    decimals: 6,
  })

  const resetFormState = () => {
    setAmount(null)
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
        args: [initiative.initiativeId, tokenAddress, amount * 1e6, expiresAt, terms],
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
      fetchUSDC(address)
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
    if (allocations) {
      const shares = []
      if (amount) {
        for (const allocation of allocations) {
          shares.push((amount * Number(allocation)) / 100)
        }
      } else {
        // Reset shares if amount is zero or cleared
        shares.length = 0
      }
      setShares(shares)
    }
  }, [allocations, amount])

  return (
    <Drawer
      dismissible={!isSubmitting && !isApproving}
      open={isDrawerOpen}
      onOpenChange={handleOnOpenChange}
    >
      <DrawerTrigger asChild>
        <Button
          variant="outline"
          full
          size="md"
          onClick={handleTriggerDrawer}
          className="flex flex-col items-center min-w-[80px]"
        >
          <UsdcIcon className="h-5 w-5" />
          <span className="text-xs mt-1">{initiative.rewards.toFixed(0)}</span>
        </Button>
      </DrawerTrigger>
      <DrawerContent>
        <div className="p-8 flex-1 overflow-y-auto flex flex-col gap-4">
          <DrawerHeader>
            <DrawerTitle>Contribute incentives</DrawerTitle>
            <Alert className="bg-blue-50 dark:bg-neutral-800">
              <CircleAlert style={{ height: 22, width: 22, marginRight: 8 }} />
              <AlertTitle>
                Contribute incentives to help this initiative gain support. Incentives will be
                distributed based on your communities configured distribution schedule outlined
                below.
              </AlertTitle>
              <AlertDescription>
                Any USDC you contribute will only be used once initiative is accepted.
              </AlertDescription>
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
                <Label className="text-red-500 mt-2">Please enter an amount to contribute</Label>
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
          <div className="flex items-center">
            <Label className="w-1/5 flex items-center" htmlFor="token">
              Allocations
            </Label>
            <div className="w-4/5 text-xs">
              <div className="flex flex-row gap-2">
                {amount != null && (
                  <>
                    <div className="flex items-center gap-2">{amount} USDC</div>
                    <div className="flex items-center gap-2">
                      <ArrowRight className="w-3 h-3" />
                    </div>
                  </>
                )}
                <div className="flex flex-col gap-2">
                  {allocations?.map((allocation, index) => {
                    const shareValue = shares?.[index] ? `- ${Number(shares[index])} USDC` : ''
                    return (
                      <span className="text-xs" key={allocation}>
                        {Number(allocation)}% {shareValue}
                      </span>
                    )
                  })}
                </div>
                <div className="flex flex-col gap-2">
                  <span className="text-xs">Protocol fee</span>
                  <span className="text-xs">Distributed to supporters</span>
                  <span className="text-xs">Distributed to treasury</span>
                </div>
              </div>
            </div>
          </div>

          <div className="flex justify-end mt-8">{resolveAction()}</div>
        </div>
      </DrawerContent>
    </Drawer>
  )
}
