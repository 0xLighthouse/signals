import { Separator } from '@/components/ui/separator'

export function Footer() {
  return (
    <div className="mt-20">
      <div className="space-y-2">
        <h4 className="text-md font-bold leading-none">Signals</h4>
        <p className="text-sm text-muted-foreground">Real time community sentiment</p>
      </div>
      <Separator className="my-4" />
      <div className="flex h-5 items-center space-x-4 text-sm">
        <div>
          <a href="https://mirror.xyz/lighthousegov.eth">Blog</a>
        </div>
        <Separator orientation="vertical" />
        <div>
          <a href="https://docs.lighthouse.cx/protocols/signals">Docs</a>
        </div>
        <Separator orientation="vertical" />
        <div>
          <a href="https://github.com/0xLighthouse/signals">GitHub</a>
        </div>
      </div>
    </div>
  )
}
