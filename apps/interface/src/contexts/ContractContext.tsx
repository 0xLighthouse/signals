'use client'

import { context, readClient } from '@/config/web3'
import { useAccount } from '@/hooks/useAccount'
import React, { createContext, useState, useEffect, useContext } from 'react'
import { getContract } from 'viem'

const token = getContract({
  address: context.contracts.BoardUnderlyingToken.address,
  abi: context.contracts.BoardUnderlyingToken.abi,
  client: readClient,
})

// Types for contract metadata
interface ContractContextType {
  address: `0x${string}`
  name: string | null
  symbol: string | null
  decimals: number | null
  totalSupply: number | null
  balance: number | null
  fetchContractMetadata: () => Promise<void>
  formatter: (value?: number | null | undefined) => number
}

// Default values for the context
export const ContractContext = createContext<ContractContextType | undefined>(undefined)

// Custom hook to use the contract context
export const useUnderlying = () => {
  const context = useContext(ContractContext)
  if (!context) {
    throw new Error('useUnderlying must be used within a ContractContext')
  }
  return context
}

interface Props {
  children: React.ReactNode
}

export const TokenProvider: React.FC<Props> = ({ children }) => {
  const { address } = useAccount()
  const [name, setContractName] = useState<string | null>(null)
  const [symbol, setSymbol] = useState<string | null>(null)
  const [decimals, setDecimals] = useState<number | null>(null)
  const [totalSupply, setTotalSupply] = useState<number>(0)
  const [balance, setBalance] = useState<number>(0)

  const fetchContractMetadata = React.useCallback(async () => {
    try {
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
  }, [address])

  useEffect(() => {
    // Fetch contract metadata when the address changes
    fetchContractMetadata()
  }, [fetchContractMetadata])

  // Expose a formatter for the underlying token
  const formatter = (value?: number | null | undefined) => {
    if (!decimals || !value) return value
    const exp = 10 ** decimals
    return Math.ceil(value / exp)
  }

  // Provide contract data to children
  return (
    <ContractContext.Provider
      value={{
        address: context.contracts.BoardUnderlyingToken.address.toLowerCase() as `0x${string}`,
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
    </ContractContext.Provider>
  )
}
