import React from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'

export const InstructionsCard = () => {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-sm font-bold">Instructions</CardTitle>
      </CardHeader>
      <CardContent className="text-sm">        
        <ul>
            <li>1. Connect your wallet</li>
            <li>2. Claim tokens from our faucet</li>
            <li>3. Propose an initiative</li>
            <li>4. Support other initiatives</li>
        </ul>
      </CardContent>      
    </Card>
  )
}
