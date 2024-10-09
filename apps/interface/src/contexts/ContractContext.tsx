'use client'

import { ABI, ERC20_ADDRESS, readClient } from '@/config/web3'
import React, { createContext, useState, useEffect, useContext } from 'react'
import { getContract } from 'viem'
import { useAccount } from 'wagmi'

// Types for contract metadata
interface ContractContextType {
  name: string | null
  symbol: string | null
  decimals: number | null
  totalSupply: number | null
  balance: number | null
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

export const TokenProvider: React.FC<Props> = ({  children }) => {
  const { address } = useAccount()

  const [name, setContractName] = useState<string | null>(null)
  const [symbol, setSymbol] = useState<string | null>(null)
  const [decimals, setDecimals] = useState<number | null>(null)
  const [totalSupply, setTotalSupply] = useState<number | null>(null)
  const [balance, setBalance] = useState<number | null>(null)

  useEffect(() => {
    const fetchContractMetadata = async () => {
      if (!address) return

      try {
        const contract = getContract({
          address: ERC20_ADDRESS,
          abi: ABI,
          client: readClient,
        })

        // Fetch contract data in parallel using Promise.all
        const [name, symbol, totalSupply, balance] = await Promise.all([
          contract.read.name(),
          contract.read.symbol(),
          contract.read.decimals(),
          contract.read.totalSupply(),
          contract.read.balanceOf([address]),
        ])

        // Update state with fetched metadata
        setContractName(String(name))
        setSymbol(String(symbol))
        setDecimals(Number(decimals))
        setTotalSupply(Number(totalSupply))
        setBalance(Number(balance))
      } catch (error) {
        console.error('Error fetching contract metadata:', error)
      }
    }

    // Fetch contract metadata when the address changes
    fetchContractMetadata()
  }, [address])

  // Provide contract data to children
  return (
    <ContractContext.Provider value={{ name, symbol, decimals, totalSupply, balance }}>
      {children}
    </ContractContext.Provider>
  )
}
