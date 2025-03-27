'use client'

import { useEffect, useState } from 'react'
import { Info, Settings } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Card } from '@/components/ui/card'
import { Label } from '@/components/ui/label'
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from '@/components/ui/tooltip'
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from '@/components/ui/collapsible'
import { Input } from '@/components/ui/input'
import { useAccount } from '@/hooks/useAccount'
import { useWeb3 } from '@/contexts/Web3Provider'
import { toast } from 'sonner'
import { useLocksStore } from '@/stores/useLocksStore'
import { usePoolsStore } from '@/stores/usePoolsStore'
import { Pool, Lock } from '@/indexers/api/types'
import { PoolsAvailable } from '../pools/pools-available'

// interface Pool {
//   id: string
//   name: string
//   inputToken: string
//   outputTokens: string[]
//   quote: {
//     amount: string
//     token: string
//   }
//   apr: string
//   tvl: string
// }

// interface IBond {
//   id: string
//   name: string
//   maturityDate: string
//   issueDate: string
//   faceValue: string
//   tokenId: number
//   price: string
//   yield: string
// }

const resolveOutputTokens = (pool: Pool) => {
  const outputTokens: OutputToken[] = []
  outputTokens.push({
    key: 'currency0',
    label: `${pool.currency0.symbol}`,
  })
  outputTokens.push({
    key: 'currency1',
    label: `${pool.currency1.symbol}`,
  })
  outputTokens.push({
    key: 'mixed',
    label: `Mixed (50% ${pool.currency0.symbol}/${pool.currency1.symbol})`,
  })
  return outputTokens
}

type OutputTokenKey = 'mixed' | 'currency0' | 'currency1'

interface OutputToken {
  key: OutputTokenKey
  label: string
}

