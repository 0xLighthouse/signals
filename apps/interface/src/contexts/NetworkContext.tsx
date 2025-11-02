'use client'

import React, { createContext, useState, useEffect, useContext } from 'react'
import { getContract } from 'viem'

import { useNetwork } from '@/hooks/useNetwork'
import { useAccount } from '@/hooks/useAccount'
import { ZERO_ADDRESS } from '@/config/web3'
import { useWeb3 } from './Web3Provider'

// Types for contract metadata
interface NetworkContextType {
  address: `0x${string}`
  name: string | null
  symbol: string | null
  decimals: number | null
  totalSupply: number | null
  balance: number | null
  fetchContractMetadata: () => Promise<void>
}

// Default values for the context
export const NetworkContext = createContext<NetworkContextType | undefined>(undefined)

// Custom hook to use the contract context
export const useUnderlying = () => {
  const context = useContext(NetworkContext)
  if (!context) {
    throw new Error('useUnderlying must be used within a NetworkContext')
  }
  return context
}

interface Props {
  children: React.ReactNode
}

export const NetworkProvider: React.FC<Props> = ({ children }) => {
  const { address } = useAccount()
  const { config } = useNetwork()
  const { publicClient } = useWeb3()
  const underlyingContract = config.contracts.BoardUnderlyingToken
  const [name, setContractName] = useState<string | null>(null)
  const [symbol, setSymbol] = useState<string | null>(null)
  const [decimals, setDecimals] = useState<number | null>(null)
  const [totalSupply, setTotalSupply] = useState<number>(0)
  const [balance, setBalance] = useState<number>(0)

  const fetchContractMetadata = React.useCallback(async () => {
    if (!publicClient || !underlyingContract) return

    try {
      const token = getContract({
        address: underlyingContract.address,
        abi: underlyingContract.abi,
        client: publicClient,
      })

      // Fetch contract data in parallel using Promise.all
      const [name, symbol, decimals, totalSupply, balance] = await Promise.all([
        token.read.name(),
        token.read.symbol(),
        token.read.decimals(),
        token.read.totalSupply(),
        address ? token.read.balanceOf([address]) : 0,
      ])

      // Update state with fetched metadata
      setContractName(String(name))
      setSymbol(String(symbol))
      setDecimals(Number(decimals))
      setTotalSupply(Number(totalSupply ?? 0))
      setBalance(Number(balance))
    } catch (error) {
      console.error('Error fetching contract metadata:', error)
    }
  }, [address, publicClient, underlyingContract?.address, underlyingContract?.abi])

  useEffect(() => {
    // Fetch contract metadata when the address changes
    fetchContractMetadata()
  }, [fetchContractMetadata])

  // Expose a formatter for the underlying token
  const formatter = (value?: number | null | undefined) => {
    const effectiveDecimals = decimals ?? underlyingContract?.decimals
    if (!effectiveDecimals || !value) return value ?? null
    const exp = 10 ** effectiveDecimals
    return Math.ceil(value / exp)
  }

  // Provide contract data to children
  return (
    <NetworkContext.Provider
      value={{
        address: (underlyingContract?.address ?? ZERO_ADDRESS).toLowerCase() as `0x${string}`,
        name,
        symbol,
        decimals,
        totalSupply,
        balance,
        formatter: (value) => formatter(value) ?? 0,
        fetchContractMetadata,
      }}
    >
      {children}
    </NetworkContext.Provider>
  )
}
