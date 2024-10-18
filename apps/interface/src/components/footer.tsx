import { Separator } from '@/components/ui/separator'

export function Footer() {
  return (
    <div>
      <div className="space-y-1">
        <h4 className="text-sm font-medium leading-none">Signals</h4>
        <p className="text-sm text-muted-foreground">
          Pool feedback from the community to prioritize initiatives.
        </p>
      </div>
      <Separator className="my-4" />
      <div className="flex h-5 items-center space-x-4 text-sm">
        <div>Blog</div>
        <Separator orientation="vertical" />
        <div>Docs</div>
        <Separator orientation="vertical" />
        <div>
          <a href="https://github.com/0xLighthouse/signals">GitHub</a>
        </div>
      </div>
    </div>
  )
}
