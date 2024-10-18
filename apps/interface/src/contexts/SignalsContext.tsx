import { createContext, useContext, useEffect, useState } from 'react'
import { getContract } from 'viem'
import { useAccount } from 'wagmi'

// Types for contract metadata
type ProtocolContextType = {}

// Default values for the context
export const ProtocolContext = createContext<ProtocolContextType | undefined>(undefined)

// Custom hook to use the contract context
export const useSignals = () => {
  const context = useContext(ProtocolContext)
  if (!context) {
    throw new Error('useSignals must be used within a ProtocolContext')
  }
  return context
}

interface Props {
  children: React.ReactNode
}

export const ProtocolProvider: React.FC<Props> = ({ children }) => {
  const { address } = useAccount()

  // const [name, setContractName] = useState<string | null>(null)
  // const [symbol, setSymbol] = useState<string | null>(null)
  // const [decimals, setDecimals] = useState<number | null>(null)
  // const [totalSupply, setTotalSupply] = useState<number | null>(null)
  // const [balance, setBalance] = useState<number | null>(null)

  // useEffect(() => {
  //   const fetchContractMetadata = async () => {
  //     if (!address) return

  //     try {
  //       const contract = getContract({
  //         address: ERC20_ADDRESS,
  //         abi: ABI,
  //         client: readClient,
  //       })

  //       // Fetch contract data in parallel using Promise.all
  //       const [name, symbol, decimals, totalSupply, balance] = await Promise.all([
  //         contract.read.name(),
  //         contract.read.symbol(),
  //         contract.read.decimals(),
  //         contract.read.totalSupply(),
  //         contract.read.balanceOf([address]),
  //       ])

  //       console.log(
  //         `LOG ------------_> Name: ${name}, Symbol: ${symbol}, Decimals: ${decimals}, Total Supply: ${totalSupply}, Balance: ${balance}`,
  //       )

  //       // Update state with fetched metadata
  //       setContractName(String(name))
  //       setSymbol(String(symbol))
  //       setDecimals(Number(decimals))
  //       setTotalSupply(Number(totalSupply))
  //       setBalance(Number(balance))
  //     } catch (error) {
  //       console.error('Error fetching contract metadata:', error)
  //     }
  //   }

  //   // Fetch contract metadata when the address changes
  //   fetchContractMetadata()
  // }, [address])

  // // Provide contract data to children
  return <ProtocolContext.Provider value={{}}>{children}</ProtocolContext.Provider>
}
