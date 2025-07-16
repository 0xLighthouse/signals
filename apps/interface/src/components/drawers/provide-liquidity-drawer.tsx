'use client'

import { CircleAlert, ArrowDownUp, AlertCircle, Info, RefreshCw } from 'lucide-react'
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
import { useAccount } from '@/hooks/useAccount'
import { Card } from '@/components/ui/card'
import { useUnderlying } from '@/contexts/ContractContext'
import { useEffect, useMemo, useState } from 'react'
import { useApproveTokens } from '@/hooks/useApproveTokens'
import { Alert, AlertDescription, AlertTitle } from '../ui/alert'
import { useWeb3 } from '@/contexts/Web3Provider'
import { usePrivy } from '@privy-io/react-auth'
import { normaliseNumber } from '@/lib/utils'
import { usePoolsStore } from '@/stores/usePoolsStore'
import { Pool } from '@/indexers/api/types'
import { PoolsAvailable } from '../containers/pools/pools-available'
import { calculateLiquidity, CurrencyType, toUniswapPool } from '@/lib/uniswap'

export function ProvideLiquidityDrawer({ poolId }: { poolId?: string }) {
  const { address } = useAccount()
  const { walletClient, publicClient } = useWeb3()
  const { authenticated, login } = usePrivy()
  const { balance, symbol, formatter } = useUnderlying()

  const pools = usePoolsStore((state) => state.pools)

  const [amountA, setAmountA] = useState<number>(0)
  const [amountB, setAmountB] = useState<number>(0)
  const [liquidityDelta, setLiquidityDelta] = useState<number>(0)

  const [isDrawerOpen, setIsDrawerOpen] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [selectedPoolId, setSelectedPoolId] = useState<string>('')
  const [selectedPoolData, setSelectedPoolData] = useState<Pool | undefined>(undefined)
  const [inputFocused, setInputFocused] = useState<CurrencyType | null>(null)
  const [inputError, setInputError] = useState<string | null>(null)
  const [lockRatio, setLockRatio] = useState(true)

  useEffect(() => {
    if (selectedPoolId) {
      setSelectedPoolData(pools.find((pool) => pool.poolId.toString() === selectedPoolId))
    }
  }, [selectedPoolId])

  // Track if inputs are swapped to show correct token and balance information
  const [isInputsSwapped, setIsInputsSwapped] = useState(false)

  // Get the correct token details based on the current swap state
  const getCurrency0 = () =>
    isInputsSwapped ? selectedPoolData?.currency1.symbol : selectedPoolData?.currency0.symbol
  const getCurrency1 = () =>
    isInputsSwapped ? selectedPoolData?.currency0.symbol : selectedPoolData?.currency1.symbol

  // Get the correct balance for each input field
  const getCurrency0Balance = () => {
    if (!selectedPoolData) return '0'
    return isInputsSwapped ? '0.00' : normaliseNumber(formatter(balance)) || '0'
  }

  const getCurrency1Balance = () => {
    if (!selectedPoolData) return '0'
    return isInputsSwapped ? normaliseNumber(formatter(balance)) || '0' : '0.00'
  }

  /**
   * Currency 0 Approval
   */
  const approveTokenConfig = useMemo(
    () => ({
      amount: amountA,
      actor: address,
      spender: context.contracts.BondHook.address,
      tokenAddress: selectedPoolData?.currency0.address,
      tokenDecimals: selectedPoolData?.currency0.decimals ?? 18,
    }),
    [amountA, address, selectedPoolData],
  )
  const {
    isApproving: isApprovingCurrency0,
    hasAllowance: hasCurrency0Allowance,
    handleApprove: handleApproveCurrency0,
    allowance: currency0Allowance,
    formattedAllowance: formattedCurrency0Allowance,
    handleRevokeAllowance: handleRevokeCurrency0Allowance,
  } = useApproveTokens(approveTokenConfig)

  /**
   * Currency 1 Approval
   */
  const approveTokenConfig1 = useMemo(
    () => ({
      amount: amountB,
      actor: address,
      spender: context.contracts.BondHook.address,
      tokenAddress: selectedPoolData?.currency1.address,
      tokenDecimals: selectedPoolData?.currency1.decimals ?? 18,
    }),
    [amountB, address, selectedPoolData],
  )
  const {
    isApproving: isApprovingCurrency1,
    hasAllowance: hasCurrency1Allowance,
    handleApprove: handleApproveCurrency1,
    allowance: currency1Allowance,
    formattedAllowance: formattedCurrency1Allowance,
    handleRevokeAllowance: handleRevokeCurrency1Allowance,
  } = useApproveTokens(approveTokenConfig1)

  const resetFormState = () => {
    setAmountA(0)
    setAmountB(0)
    setSelectedPoolId('')
    setInputError(null)
    setIsInputsSwapped(false) // Reset to original order
    setLockRatio(true) // Reset to locked ratio by default
  }

  const handleMaxAmount = (input: CurrencyType) => {
    const maxAmount = Number.parseFloat(normaliseNumber(formatter(balance)))
    if (input === 'Currency0') {
      if (isInputsSwapped) {
        // In swapped mode, token B is in position A
        // Mock for now, would use actual B balance
        setAmountA(0)
        validateInput(0, 'Currency0')
      } else {
        // Normal mode, token A is in position A
        setAmountA(maxAmount)
        validateInput(maxAmount, 'Currency0')
      }
    } else {
      if (isInputsSwapped) {
        // In swapped mode, token A is in position B
        setAmountB(maxAmount)
        validateInput(maxAmount, 'Currency1')
      } else {
        // Normal mode, token B is in position B
        // Mock for now, would use actual B balance
        setAmountB(0)
        validateInput(0, 'Currency1')
      }
    }
  }

  const validateInput = (value: number, input: CurrencyType) => {
    const userBalance = Number.parseFloat(normaliseNumber(formatter(balance)))

    if (input === 'Currency0') {
      if (!isInputsSwapped) {
        // Token A is in position A
        if (value > userBalance) {
          setInputError(`Insufficient ${symbol} balance`)
          return false
        }
      } else {
        // Token B is in position A (swapped)
        // Mock validation for now
        // In reality, would check the user's token B balance
      }
    } else {
      if (isInputsSwapped) {
        // Token A is in position B (swapped)
        if (value > userBalance) {
          setInputError(`Insufficient ${symbol} balance`)
          return false
        }
      } else {
        // Token B is in position B
        // Mock validation for now
        // In reality, would check the user's token B balance
      }
    }
    setInputError(null)
    return true
  }

  const swapInputs = () => {
    // Swap the input values
    const tempA = amountA
    setAmountA(amountB)
    setAmountB(tempA)

    // Toggle the swapped state to update token info display
    setIsInputsSwapped(!isInputsSwapped)

    // If there was an error on one of the inputs, re-validate after swapping
    if (inputError) {
      setTimeout(() => {
        validateInput(amountB, 'Currency0')
        validateInput(tempA, 'Currency1')
      }, 0)
    }
  }

  const handleAmountChange = async (value: number, input: CurrencyType) => {
    if (!selectedPoolData) {
      console.error('No pool selected')
      return
    }
    const { pool } = await toUniswapPool(selectedPoolData)

    const { amountA, amountB, liquidityDelta } = calculateLiquidity({
      pool,
      amount: value,
      sourceCurrency: input,
      range: {
        tickLower: -887220, // Min usable tick for spacing of 60
        tickUpper: 887220, // Max usable tick for spacing of 60
      },
    })

    if (input === 'Currency0') {
      setAmountA(value)
      setAmountB(amountB)
    } else {
      setAmountA(amountA)
      setAmountB(value)
    }

    setLiquidityDelta(liquidityDelta)
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

  const handleAddLiquidity = async () => {
    if (!address) throw new Error('Address not available.')
    if (!amountA || !amountB || !selectedPoolId) {
      return toast('Please enter amounts and select a pool')
    }

    if (!selectedPoolData) {
      console.error('No pool selected')
      return
    }

    if (!walletClient) {
      toast('Wallet not connected')
      return
    }

    try {
      // setIsSubmitting(true)

      console.log('----- ADDING LIQUIDITY -----')
      const nonce = await publicClient.getTransactionCount({ address })
      const liquidityData = {
        poolKey: {
          currency0: selectedPoolData.currency0.address,
          currency1: selectedPoolData.currency1.address,
          fee: 8388608,
          tickSpacing: 60,
          hooks: context.contracts.BondHook.address,
        },
        liquidityDelta: BigInt(liquidityDelta),
        swapPriceLimit: 0n, // or your desired price limit
        desiredCurrency: 2, // enum value, 0 or 1 depending on desired currency
      }

      console.log('nonce', nonce)

      // Replace with the actual contract function for providing liquidity
      const { request } = await publicClient.simulateContract({
        account: address,
        address: context.contracts.BondHook.address,
        abi: context.contracts.BondHook.abi,
        functionName: 'modifyLiquidity',
        nonce,
        args: [liquidityData],
      })

      console.log('Request:', request)
      const hash = await walletClient.writeContract(request)

      const receipt = await publicClient.waitForTransactionReceipt({
        hash,
        confirmations: 2,
        pollingInterval: 2000,
      })
      console.log('Receipt:', receipt)

      // setIsDrawerOpen(false)
      // resetFormState()
      // toast('Liquidity provided successfully!')
      // fetchContractMetadata()
    } catch (err) {
      console.trace(err)
      toast('Error providing liquidity')
      setIsSubmitting(false)
    }
  }

  const resolveAction = () => {
    if (!hasCurrency0Allowance && amountA) {
      return (
        <Button
          onClick={() => handleApproveCurrency0(amountA)}
          isLoading={isApprovingCurrency0}
          className="w-full"
        >
          {isApprovingCurrency0 ? 'Confirming approval...' : `Approve ${getCurrency0()}`}
        </Button>
      )
    }

    if (!hasCurrency1Allowance && amountB) {
      return (
        <Button
          onClick={() => handleApproveCurrency1(amountB)}
          isLoading={isApprovingCurrency1}
          className="w-full"
        >
          {isApprovingCurrency1 ? 'Confirming approval...' : `Approve ${getCurrency1()}`}
        </Button>
      )
    }

    return (
      <Button
        disabled={!amountA || !amountB || !selectedPoolId || !!inputError}
        onClick={handleAddLiquidity}
        isLoading={isSubmitting}
        className="w-full"
      >
        {inputError ? 'Insufficient Balance' : 'Provide Liquidity'}
      </Button>
    )
  }

  return (
    <Drawer
      dismissible={!isSubmitting && !isApprovingCurrency0 && !isApprovingCurrency1}
      open={isDrawerOpen}
      onOpenChange={handleOnOpenChange}
    >
      <DrawerTrigger asChild>
        <Button onClick={handleTriggerDrawer}>Provide Liquidity</Button>
      </DrawerTrigger>
      <DrawerContent className="p-0">
        <div className="flex-1 overflow-y-auto">
          <DrawerHeader className="p-8 pb-2">
            <DrawerTitle>Provide Liquidity</DrawerTitle>
            <Alert className="bg-blue-50 dark:bg-neutral-800 mt-4">
              <CircleAlert style={{ height: 22, width: 22, marginRight: 8 }} />
              <AlertTitle>Add liquidity to a pool</AlertTitle>
              <AlertDescription>
                Provide liquidity to earn fees and participate in governance.
              </AlertDescription>
            </Alert>
          </DrawerHeader>
          <div className="p-8 pt-2">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              {/* Column 1: Available Pools and User Balances */}
              <div className="space-y-4">
                <h3 className="font-semibold">Available Pools</h3>
                <PoolsAvailable
                  pools={pools}
                  selectedPoolId={selectedPoolId}
                  handleOnClick={(poolId: string) => {
                    setSelectedPoolId(poolId)
                  }}
                />

                {/* User Balances */}
                <Card className="p-4 mt-4">
                  <h3 className="font-semibold mb-2">Your Balances</h3>
                  <div className="space-y-2">
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-neutral-500 dark:text-neutral-400">
                        {symbol}
                      </span>
                      <span className="font-medium">
                        {normaliseNumber(formatter(balance)) || '-'}
                      </span>
                    </div>
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-neutral-500 dark:text-neutral-400">USDC</span>
                      <span className="font-medium">0.00</span>
                    </div>
                  </div>
                </Card>
              </div>

              {/* Column 2: Deposit Amounts */}
              <div className="space-y-4">
                <h3 className="font-semibold">Deposit Amounts</h3>
                {selectedPoolData ? (
                  <Card className="p-4">
                    <div className="space-y-4">
                      {/* Token inputs */}
                      <div className="flex flex-col space-y-4">
                        {/* Input A */}
                        <div className="rounded-lg border border-input p-3">
                          <div className="flex justify-between items-center mb-2">
                            <div className="flex items-center gap-2">
                              <div className="bg-primary/10 rounded-full p-1">
                                <div className="bg-primary h-4 w-4 rounded-full flex items-center justify-center text-white text-[10px] font-bold">
                                  {getCurrency0()}
                                </div>
                              </div>
                              <span className="font-medium">{getCurrency0()}</span>
                            </div>
                            <div className="text-xs text-muted-foreground">
                              Balance: {getCurrency0Balance()}
                              <Button
                                variant="link"
                                className="text-xs h-auto p-0 ml-1 text-blue-500"
                                onClick={() => handleMaxAmount('Currency0')}
                              >
                                MAX
                              </Button>
                            </div>
                          </div>
                          <div className="flex items-center">
                            <Input
                              id="amountA"
                              type="number"
                              value={amountA ?? undefined}
                              onChange={(e) => {
                                handleAmountChange(
                                  e.target.value ? Number(e.target.value) : 0,
                                  'Currency0',
                                )
                              }}
                              onFocus={() => setInputFocused('Currency0')}
                              onBlur={() => setInputFocused(null)}
                              min="0"
                              step="0.01"
                              className="w-full border-0 bg-transparent focus-visible:ring-0 focus-visible:ring-offset-0 p-0 h-10 text-lg"
                            />
                          </div>
                        </div>

                        {/* Swap button - centered horizontally */}
                        {/* <div className="flex justify-center">
                          <Button
                            type="button"
                            size="icon"
                            variant="ghost"
                            className="h-8 w-8 rounded-full bg-muted"
                            onClick={swapInputs}
                            title="Swap tokens"
                          >
                            <ArrowDownUp className="h-4 w-4" />
                            <span className="sr-only">Swap tokens</span>
                          </Button>
                        </div> */}

                        {/* Input B */}
                        <div className="rounded-lg border border-input p-3">
                          <div className="flex justify-between items-center mb-2">
                            <div className="flex items-center gap-2">
                              <div className="bg-primary/10 rounded-full p-1">
                                <div className="bg-primary h-4 w-4 rounded-full flex items-center justify-center text-white text-[10px] font-bold">
                                  B
                                </div>
                              </div>
                              <span className="font-medium">{getCurrency1()}</span>
                            </div>
                            <div className="text-xs text-muted-foreground">
                              Balance: {getCurrency1Balance()}
                              <Button
                                variant="link"
                                className="text-xs h-auto p-0 ml-1 text-blue-500"
                                onClick={() => handleMaxAmount('Currency1')}
                              >
                                MAX
                              </Button>
                            </div>
                          </div>
                          <div className="flex items-center">
                            <Input
                              id="amountB"
                              type="number"
                              value={amountB ?? undefined}
                              onChange={(e) =>
                                handleAmountChange(
                                  e.target.value ? Number(e.target.value) : 0,
                                  'Currency1',
                                )
                              }
                              onFocus={() => setInputFocused('Currency1')}
                              onBlur={() => setInputFocused(null)}
                              min="0"
                              step="0.0001"
                              className="w-full border-0 bg-transparent focus-visible:ring-0 focus-visible:ring-offset-0 p-0 h-10 text-lg"
                            />
                          </div>
                        </div>
                      </div>

                      {/* Ratio control section */}
                      <div className="flex flex-col space-y-2 mt-2">
                        {/* Ratio lock toggle button */}
                        <div className="flex justify-between items-center">
                          <div className="flex items-center gap-1 text-sm">
                            <Info className="h-3.5 w-3.5 text-muted-foreground" />
                            <span>Price and amount</span>
                          </div>
                          <Button
                            type="button"
                            variant={lockRatio ? 'secondary' : 'outline'}
                            size="sm"
                            className="h-8 px-2 text-xs flex items-center gap-1"
                            onClick={() => setLockRatio(!lockRatio)}
                          >
                            <RefreshCw
                              className={`h-3.5 w-3.5 ${lockRatio ? 'text-primary' : 'text-muted-foreground'}`}
                            />
                            <span>{lockRatio ? 'Locked' : 'Unlocked'}</span>
                          </Button>
                        </div>

                        {/* Ratio display */}
                        <div className="flex flex-col gap-1 p-3 bg-secondary/30 rounded-md">
                          <div className="flex justify-between text-sm">
                            <span className="text-muted-foreground">Current Ratio</span>
                            {amountA > 0 && amountB > 0 ? (
                              <span className="font-medium">
                                1 {getCurrency0()} = {(amountB / amountA).toFixed(4)}{' '}
                                {getCurrency1()}
                              </span>
                            ) : (
                              <span className="text-muted-foreground">
                                Enter amounts to see ratio
                              </span>
                            )}
                          </div>
                        </div>
                      </div>

                      {/* Error message */}
                      {inputError && (
                        <div className="flex items-center text-red-500 text-sm mt-2">
                          <AlertCircle className="h-4 w-4 mr-1" />
                          {inputError}
                        </div>
                      )}
                    </div>
                  </Card>
                ) : (
                  <div className="text-sm text-neutral-500 dark:text-neutral-400 p-4">
                    Select a pool to add liquidity
                  </div>
                )}

                {selectedPoolData && (hasCurrency0Allowance || hasCurrency1Allowance) && (
                  <Card className="p-4 mt-4">
                    <h3 className="font-semibold mb-2">Current Allowance</h3>

                    {hasCurrency0Allowance && (
                      <>
                        <div className="flex justify-between items-center">
                          <span className="text-sm text-neutral-500 dark:text-neutral-400">
                            {symbol}
                          </span>
                          <span className="font-medium">{formattedCurrency0Allowance}</span>
                        </div>
                        <Button
                          variant="link"
                          className="text-red-500 mt-2 p-0 h-auto"
                          onClick={handleRevokeCurrency0Allowance}
                        >
                          Revoke Allowance
                        </Button>
                      </>
                    )}
                  </Card>
                )}
              </div>

              {/* Column 3: Pool Stats and Submit Action */}
              <div className="space-y-4">
                <h3 className="font-semibold">Summary</h3>
                {selectedPoolData ? (
                  <Card className="p-4">
                    <div className="space-y-3">
                      <div className="flex justify-between items-center">
                        <span className="text-sm text-neutral-500 dark:text-neutral-400">APR</span>
                        <span className="font-medium">42069</span>
                      </div>
                      <div className="flex justify-between items-center">
                        <span className="text-sm text-neutral-500 dark:text-neutral-400">TVL</span>
                        <span className="font-medium">42069</span>
                      </div>
                      <div className="flex justify-between items-center">
                        <span className="text-sm text-neutral-500 dark:text-neutral-400">
                          Your Share
                        </span>
                        <span className="font-medium">0%</span>
                      </div>
                      <div className="flex justify-between text-sm">
                        <span className="text-neutral-500 dark:text-neutral-400">
                          Share of Pool
                        </span>
                        <span className="font-medium">0.01%</span> {/* Mock value */}
                      </div>
                    </div>

                    <div className="pt-4 mt-4 border-t border-border">{resolveAction()}</div>
                  </Card>
                ) : (
                  <div className="text-sm text-neutral-500 dark:text-neutral-400 p-4">
                    Select a pool to view summary
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      </DrawerContent>
    </Drawer>
  )
}
