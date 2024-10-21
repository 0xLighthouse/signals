'use client'

import React, { useEffect, useState } from 'react'
import { useAccount } from 'wagmi'
import { readClient } from '@/config/web3'
import { useUnderlying } from '@/contexts/ContractContext'
import { useSignals } from '@/contexts/SignalsContext'
import { useRewardsStore } from '@/stores/useRewardsStore'

export const FaucetBar = () => {
  const { address } = useAccount()
  const {
    balance: usdcBalance,
    fetch: fetchUSDC,
    symbol: usdcSymbol,
    formatter: formatUSDC,
  } = useRewardsStore()
  const { symbol: underlyingSymbol, totalSupply, balance: underlyingBalance } = useUnderlying()
  const { formatter } = useSignals()

  useEffect(() => {
    if (address) {
      fetchUSDC(address)
    }
  }, [address, fetchUSDC])

  // const [gas, setGas] = useState<number>(0)

  // useEffect(() => {
  //   const fetchGasBalance = async () => {
  //     try {
  //       if (!address) return
  //       const gasBalance = await readClient.getBalance({
  //         address,
  //       })
  //       setGas(Number(gasBalance))
  //     } catch (error) {
  //       console.error('Error fetching gas balance:', error)
  //     }
  //   }
  //   fetchGasBalance()
  // }, [address])

  if (!address) return null

  return (
    <div className="flex items-center justify-between p-4 bg-white dark:bg-neutral-900 shadow-md rounded-lg">
      <div className="flex flex-1 justify-evenly text-center">
        <div>
          <span className="text-2xl font-bold">{formatter(underlyingBalance)}</span>
          <p className="text-sm text-neutral-500 dark:text-neutral-400">
            Balance ({underlyingSymbol})
          </p>
        </div>
        <div>
          <span className="text-2xl font-bold">{formatUSDC(usdcBalance)}</span>
          <p className="text-sm text-neutral-500 dark:text-neutral-400">Balance ({usdcSymbol})</p>
        </div>
        <div>
          <span className="text-2xl font-bold">TODO</span>
          <p className="text-sm text-neutral-500 dark:text-neutral-400">% Locked</p>
        </div>
      </div>
    </div>
  )
}
