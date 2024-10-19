'use client'

import { useEffect } from 'react'
import { useAccount } from 'wagmi'

export const History = () => {
  const { address } = useAccount()
  //   const [initiatives, setInitiatives] = useState<NormalisedInitiative[]>([])

  useEffect(() => {
    if (!address) return

    fetch(`/api/history?supporter=${address}`)
      .then((res) => res.json())
      .then((data) => {
        console.log('history', data)
        // Ensure data is an array before setting state
        // if (Array.isArray(data)) {
        //   setInitiatives(data) // Update the state with the fetched data
        // } else {
        //   console.error('Fetched data is not an array:', data) // Log an error if data is not an array
        // }
      })
      .catch((error) => console.error('Error fetching history:', error)) // Handle errors
  }, [address])
  return <div>History</div>
}
