'use client'

import { useNetworkStore } from '@/stores/useNetworkStore'
import { useBoardsStore } from '@/stores/useBoardsStore'

export const Debug = () => {
  const config = useNetworkStore((state) => state.config)
  const boards = useBoardsStore((state) => state.boards)

  // omit contracts on config
  const { contracts, ...networkConfig } = config
  console.log(JSON.stringify(networkConfig, null, 2))
  console.log(JSON.stringify(boards, null, 2))
  return null
}
