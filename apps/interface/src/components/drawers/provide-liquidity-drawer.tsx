'use client'

import { CircleAlert, DollarSign, ArrowDownUp, AlertCircle, Info, RefreshCw } from 'lucide-react'
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
import { Alert, AlertDescription, AlertTitle } from '../ui/alert'
import { useWeb3 } from '@/contexts/Web3Provider'
import { usePrivy } from '@privy-io/react-auth'
import { normaliseNumber } from '@/lib/utils'

interface Pool {
  id: string
  name: string
  currencyA: string
  currencyB: string
  apr: string
  tvl: string
}

export function ProvideLiquidityDrawer() {
  const { address } = useAccount()
  const { walletClient, publicClient } = useWeb3()
  const { authenticated, login } = usePrivy()
  const { balance, symbol, fetchContractMetadata, formatter } = useUnderlying()

  const [amountA, setAmountA] = useState(0)
  const [amountB, setAmountB] = useState(0)
  const [isDrawerOpen, setIsDrawerOpen] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [selectedPool, setSelectedPool] = useState<string>('')
  const [inputFocused, setInputFocused] = useState<'A' | 'B' | null>(null)
  const [inputError, setInputError] = useState<string | null>(null)
  const [lockRatio, setLockRatio] = useState(true)

  // Mock data - replace with actual data fetching
  const availablePools: Pool[] = [
    {
      id: '1',
      name: 'USDC/GOV Pool',
      currencyA: 'USDC',
      currencyB: 'GOV',
      apr: '5.2%',
      tvl: '$1.2M',
    },
    {
      id: '2',
      name: 'USDT/GOV Pool',
      currencyA: 'USDT',
      currencyB: 'GOV',
      apr: '5.4%',
      tvl: '$800K',
    },
  ]

  const selectedPoolData = availablePools.find((pool) => pool.id === selectedPool)
  
  // Track if inputs are swapped to show correct token and balance information
  const [isInputsSwapped, setIsInputsSwapped] = useState(false)
  
  // Get the correct token details based on the current swap state
  const getTokenA = () => isInputsSwapped ? selectedPoolData?.currencyB : selectedPoolData?.currencyA
  const getTokenB = () => isInputsSwapped ? selectedPoolData?.currencyA : selectedPoolData?.currencyB
  
  // Get the correct balance for each input field
  const getBalanceA = () => {
    if (!selectedPoolData) return '0'
    return isInputsSwapped ? '0.00' : normaliseNumber(formatter(balance)) || '0'
  }
  
  const getBalanceB = () => {
    if (!selectedPoolData) return '0'
    return isInputsSwapped ? normaliseNumber(formatter(balance)) || '0' : '0.00'
  }

  const {
    isApproving,
    hasAllowance,
    handleApprove,
    allowance,
    formattedAllowance,
    handleRevokeAllowance,
  } = useApproveTokens({
    amount: amountA,
    actor: address,
    spender: context.contracts.SignalsProtocol.address,
    tokenAddress: context.contracts.BoardUnderlyingToken.address,
    tokenDecimals: 18,
  })

  const resetFormState = () => {
    setAmountA(0)
    setAmountB(0)
    setSelectedPool('')
    setInputError(null)
    setIsInputsSwapped(false) // Reset to original order
    setLockRatio(true) // Reset to locked ratio by default
  }
  
  const handleMaxAmount = (input: 'A' | 'B') => {
    const maxAmount = parseFloat(normaliseNumber(formatter(balance)))
    
    if (input === 'A') {
      if (isInputsSwapped) {
        // In swapped mode, token B is in position A
        // Mock for now, would use actual B balance
        setAmountA(0)
        validateInput(0, 'A')
      } else {
        // Normal mode, token A is in position A
        setAmountA(maxAmount)
        validateInput(maxAmount, 'A')
      }
    } else {
      if (isInputsSwapped) {
        // In swapped mode, token A is in position B
        setAmountB(maxAmount)
        validateInput(maxAmount, 'B')
      } else {
        // Normal mode, token B is in position B
        // Mock for now, would use actual B balance
        setAmountB(0)
        validateInput(0, 'B')
      }
    }
  }
  
  const validateInput = (value: number, input: 'A' | 'B') => {
    const userBalance = parseFloat(normaliseNumber(formatter(balance)))
    
    if (input === 'A') {
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
        validateInput(amountB, 'A')
        validateInput(tempA, 'B')
      }, 0)
    }
  }
  
  // Calculate the ratio between tokens for locked ratio mode
  const calculateRatio = () => {
    if (amountA > 0 && amountB > 0) {
      return amountB / amountA
    }
    // Default ratio - in a real app, this would be derived from the pool's reserve ratio
    return 1; 
  }
  
  const handleAmountChange = (value: number, input: 'A' | 'B') => {
    // Get the current ratio if we're maintaining ratio and if both values are set
    const ratio = calculateRatio();
    
    if (input === 'A') {
      setAmountA(value)
      
      // If ratio is locked and we have a valid ratio, update B proportionally
      if (lockRatio && amountA > 0 && amountB > 0) {
        const newBValue = value * ratio;
        setAmountB(Math.max(0, parseFloat(newBValue.toFixed(6))));
        validateInput(newBValue, 'B');
      }
      
      validateInput(value, 'A')
    } else {
      setAmountB(value)
      
      // If ratio is locked and we have a valid ratio, update A proportionally
      if (lockRatio && amountA > 0 && amountB > 0) {
        const newAValue = value / ratio;
        setAmountA(Math.max(0, parseFloat(newAValue.toFixed(6))));
        validateInput(newAValue, 'A');
      }
      
      validateInput(value, 'B')
    }
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
    if (!amountA || !amountB || !selectedPool) {
      return toast('Please enter amounts and select a pool')
    }
    
    // Validate input amounts before submitting
    const isValidA = validateInput(amountA, 'A')
    const isValidB = validateInput(amountB, 'B')
    
    if (!isValidA || !isValidB) {
      return // Don't proceed if input validation fails
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
      //   args: [BigInt(amountA * 1e18), BigInt(amountB * 1e18), selectedPool],
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
    if (!hasAllowance && amountA) {
      return (
        <Button onClick={() => handleApprove(amountA)} isLoading={isApproving} className="w-full">
          {isApproving ? 'Confirming approval...' : 'Approve'}
        </Button>
      )
    }
    return (
      <Button 
        disabled={!amountA || !amountB || !selectedPool || !!inputError} 
        onClick={handleSubmit} 
        isLoading={isSubmitting}
        className="w-full"
      >
        {inputError ? 'Insufficient Balance' : 'Provide Liquidity'}
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
                {availablePools.map((pool) => (
                  <Card
                    key={pool.id}
                    className={`p-4 cursor-pointer transition-colors ${
                      selectedPool === pool.id ? 'border-blue-500' : 'hover:border-blue-500/50'
                    }`}
                    onClick={() => setSelectedPool(pool.id)}
                  >
                    <div className="flex flex-col gap-2">
                      <h3 className="font-bold">{pool.name}</h3>
                      <div className="text-sm text-muted-foreground">
                        <div>
                          {pool.currencyA}/{pool.currencyB}
                        </div>
                      </div>
                    </div>
                  </Card>
                ))}

                {/* User Balances */}
                <Card className="p-4 mt-4">
                  <h3 className="font-semibold mb-2">Your Balances</h3>
                  <div className="space-y-2">
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-neutral-500 dark:text-neutral-400">
                        {symbol}
                      </span>
                      <span className="font-medium">{normaliseNumber(formatter(balance)) || '-'}</span>
                    </div>
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-neutral-500 dark:text-neutral-400">
                        USDC
                      </span>
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
                                <div className="bg-primary h-4 w-4 rounded-full flex items-center justify-center text-white text-[10px] font-bold">A</div>
                              </div>
                              <span className="font-medium">{getTokenA()}</span>
                            </div>
                            <div className="text-xs text-muted-foreground">
                              Balance: {getBalanceA()}
                              <Button 
                                variant="link" 
                                className="text-xs h-auto p-0 ml-1 text-blue-500" 
                                onClick={() => handleMaxAmount('A')}
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
                              placeholder="0.0"
                              onChange={(e) => handleAmountChange(e.target.value ? Number(e.target.value) : 0, 'A')}
                              onFocus={() => setInputFocused('A')}
                              onBlur={() => setInputFocused(null)}
                              min="0"
                              step="0.01"
                              className="w-full border-0 bg-transparent focus-visible:ring-0 focus-visible:ring-offset-0 p-0 h-10 text-lg"
                            />
                          </div>
                        </div>
                        
                        {/* Swap button - centered horizontally */}
                        <div className="flex justify-center">
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
                        </div>
                        
                        {/* Input B */}
                        <div className="rounded-lg border border-input p-3">
                          <div className="flex justify-between items-center mb-2">
                            <div className="flex items-center gap-2">
                              <div className="bg-primary/10 rounded-full p-1">
                                <div className="bg-primary h-4 w-4 rounded-full flex items-center justify-center text-white text-[10px] font-bold">B</div>
                              </div>
                              <span className="font-medium">{getTokenB()}</span>
                            </div>
                            <div className="text-xs text-muted-foreground">
                              Balance: {getBalanceB()}
                              <Button 
                                variant="link" 
                                className="text-xs h-auto p-0 ml-1 text-blue-500" 
                                onClick={() => handleMaxAmount('B')}
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
                              placeholder="0.0"
                              onChange={(e) => handleAmountChange(e.target.value ? Number(e.target.value) : 0, 'B')}
                              onFocus={() => setInputFocused('B')}
                              onBlur={() => setInputFocused(null)}
                              min="0"
                              step="0.01"
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
                            variant={lockRatio ? "secondary" : "outline"}
                            size="sm"
                            className="h-8 px-2 text-xs flex items-center gap-1"
                            onClick={() => setLockRatio(!lockRatio)}
                          >
                            <RefreshCw className={`h-3.5 w-3.5 ${lockRatio ? "text-primary" : "text-muted-foreground"}`} />
                            <span>{lockRatio ? "Locked" : "Unlocked"}</span>
                          </Button>
                        </div>
                        
                        {/* Ratio display */}
                        <div className="flex flex-col gap-1 p-3 bg-secondary/30 rounded-md">
                          <div className="flex justify-between text-sm">
                            <span className="text-muted-foreground">Current Ratio</span>
                            {amountA > 0 && amountB > 0 ? (
                              <span className="font-medium">1 {getTokenA()} = {(amountB / amountA).toFixed(4)} {getTokenB()}</span>
                            ) : (
                              <span className="text-muted-foreground">Enter amounts to see ratio</span>
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

                {selectedPoolData && allowance ? (
                  <Card className="p-4 mt-4">
                    <h3 className="font-semibold mb-2">Current Allowance</h3>
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-neutral-500 dark:text-neutral-400">
                        {symbol}
                      </span>
                      <span className="font-medium">{formattedAllowance}</span>
                    </div>
                    <Button
                      variant="link"
                      className="text-red-500 mt-2 p-0 h-auto"
                      onClick={handleRevokeAllowance}
                    >
                      Revoke Allowance
                    </Button>
                  </Card>
                ) : null}
              </div>

              {/* Column 3: Pool Stats and Submit Action */}
              <div className="space-y-4">
                <h3 className="font-semibold">Summary</h3>
                {selectedPoolData ? (
                  <Card className="p-4">
                    <div className="space-y-3">
                      <div className="flex justify-between items-center">
                        <span className="text-sm text-neutral-500 dark:text-neutral-400">
                          APR
                        </span>
                        <span className="font-medium">{selectedPoolData.apr}</span>
                      </div>
                      <div className="flex justify-between items-center">
                        <span className="text-sm text-neutral-500 dark:text-neutral-400">
                          TVL
                        </span>
                        <span className="font-medium">{selectedPoolData.tvl}</span>
                      </div>
                      <div className="flex justify-between items-center">
                        <span className="text-sm text-neutral-500 dark:text-neutral-400">
                          Your Share
                        </span>
                        <span className="font-medium">0%</span>
                      </div>
                      <div className="flex justify-between text-sm">
                        <span className="text-neutral-500 dark:text-neutral-400">Share of Pool</span>
                        <span className="font-medium">0.01%</span> {/* Mock value */}
                      </div>
                    </div>
                    
                    <div className="pt-4 mt-4 border-t border-border">
                      {resolveAction()}
                    </div>
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