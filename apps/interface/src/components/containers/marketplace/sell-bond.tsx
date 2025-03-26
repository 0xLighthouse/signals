'use client'

import { useState } from 'react'
import { Clock, Info, Settings } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Card } from '@/components/ui/card'
import { Label } from '@/components/ui/label'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from '@/components/ui/tooltip'
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from '@/components/ui/collapsible'
import { Input } from '@/components/ui/input'
import { MaturityTimeline } from './maturity-timeline'
import { useAccount } from '@/hooks/useAccount'
import { useWeb3 } from '@/contexts/Web3Provider'
import { toast } from 'sonner'
import { context } from '@/config/web3'
import { DateTime } from 'luxon'

interface Pool {
  id: string
  name: string
  inputToken: string
  outputTokens: string[]
  quote: {
    amount: string
    token: string
  }
  apr: string
  tvl: string
}

interface Bond {
  id: string
  name: string
  maturityDate: string
  issueDate: string
  faceValue: string
  tokenId: number
  price: string
  yield: string
}

export function SellBond() {
  const { address } = useAccount()
  const { walletClient, publicClient } = useWeb3()
  const [selectedNFT, setSelectedNFT] = useState<string>('')
  const [selectedPool, setSelectedPool] = useState<string>('')
  const [selectedOutputToken, setSelectedOutputToken] = useState<string>('')
  const [showAdvanced, setShowAdvanced] = useState(false)
  const [slippage, setSlippage] = useState('0.5')
  const [isSubmitting, setIsSubmitting] = useState(false)

  // Mock data - replace with actual data fetching
  const availableBonds: Bond[] = [
    {
      id: '1',
      name: 'ETH-USDC Bond #1',
      maturityDate: '2024-12-31',
      issueDate: '2024-01-01',
      faceValue: '1000',
      tokenId: 123,
      price: '980.50',
      yield: '5.2%',
    },
    {
      id: '2',
      name: 'ETH-USDC Bond #2',
      maturityDate: '2025-06-30',
      issueDate: '2024-02-15',
      faceValue: '2000',
      tokenId: 124,
      price: '1940.20',
      yield: '4.8%',
    },
  ]

  const availablePools: Pool[] = [
    {
      id: '1',
      name: 'USDC/GOV Pool',
      inputToken: 'GOV',
      outputTokens: ['USDC', 'GOV'],
      quote: {
        amount: '980.50',
        token: 'USDC',
      },
      apr: '5.2%',
      tvl: '$1.2M',
    },
    {
      id: '2',
      name: 'USDT/GOV Pool',
      inputToken: 'GOV',
      outputTokens: ['USDT', 'GOV'],
      quote: {
        amount: '981.20',
        token: 'USDT',
      },
      apr: '5.4%',
      tvl: '$800K',
    },
  ]

  const selectedBond = availableBonds.find((bond) => bond.id === selectedNFT)
  const selectedPoolData = availablePools.find((pool) => pool.id === selectedPool)

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
      const nonce = await publicClient.getTransactionCount({ address })

      const slippageAmount = parseFloat(slippage) / 100
      const minimumAmountOut = selectedPoolData
        ? parseFloat(selectedPoolData.quote.amount) * (1 - slippageAmount)
        : 0

      let functionName = 'sellBondInPool'
      let args = [
        selectedBond.tokenId,
        selectedPool,
        selectedOutputToken === 'mixed' ? 'mixed' : selectedOutputToken,
        String(minimumAmountOut * 1e6),
      ]

      // If mixed token is selected, use different function
      if (selectedOutputToken === 'mixed') {
        functionName = 'sellBondInPoolMixed'
        args = [
          selectedBond.tokenId,
          selectedPool,
          String((minimumAmountOut / 2) * 1e6), // Half for each token
          String((minimumAmountOut / 2) * 1e6),
        ]
      }

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
      setSelectedNFT('')
      setSelectedPool('')
      setSelectedOutputToken('')
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
          {availableBonds.map((bond) => (
            <Card
              key={bond.id}
              className={`p-4 cursor-pointer transition-colors ${
                selectedNFT === bond.id ? 'border-blue-500' : 'hover:border-blue-500/50'
              }`}
              onClick={() => setSelectedNFT(bond.id)}
            >
              <div className="flex flex-col gap-2">
                <h3 className="font-bold">{bond.name}</h3>
                <div className="text-sm text-muted-foreground">
                  <div>Price: {bond.price} USDC</div>
                  <div>Maturity: {bond.maturityDate}</div>
                  <div>Yield: {bond.yield}</div>
                </div>
              </div>
            </Card>
          ))}

          {selectedBond && (
            <Card className="p-4 mt-4">
              <div className="mb-2 flex items-center gap-2">
                <Clock className="h-4 w-4" />
                <h3 className="font-semibold">Time to Maturity</h3>
              </div>
              <MaturityTimeline
                issueDate={DateTime.fromSeconds(Number(selectedBond.issueDate))}
                maturityDate={DateTime.fromSeconds(Number(selectedBond.maturityDate))}
              />
            </Card>
          )}
        </div>

        {/* Column 2: Available Pools */}
        <div className="space-y-6">
          <div className="space-y-4">
            <h3 className="font-semibold">Available Pools</h3>
            {selectedBond ? (
              <>
                {availablePools.map((pool) => (
                  <Card
                    key={pool.id}
                    className={`p-4 cursor-pointer transition-colors ${
                      selectedPool === pool.id ? 'border-blue-500' : 'hover:border-blue-500/50'
                    }`}
                    onClick={() => setSelectedPool(pool.id)}
                  >
                    <div>
                      <h3 className="font-semibold">{pool.name}</h3>
                      <div className="text-sm text-neutral-500 dark:text-neutral-400 mt-1">
                        <div>APR: {pool.apr}</div>
                        <div>TVL: {pool.tvl}</div>
                      </div>
                    </div>
                  </Card>
                ))}
              </>
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
          {selectedBond && selectedPoolData && (
            <div className="space-y-4">
              <h3 className="font-semibold">Output Currency</h3>
              <div className="space-y-2">
                <Label>Receive Token</Label>
                <div className="flex flex-wrap gap-2 mt-1">
                  {selectedPoolData.outputTokens.map((token) => (
                    <Button
                      key={token}
                      variant={selectedOutputToken === token ? 'default' : 'outline'}
                      size="sm"
                      onClick={() => setSelectedOutputToken(token)}
                    >
                      {token}
                    </Button>
                  ))}
                  <Button
                    variant={selectedOutputToken === 'mixed' ? 'default' : 'outline'}
                    size="sm"
                    onClick={() => setSelectedOutputToken('mixed')}
                  >
                    Mixed (50% {selectedPoolData.outputTokens[0]}/{selectedPoolData.outputTokens[1]}
                    )
                  </Button>
                </div>
              </div>
            </div>
          )}

          {/* Quote Details Section */}
          <div className="space-y-4">
            <h3 className="font-semibold">Quote Details</h3>
            {selectedBond && selectedPoolData && selectedOutputToken ? (
              <Card className="p-4">
                <div className="space-y-4">
                  <div>
                    <h3 className="font-semibold">Current Quote</h3>
                    <div className="text-2xl font-bold mt-2">
                      {selectedOutputToken === 'mixed'
                        ? `${parseFloat(selectedPoolData.quote.amount) / 2} ${selectedPoolData.outputTokens[0]} + ${parseFloat(selectedPoolData.quote.amount) / 2} ${selectedPoolData.outputTokens[1]}`
                        : `${selectedPoolData.quote.amount} ${selectedOutputToken}`}
                    </div>
                    <div className="text-sm text-neutral-500 dark:text-neutral-400 mt-1">
                      For your {selectedBond.name}
                    </div>
                  </div>

                  <div className="pt-2 border-t border-neutral-200 dark:border-neutral-800">
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-neutral-500 dark:text-neutral-400">
                        Face Value
                      </span>
                      <span className="font-medium">{selectedBond.faceValue} USDC</span>
                    </div>
                    <div className="flex justify-between items-center mt-2">
                      <span className="text-sm text-neutral-500 dark:text-neutral-400">
                        Discount
                      </span>
                      <span className="font-medium">{selectedBond.yield}</span>
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
      {selectedBond && selectedPoolData && selectedOutputToken && (
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
