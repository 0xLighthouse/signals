'use client'

import {
    Card,
    CardContent,
    CardDescription,
    CardFooter,
    CardHeader    
} from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import {
  Tabs,
  TabsContent,
  TabsList,
  TabsTrigger,
} from "@/components/ui/tabs"
import { Textarea } from "../ui/textarea"
import { useUnderlying } from "@/contexts/ContractContext"

export const SubmissionsV2 = () => {
  const { name, symbol, totalSupply, balance } = useUnderlying()
  

  return (
    <Tabs defaultValue="account" className="w-[400px]">
      <TabsList className="grid w-full grid-cols-2">
        <TabsTrigger value="account">Account</TabsTrigger>
        <TabsTrigger value="password">Password</TabsTrigger>
      </TabsList>
      <TabsContent value="account">
        <Card>
          <CardHeader>
            <CardDescription>
              You will need {symbol} tokens to submit an idea. You have {balance} ({symbol}) tokens. Your tokens will not be locked.
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
          </CardContent>
          <CardFooter>
            <Button>Save changes</Button>
          </CardFooter>
        </Card>
      </TabsContent>
      <TabsContent value="password">
        <Card>
          <CardHeader>
            <CardDescription>
            You will need XXX tokens to submit an idea. You have XXX tokens. Your tokens WILL not be locked.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-2">
            <div className="space-y-1">
              <Label htmlFor="current">Current password</Label>
              <Input id="current" type="password" />
            </div>
            <div className="space-y-1">
              <Label htmlFor="new">New password</Label>
              <Input id="new" type="password" />
            </div>
          </CardContent>
          <CardFooter>
            <Button>Save password</Button>
          </CardFooter>
        </Card>
      </TabsContent>
    </Tabs>
  )
}
