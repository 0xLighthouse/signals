import { useEffect, useState } from 'react'
import { readClient } from '@/config/web3'
import { ABI } from '@/config/web3'

interface Props {
  actor?: `0x${string}`
  amount?: number | null
  decimals?: number
  spenderAddress?: `0x${string}`
  tokenAddress?: `0x${string}`
}

export function useCheckAllowance({
  actor,
  amount,
  decimals,
  spenderAddress,
  tokenAddress,
}: Props) {
  const [hasAllowance, setHasAllowance] = useState(false)

  useEffect(() => {
    const checkAllowance = async () => {
      if (!amount || !actor || !spenderAddress || !tokenAddress) return

      const allowance = await readClient.readContract({
        address: tokenAddress,
        abi: ABI,
        functionName: 'allowance',
        args: [actor, spenderAddress],
      })

      const _hasAllowance = Number(allowance) >= amount * 10 ** (decimals || 18)
      console.log('hasAllowance', _hasAllowance)
      setHasAllowance(_hasAllowance)
    }

    checkAllowance()
  }, [actor, amount, spenderAddress, tokenAddress, decimals])

  return hasAllowance
}
