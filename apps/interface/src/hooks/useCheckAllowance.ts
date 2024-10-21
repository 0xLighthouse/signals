import { useEffect, useState } from 'react'
import { readClient } from '@/config/web3'
import { ERC20_ADDRESS, ABI, SIGNALS_PROTOCOL } from '@/config/web3'

export function useCheckAllowance(address?: string, amount?: number) {
  const [hasAllowance, setHasAllowance] = useState(false)

  useEffect(() => {
    const checkAllowance = async () => {
      if (!amount) return
      if (!address) return

      const allowance = await readClient.readContract({
        address: ERC20_ADDRESS,
        abi: ABI,
        functionName: 'allowance',
        args: [address, SIGNALS_PROTOCOL],
      })

      const _hasAllowance = Number(allowance) >= amount * 1e18
      console.log('hasAllowance', _hasAllowance)
      setHasAllowance(_hasAllowance)
    }

    checkAllowance()
  }, [address, amount])

  return hasAllowance
}

