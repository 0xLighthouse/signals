import { redirect } from 'next/navigation'
import { getDefaultNetwork, getNetworkUrl } from '@/lib/routing'

export default function Home() {
  const defaultNetwork = getDefaultNetwork()
  redirect(getNetworkUrl(defaultNetwork))
}
