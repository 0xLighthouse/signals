import { Separator } from '@/components/ui/separator'
import { HomeLogo } from './ui/home-logo'

export function Footer() {
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
          <a href="https://docs.lighthouse.cx/protocols/signals" className="hover:underline">
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
      </div>
      {/* <Separator className="my-4" /> */}
      <div className="mt-8 flex justify-end">
        <a href="https://lighthouse.cx" target="_blank" rel="noreferrer">
          <HomeLogo />
        </a>
      </div>
    </div>
  )
}