export function SellBond() {
  const { address } = useAccount()
  const { walletClient } = useWeb3()
  const [selectedBond, setSelectedBond] = useState<Lock | undefined>(undefined)
  const [selectedPool, setSelectedPool] = useState<Pool | undefined>(undefined)
  const [selectedOutputToken, setSelectedOutputToken] = useState<OutputToken | undefined>(undefined)
  const [outputTokens, setOutputTokens] = useState<OutputToken[]>([])

  const [showAdvanced, setShowAdvanced] = useState(false)
  const [slippage, setSlippage] = useState('0.5')
  const [isSubmitting, setIsSubmitting] = useState(false)

  const allBonds = useLocksStore((state) => state.locks)
  const allPools = usePoolsStore((state) => state.pools)

  // Fetch pools if they are not initialized
  useEffect(() => {
    if (allPools.length === 0 && !usePoolsStore.getState().isInitialized) {
      usePoolsStore.getState().fetchPools()
    }
  }, [allPools])

  // Compute output tokens based on selected pool
  useEffect(() => {
    if (selectedPool) {
      setOutputTokens(resolveOutputTokens(selectedPool))
    }
  }, [selectedPool])

  // Build quote when output token is selected
  useEffect(() => {
    if (selectedOutputToken) {
      console.log('----- TODO: BUILD QUOTE -----')
    }
  }, [selectedOutputToken])

  // Reset form
  const handleReset = () => {
    setSelectedBond(undefined)
    setSelectedPool(undefined)
    setSelectedOutputToken(undefined)
  }

  const handleSellBond = async () => {
    if (!address) {
      toast('Please connect a wallet')
      return
    }

    if (!selectedBond || !selectedPool || !selectedOutputToken) {
      toast('Please select all required options')
      return
    }

    try {
      if (!walletClient) {
        toast('Wallet not connected')
        return
      }

      setIsSubmitting(true)
      // const nonce = await publicClient.getTransactionCount({ address })

      // const slippageAmount = parseFloat(slippage) / 100
      // const minimumAmountOut = selectedPoolData
      //   ? parseFloat(selectedPoolData.quote.amount) * (1 - slippageAmount)
      //   : 0

      // let functionName = 'sellBondInPool'
      // let args = [
      //   selectedBond.tokenId,
      //   selectedPool,
      //   selectedOutputToken === 'mixed' ? 'mixed' : selectedOutputToken,
      //   String(minimumAmountOut * 1e6),
      // ]

      // // If mixed token is selected, use different function
      // if (selectedOutputToken === 'mixed') {
      //   functionName = 'sellBondInPoolMixed'
      //   args = [
      //     selectedBond.tokenId,
      //     selectedPool,
      //     String((minimumAmountOut / 2) * 1e6), // Half for each token
      //     String((minimumAmountOut / 2) * 1e6),
      //   ]
      // }

      // const { request } = await publicClient.simulateContract({
      //   account: address,
      //   address: context.contracts.SignalsMarketplace.address,
      //   abi: context.contracts.SignalsMarketplace.abi,
      //   functionName,
      //   nonce,
      //   // @ts-ignore
      //   args,
      // })

      // const hash = await walletClient.writeContract(request)

      // const receipt = await publicClient.waitForTransactionReceipt({
      //   hash,
      //   confirmations: 2,
      //   pollingInterval: 2000,
      // })

      // console.log('Receipt:', receipt)
      // toast('Bond sold successfully!')

      // Reset form
      handleReset()
    } catch (error) {
      console.error(error)
      // @ts-ignore
      if (error?.message?.includes('User rejected the request')) {
        toast('User rejected the request')
      } else {
        toast('Error selling bond :(')
      }
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <div className="w-full">
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* Column 1: Currently Selected Bond */}
        <div className="space-y-4">
          <h3 className="font-semibold">Your Bond</h3>
          {allBonds.map((bond) => (
            <Card
              key={bond.tokenId}
              className={`p-4 cursor-pointer transition-colors ${
                selectedBond?.tokenId === bond.tokenId
                  ? 'border-blue-500'
                  : 'hover:border-blue-500/50'
              }`}
              onClick={() => setSelectedBond(bond)}
            >
              <div className="flex flex-col gap-2">
                <h3 className="font-bold">{bond.initiative.title}</h3>
                <div className="text-sm text-muted-foreground">
                  <div>Tokens: {bond.metadata.nominalValue} USDC</div>
                  <div>Maturity: {bond.metadata.expires}</div>
                </div>
              </div>
            </Card>
          ))}
        </div>

        {/* Column 2: Available Pools */}
        <div className="space-y-6">
          <div className="space-y-4">
            <h3 className="font-semibold">Available Pools</h3>
            {selectedBond ? (
              <PoolsAvailable
                pools={allPools}
                selectedPoolId={selectedPool?.poolId}
                handleOnClick={(poolId: string) => {
                  setSelectedPool(allPools.find((pool) => pool.poolId === poolId))
                }}
              />
            ) : (
              <div className="text-sm text-neutral-500 dark:text-neutral-400 p-4">
                Select a bond to view available pools
              </div>
            )}
          </div>
        </div>

        {/* Column 3: Output Currency and Quote Information */}
        <div className="space-y-6">
          {/* Output Currency Section */}
          {selectedBond && selectedPool && outputTokens.length > 0 && (
            <div className="space-y-4">
              <h3 className="font-semibold">Output Currency</h3>
              <div className="space-y-2">
                <Label>Receive Token</Label>
                <div className="flex flex-wrap gap-2 mt-1">
                  {outputTokens.map((token) => (
                    <Button
                      key={token.key}
                      variant={selectedOutputToken?.key === token.key ? 'default' : 'outline'}
                      size="sm"
                      onClick={() => setSelectedOutputToken(token)}
                    >
                      {token.label}
                    </Button>
                  ))}
                </div>
              </div>
            </div>
          )}

          {/* Quote Details Section */}
          <div className="space-y-4">
            <h3 className="font-semibold">Quote Details</h3>
            {selectedBond && selectedPool && selectedOutputToken ? (
              <Card className="p-4">
                <div className="space-y-4">
                  <div>
                    <h3 className="font-semibold">Current Quote</h3>
                    <div className="text-2xl font-bold mt-2">TODO: BUILD QUOTE</div>
                    <div className="text-sm text-neutral-500 dark:text-neutral-400 mt-1">
                      For your NFT#{selectedBond.tokenId}
                    </div>
                  </div>

                  <div className="pt-2 border-t border-neutral-200 dark:border-neutral-800">
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-neutral-500 dark:text-neutral-400">
                        Face Value
                      </span>
                      <span className="font-medium">{selectedBond.metadata.nominalValue} USDC</span>
                    </div>
                    <div className="flex justify-between items-center mt-2">
                      <span className="text-sm text-neutral-500 dark:text-neutral-400">
                        Discount
                      </span>
                      <span className="font-medium">YEILD 69</span>
                    </div>
                  </div>

                  {/* Advanced Settings */}
                  <div className="pt-4 border-t border-neutral-200 dark:border-neutral-800 mt-4">
                    <Collapsible
                      open={showAdvanced}
                      onOpenChange={setShowAdvanced}
                      className="space-y-2"
                    >
                      <CollapsibleTrigger asChild>
                        <Button variant="ghost" className="flex items-center gap-2 px-0">
                          <Settings className="h-4 w-4" />
                          Advanced Settings
                        </Button>
                      </CollapsibleTrigger>
                      <CollapsibleContent className="space-y-4">
                        <div className="space-y-2">
                          <div className="flex items-center gap-2">
                            <Label>Slippage Tolerance (%)</Label>
                            <TooltipProvider>
                              <Tooltip>
                                <TooltipTrigger>
                                  <Info className="h-4 w-4" />
                                </TooltipTrigger>
                                <TooltipContent>
                                  Your transaction will revert if the price changes unfavorably by
                                  more than this percentage.
                                </TooltipContent>
                              </Tooltip>
                            </TooltipProvider>
                          </div>
                          <Input
                            type="number"
                            value={slippage}
                            onChange={(e) => setSlippage(e.target.value)}
                            className="w-full"
                          />
                        </div>
                      </CollapsibleContent>
                    </Collapsible>
                  </div>
                </div>
              </Card>
            ) : (
              <div className="text-sm text-neutral-500 dark:text-neutral-400 p-4">
                Select an output token to view quote details
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Action Button */}
      {selectedBond && selectedPool && selectedOutputToken && (
        <div className="mt-8">
          <Button
            className="w-full"
            onClick={handleSellBond}
            disabled={isSubmitting}
            isLoading={isSubmitting}
          >
            {isSubmitting ? 'Processing...' : 'Sell Bond'}
          </Button>
        </div>
      )}
    </div>
  )
}
