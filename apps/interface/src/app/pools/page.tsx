'use client'

import { PageLayout } from '@/components/containers/page-layout'
import { Card } from '@/components/ui/card'
import { ProvideLiquidityDrawer } from '@/components/drawers/provide-liquidity-drawer'

export default function PoolsPage() {
  return (
    <PageLayout>
      <div className="flex flex-col items-center justify-center">
        <h1 className="text-3xl font-bold mb-6">Liquidity Pools</h1>
        <div className="w-full">
          <Card className="p-6 mb-6">
            <div className="flex justify-between items-center mb-4">
              <h2 className="text-xl font-semibold">Main Liquidity Pool</h2>
              <ProvideLiquidityDrawer />
            </div>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mt-4">
              <div className="bg-neutral-100 dark:bg-neutral-800 p-4 rounded-lg">
                <p className="text-sm text-neutral-500 dark:text-neutral-400">Total Liquidity</p>
                <p className="text-2xl font-bold">100,000 USDC</p>
              </div>
              <div className="bg-neutral-100 dark:bg-neutral-800 p-4 rounded-lg">
                <p className="text-sm text-neutral-500 dark:text-neutral-400">Your Liquidity</p>
                <p className="text-2xl font-bold">0 USDC</p>
              </div>
              <div className="bg-neutral-100 dark:bg-neutral-800 p-4 rounded-lg">
                <p className="text-sm text-neutral-500 dark:text-neutral-400">APR</p>
                <p className="text-2xl font-bold">5.2%</p>
              </div>
            </div>
          </Card>
          
          <div className="bg-neutral-50 dark:bg-neutral-900 p-6 rounded-lg">
            <h3 className="text-lg font-medium mb-4">About Providing Liquidity</h3>
            <ul className="list-disc pl-5 space-y-2">
              <li>Provide liquidity to earn fees from trades and bond transactions</li>
              <li>Receive LP tokens representing your share of the pool</li>
              <li>Withdraw your liquidity at any time</li>
              <li>APR varies based on pool activity and total liquidity</li>
            </ul>
          </div>
        </div>
      </div>
    </PageLayout>
  )
}