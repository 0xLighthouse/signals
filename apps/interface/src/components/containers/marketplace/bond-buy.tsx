'use client'

import { useEffect, useMemo, useState } from 'react'
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
import { useLocksStore } from '@/stores/useBondsStore'
import { usePoolsStore } from '@/stores/usePoolsStore'
import { Pool, Lock } from '@/indexers/api/types'
import { PoolsAvailable } from '../pools/pools-available'
import { context, INDEXER_ENDPOINT } from '@/config/web3'
import { arbitrumSepolia } from 'viem/chains'
import { useUnderlying } from '@/contexts/ContractContext'
import { useApproveNFT } from '@/hooks/useApproveNFT'
import { hexToNumber } from 'viem'
import { BondHookABI } from '../../../../../../packages/abis'
import { OutputToken, resolveOutputTokens } from './utils'

export function BondBuy() {
  const { address } = useAccount()
  const { walletClient, publicClient } = useWeb3()
  const [selectedBond, setSelectedBond] = useState<Lock | undefined>(undefined)
  const [selectedPool, setSelectedPool] = useState<Pool | undefined>(undefined)
  const [selectedOutputToken, setSelectedOutputToken] = useState<OutputToken | undefined>(undefined)
  const [outputTokens, setOutputTokens] = useState<OutputToken[]>([])
  const [quote, setQuote] = useState<number | undefined>(undefined)
  const { formatter: formatterUnderlying, symbol: symbolUnderlying } = useUnderlying()

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

  const fetchQuote = async () => {
    const quote = await fetch(
      `${INDEXER_ENDPOINT}/quote/${arbitrumSepolia.id}/${context.contracts.BondHook.address}/${selectedBond?.tokenId}?type=user-buy`,
    )
    const resp = await quote.json()
    return resp.data.quoteInUnderlying
  }

  // Build quote when output token is selected
  useEffect(() => {
    if (selectedOutputToken) {
      fetchQuote().then((quote) => {
        setQuote(quote)
      })
    }
  }, [selectedOutputToken])

  // Approve to spend the bond
  const approveNFTConfig = useMemo(() => {
    return {
      actor: address,
      tokenId: selectedBond?.tokenId,
      spender: context.contracts.BondHook.address,
      tokenAddress: context.contracts.SignalsProtocol.address,
    }
  }, [selectedBond?.tokenId, address])

  const {
    isApproving: isApprovingNFT,
    isApproved: isApprovedNFT,
    handleApprove: handleApproveNFT,
    handleRevokeAllowance: handleRevokeNFT,
  } = useApproveNFT(approveNFTConfig)

  // Reset form
  const handleReset = () => {
    setSelectedBond(undefined)
    setSelectedPool(undefined)
    setSelectedOutputToken(undefined)
  }

  const handlePurchaseBond = async () => {
    console.log('handlePurchaseBond')
    if (!address) {
      toast('Please connect a wallet')
      return
    }
    if (!isApprovedNFT) {
      toast('NFT not approved')
      return
    }
    if (!quote) {
      toast('No quote found')
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

      // Appove the SignalsBoard to spend the underlying token
      const nonce = await publicClient.getTransactionCount({ address })
      const fee = hexToNumber('0x800000') // Dynamic fee flag
      const tickSpacing = 60

      // TODO: This will be updated with poolId
      const poolKey = {
        currency0: selectedPool.currency0.address,
        currency1: selectedPool.currency1.address,
        fee, // TODO: Fetch fee from pool
        tickSpacing,
        hooks: context.contracts.BondHook.address,
      }

      const swapData = {
        poolKey,
        tokenId: selectedBond.tokenId,
        bondPriceLimit: BigInt(quote),
        swapPriceLimit: BigInt(0), // No swaps
        desiredCurrency: 2, // we receive mixed currencies
      }

      const { request } = await publicClient.simulateContract({
        account: address,
        address: context.contracts.BondHook.address,
        abi: BondHookABI,
        functionName: 'swapBond',
        nonce,
        args: [swapData],
      })

      const hash = await walletClient.writeContract(request)

      const receipt = await publicClient.waitForTransactionReceipt({
        hash,
        confirmations: 2,
        pollingInterval: 2000,
      })

      console.log('Receipt:', receipt)
      toast('Bond purchased successfully!')

      // Reset form
      // handleReset()
    } catch (error) {
      console.error(error)
      // @ts-ignore
      if (error?.message?.includes('User rejected the request')) {
        toast('User rejected the request')
      } else {
        toast('Error purchasing bond :(')
      }
    } finally {
      setIsSubmitting(false)
    }
  }

  const selectAction = (tokenId: bigint) => {
    console.log('tokenId', tokenId)
    console.log('isApprovedNFT', isApprovedNFT)
    if (!isApprovedNFT) {
      return (
        <Button
          className="w-full"
          onClick={() => {
            handleApproveNFT(tokenId)
          }}
          disabled={isApprovingNFT}
          isLoading={isSubmitting}
        >
          {isSubmitting ? 'Processing...' : 'Approve NFT'}
        </Button>
      )
    }

    return (
      <Button
        className="w-full"
        onClick={handlePurchaseBond}
        disabled={isSubmitting}
        isLoading={isSubmitting}
      >
        {isSubmitting ? 'Processing...' : 'Purchase Bond'}
      </Button>
    )
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
                    <div className="text-2xl font-bold mt-2">{formatterUnderlying(quote)}</div>
                    <div className="text-sm text-neutral-500 dark:text-neutral-400 mt-1">
                      For your NFT#{selectedBond.tokenId}
                    </div>
                  </div>

                  <div className="pt-2 border-t border-neutral-200 dark:border-neutral-800">
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-neutral-500 dark:text-neutral-400">
                        Face Value
                      </span>
                      <span className="font-medium">
                        {formatterUnderlying(Number(selectedBond.metadata.nominalValue))}{' '}
                        {symbolUnderlying}
                      </span>
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
      {selectedBond && selectedPool && selectedOutputToken && quote && (
        <div className="mt-8">{selectAction(selectedBond.tokenId)}</div>
      )}
    </div>
  )
}
