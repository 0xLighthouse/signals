'use client'

import { Button } from '@/components/ui/button'
import { Drawer, DrawerClose, DrawerContent, DrawerHeader, DrawerTitle, DrawerTrigger } from '@/components/ui/drawer'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { useAccount } from '@/hooks/useAccount'
import { useState } from 'react'
import { toast } from 'sonner'

export function DeploySignalsDrawer({ isOpen, onOpenChange }: { isOpen: boolean, onOpenChange: (open: boolean) => void }) {
  const { address, isConnected } = useAccount()
  const [isLoading, setIsLoading] = useState(false)

  const [formData, setFormData] = useState({
    owner: '',
    underlyingToken: '',
    proposalThreshold: '1000000000000000000', // 1 token in wei (18 decimals)
    acceptanceThreshold: '10000000000000000000', // 10 tokens in wei
    maxLockIntervals: '12', // 12 intervals
    proposalCap: '100', // Max 100 proposals
    lockInterval: '604800', // 1 week in seconds
    decayCurveType: '0', // Linear
    decayCurveParameters: ['1000000000000000000'] // 1.0 as a decimal with 18 decimals
  })

  const handleChange = (field: string, value: string) => {
    setFormData(prev => ({
      ...prev,
      [field]: value
    }))
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    try {
      setIsLoading(true)

      // TODO: Implement contract deployment using viem
      // This will be implemented when we have the factory contract address and ABI

      toast.success('Contract successfully deployed!')
      onOpenChange(false)
      // Reset form after successful deployment
      setFormData({
        owner: '',
        underlyingToken: '',
        proposalThreshold: '1000000000000000000',
        acceptanceThreshold: '10000000000000000000',
        maxLockIntervals: '12',
        proposalCap: '100',
        lockInterval: '604800',
        decayCurveType: '0',
        decayCurveParameters: ['1000000000000000000']
      })
    } catch (error) {
      console.error('Error deploying contract:', error)
      toast.error('Failed to deploy contract. Check console for details.')
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <Drawer open={isOpen} onOpenChange={onOpenChange}>
      <DrawerTrigger asChild>
        <Button variant="outline" onClick={() => onOpenChange(true)}>Deploy Contract</Button>
      </DrawerTrigger>
      <DrawerContent className="h-[90vh]">
        <div className="mx-auto w-full max-w-md">
          <DrawerHeader>
            <DrawerTitle>Deploy Signals Contract</DrawerTitle>
          </DrawerHeader>
          <form onSubmit={handleSubmit} className="space-y-4 p-4">
            <div className="space-y-2">
              <Label htmlFor="owner">Owner Address</Label>
              <Input
                id="owner"
                placeholder="0x..."
                value={formData.owner || address}
                onChange={(e) => handleChange('owner', e.target.value)}
              />
              <p className="text-xs text-gray-500">
                The address that will own the new contract
              </p>
            </div>

            <div className="space-y-2">
              <Label htmlFor="underlyingToken">Governance Token Address</Label>
              <Input
                id="underlyingToken"
                placeholder="0x..."
                value={formData.underlyingToken}
                onChange={(e) => handleChange('underlyingToken', e.target.value)}
                required
              />
              <p className="text-xs text-gray-500">
                The ERC20 token address that will be used for lockups
              </p>
            </div>

            <div className="space-y-2">
              <Label htmlFor="proposalThreshold">Proposal Threshold</Label>
              <Input
                id="proposalThreshold"
                placeholder="1000000000000000000"
                value={formData.proposalThreshold}
                onChange={(e) => handleChange('proposalThreshold', e.target.value)}
                required
              />
              <p className="text-xs text-gray-500">
                Minimum token balance required to submit an initiative (in wei)
              </p>
            </div>

            <div className="space-y-2">
              <Label htmlFor="acceptanceThreshold">Acceptance Threshold</Label>
              <Input
                id="acceptanceThreshold"
                placeholder="10000000000000000000"
                value={formData.acceptanceThreshold}
                onChange={(e) => handleChange('acceptanceThreshold', e.target.value)}
                required
              />
              <p className="text-xs text-gray-500">
                Support required before an initiative can be accepted (in wei)
              </p>
            </div>

            <div className="space-y-2">
              <Label htmlFor="maxLockIntervals">Max Lock Intervals</Label>
              <Input
                id="maxLockIntervals"
                placeholder="12"
                value={formData.maxLockIntervals}
                onChange={(e) => handleChange('maxLockIntervals', e.target.value)}
                required
              />
              <p className="text-xs text-gray-500">
                Maximum number of intervals funds can be locked
              </p>
            </div>

            <div className="space-y-2">
              <Label htmlFor="proposalCap">Proposal Cap</Label>
              <Input
                id="proposalCap"
                placeholder="100"
                value={formData.proposalCap}
                onChange={(e) => handleChange('proposalCap', e.target.value)}
                required
              />
              <p className="text-xs text-gray-500">
                Maximum number of proposals allowed
              </p>
            </div>

            <div className="space-y-2">
              <Label htmlFor="lockInterval">Lock Interval (seconds)</Label>
              <Input
                id="lockInterval"
                placeholder="604800"
                value={formData.lockInterval}
                onChange={(e) => handleChange('lockInterval', e.target.value)}
                required
              />
              <p className="text-xs text-gray-500">
                Duration of one lock interval in seconds (e.g., 604800 = 1 week)
              </p>
            </div>

            <div className="space-y-2">
              <Label htmlFor="decayCurveType">Decay Curve Type</Label>
              <Select
                value={formData.decayCurveType}
                onValueChange={(value) => handleChange('decayCurveType', value)}
              >
                <SelectTrigger>
                  <SelectValue placeholder="Select curve type" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="0">Linear (0)</SelectItem>
                  <SelectItem value="1">Exponential (1)</SelectItem>
                </SelectContent>
              </Select>
              <p className="text-xs text-gray-500">
                Type of decay curve for lock-up bonuses
              </p>
            </div>

            <div className="space-y-2">
              <Label htmlFor="decayCurveParameters">Curve Parameter</Label>
              <Input
                id="decayCurveParameters"
                placeholder="1000000000000000000"
                value={formData.decayCurveParameters[0]}
                onChange={(e) => handleChange('decayCurveParameters', [e.target.value])}
                required
              />
              <p className="text-xs text-gray-500">
                {formData.decayCurveType === '0'
                  ? 'Linear: 1.0 (1e18) means weight decays at linear rate proportional to lockup length'
                  : 'Exponential: 0.9 (9e17) means weight decays with previous period multiplied by 0.9'}
              </p>
            </div>

            <div className="flex justify-end gap-2 pt-4">
              <DrawerClose asChild>
                <Button variant="outline">Cancel</Button>
              </DrawerClose>
              <Button
                type="submit"
                disabled={!isConnected || isLoading}
              >
                {isLoading ? 'Deploying...' : 'Deploy Contract'}
              </Button>
            </div>
          </form>
        </div>
      </DrawerContent>
    </Drawer>
  )
}
