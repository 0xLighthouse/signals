import { Card, CardContent, CardDescription, CardFooter, CardHeader } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '../ui/textarea'
import { useUnderlying } from '@/contexts/ContractContext'

export const Submission = () => {
  const { name, symbol, totalSupply, balance } = useUnderlying()

  return (
    <Card>
      <CardHeader>
        <CardDescription>
          You will need {symbol} tokens to submit an idea. You have {balance} ({symbol}) tokens.
          Your tokens will not be locked.
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-2">
        <div className="space-y-1">
          <Label htmlFor="name">Title</Label>
          <Input id="title" placeholder="On-chain forums." />
        </div>
        <div className="space-y-1">
          <Label htmlFor="username">Username</Label>
          <Textarea
            placeholder="Enter something novel. Remember to search for existing ideas first and a reminder this is public."
            required
          />
        </div>

        <div className="grid grid-cols-2 gap-4">
          <Input placeholder="Network (optional)" />
          <Input placeholder="Token (optional)" />
          <Input type="number" />
          <Input placeholder="Duration (optional)" />
        </div>
      </CardContent>
      <CardFooter>
        <Button>Save changes</Button>
      </CardFooter>
    </Card>
  )
}
