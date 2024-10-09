import { Initiatives } from '@/components/containers/initiatives'
import { FaucetCard } from '@/components/containers/faucet.card'
import { TopNav } from '@/components/containers/topnav'
import { InstructionsCard } from '@/components/containers/instructions'
import { AlertDemo } from '@/components/alert'
import { SubmissionsV2 } from '@/components/containers/submissions-v2'

export default function Home() {
  return (
    <div>
      <TopNav />
      {/* <div className="container mx-auto max-w-5xl"> */}
      <div className="container mx-auto max-w-7xl">
        <AlertDemo />
        <div className="grid grid-cols-1 md:grid-cols-[800px_1fr]">
          <div className="px-4 py-8 space-y-6">
            <Initiatives />
          </div>
          <div className="px-4 py-8">
            <SubmissionsV2 />
            <InstructionsCard />
            <FaucetCard />
          </div>
        </div>
      </div>
    </div>
  )
}
