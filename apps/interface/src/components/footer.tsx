'use client'

import { useEffect } from 'react'
import { Separator } from '@/components/ui/separator'
import { useNetworkStore } from '@/stores/useNetworkStore'

export function Footer() {
  const indexerStatus = useNetworkStore((s) => s.indexerStatus)
  const checkIndexerStatus = useNetworkStore((s) => s.checkIndexerStatus)

  useEffect(() => {
    checkIndexerStatus()
  }, [checkIndexerStatus])

  return (
    <div className="mt-10 md:mt-20">
      <div className="space-y-2">
        <div className="flex items-center">
          <h4 className="text-xl font-bold leading-none">Signals</h4>
        </div>
        <p className="text-sm text-muted-foreground">Discovering community alignment.</p>
      </div>
      <Separator className="my-4" />
      <div className="flex h-5 items-center space-x-4 text-sm">
        <div>
          <a href="https://mirror.xyz/lighthousegov.eth" className="hover:underline">
            Blog
          </a>
        </div>
        <Separator orientation="vertical" />
        <div>
          <a href="https://signals.docs.lighthouse.cx" className="hover:underline">
            Docs
          </a>
        </div>
        <Separator orientation="vertical" />
        <div>
          <a href="https://github.com/0xLighthouse/signals" className="hover:underline">
            GitHub
          </a>
        </div>
        <Separator orientation="vertical" />
        <div>
          <a href="https://github.com/0xLighthouse/signals/issues" className="hover:underline">
            Submit feedback
          </a>
        </div>
        {indexerStatus === 'indexing' && (
          <>
            <Separator orientation="vertical" />
            <div className="text-muted-foreground/60 text-xs animate-pulse">
              Indexer syncing...
            </div>
          </>
        )}
      </div>
    </div>
  )
}
