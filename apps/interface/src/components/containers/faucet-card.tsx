import React from 'react'
import { Card, CardContent, CardFooter, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'

interface Props {}

export const FaucetCard: React.FC<Props> = () => {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-2xl font-bold">Tokens</CardTitle>
      </CardHeader>
      <CardContent className="space-y-2">
        <div className="text-4xl font-bold">O SYMBOL</div>
        <div className="text-sm text-muted-foreground">Balance</div>
      </CardContent>
      <CardFooter className="flex justify-end">
        <Button>Faucet</Button>
      </CardFooter>
    </Card>
  )
}
