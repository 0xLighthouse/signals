'use client'

import { CircleAlert } from 'lucide-react'
import { toast } from 'sonner'

import { context } from '@/config/web3'
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
import { useAccount } from '@/hooks/useAccount'
import { Card } from '@/components/ui/card'
import { useUnderlying } from '@/contexts/ContractContext'
import { useState } from 'react'
import { useApproveTokens } from '@/hooks/useApproveTokens'
import { Alert, AlertDescription } from '../ui/alert'
import { useWeb3 } from '@/contexts/Web3Provider'

import { usePrivy } from '@privy-io/react-auth'

export function ProvideLiquidityDrawer() {
  const { address } = useAccount()
  const { walletClient, publicClient } = useWeb3()
  const { authenticated, login } = usePrivy()
  const { balance, symbol, fetchContractMetadata } = useUnderlying()

  const [amount, setAmount] = useState(0)
  const [isDrawerOpen, setIsDrawerOpen] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)

  const {
    isApproving,
    hasAllowance,
    handleApprove,
    allowance,
    formattedAllowance,
    handleRevokeAllowance,
  } = useApproveTokens({
    amount,
    actor: address,
    spender: context.contracts.SignalsProtocol.address,
    tokenAddress: context.contracts.BoardUnderlyingToken.address,
    tokenDecimals: 18,
  })

  const resetFormState = () => {
    setAmount(0)
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
    if (!address) {
      setIsDrawerOpen(false)
      return
    }
    if (!open) resetFormState()
    setIsDrawerOpen(open)
  }

  const handleSubmit = async () => {
    if (!address) throw new Error('Address not available.')
    if (!amount) {
      return toast('Please enter an amount to provide')
    }

    try {
      if (!walletClient) {
        toast('Wallet not connected')
        return
      }

      setIsSubmitting(true)
      const nonce = await publicClient.getTransactionCount({ address })

      // Replace with the actual contract function for providing liquidity
      // const { request } = await publicClient.simulateContract({
      //   account: address,
      //   address: context.contracts.SignalsProtocol.address,
      //   abi: context.contracts.SignalsProtocol.abi,
      //   functionName: 'provideLiquidity', // This should be the actual function name
      //   nonce,
      //   args: [BigInt(amount * 1e18)],
      // })

      // console.log('Request:', request)
      // const hash = await walletClient.writeContract(request)

      // const receipt = await publicClient.waitForTransactionReceipt({
      //   hash,
      //   confirmations: 2,
      //   pollingInterval: 2000,
      // })
      // console.log('Receipt:', receipt)
      setIsDrawerOpen(false)
      resetFormState()
      toast('Liquidity provided successfully!')
      fetchContractMetadata()
    } catch (err) {
      console.error(err)
      toast('Error providing liquidity')
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
      <Button disabled={!amount} onClick={handleSubmit} isLoading={isSubmitting}>
        Provide Liquidity
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
        <Button onClick={handleTriggerDrawer}>Provide Liquidity</Button>
      </DrawerTrigger>
      <DrawerContent>
        <div className="overflow-y-auto flex p-8 space-x-8">
          <div className="flex flex-col mx-auto lg:w-3/5">
            <DrawerHeader>
              <DrawerTitle>Provide Liquidity to Pool</DrawerTitle>
              <Alert className="bg-blue-50 dark:bg-neutral-800">
                <CircleAlert style={{ height: 22, width: 22, marginRight: 8 }} />
                <AlertDescription>
                  You have{' '}
                  <strong>
                    {balance} {symbol}
                  </strong>{' '}
                  tokens which can be used to provide liquidity.{' '}
                </AlertDescription>
              </Alert>
            </DrawerHeader>
            <div className="flex flex-col gap-8 mt-6">
              <div className="flex items-center">
                <Label className="w-1/5 flex items-center" htmlFor="amount">
                  Amount
                </Label>
                <div className="w-4/5 flex flex-col">
                  <Input
                    id="amount"
                    type="number"
                    value={amount ?? undefined}
                    defaultValue={0}
                    onChange={(e) => setAmount(e.target.value ? Number(e.target.value) : 0)}
                    min="0"
                  />
                  {!amount && (
                    <Label className="text-red-500 mt-2">Please enter an amount to provide</Label>
                  )}
                  {allowance && (
                    <Label className="text-gray-500 mt-2">
                      Current allowance is: {formattedAllowance}.{' '}
                      <Button
                        variant="link"
                        className="text-gray-500 underline"
                        onClick={handleRevokeAllowance}
                      >
                        Revoke?
                      </Button>
                    </Label>
                  )}
                </div>
              </div>
              <div className="flex items-center">
                <Label className="w-1/5 flex items-center" htmlFor="pool-info">
                  Pool Info
                </Label>
                <div className="w-4/5">
                  <Card className="p-4 dark:bg-neutral-900 border-none shadow-none">
                    <div className="my-2">
                      <p className="line-clamp break-words">
                        By providing liquidity, you'll receive LP tokens representing your share of
                        the pool.
                      </p>
                    </div>
                  </Card>
                </div>
              </div>
            </div>

            <div className="flex justify-end py-8">{resolveAction()}</div>
          </div>
        </div>
      </DrawerContent>
    </Drawer>
  )
}
