import { Button } from '@/components/ui/button'
import { Drawer, DrawerContent, DrawerTrigger } from '@/components/ui/drawer'
import { useAccount } from '@/hooks/useAccount'
import { useState } from 'react'
import { toast } from 'sonner'
import { TextInput } from '../inputs'
import { DrawerHeader, DrawerTitle } from '@/components/ui/drawer'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { DrawerClose } from '@/components/ui/drawer'
import { Label } from '@/components/ui/label'

export function DeploySignalsDrawer({
  isOpen,
  onOpenChange,
  hideTrigger,
}: { isOpen: boolean; onOpenChange: (open: boolean) => void; hideTrigger: boolean }) {
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
    decayCurveParameters: ['1000000000000000000'], // 1.0 as a decimal with 18 decimals
  })

  const handleChange = (field: string, value: string) => {
    setFormData((prev) => ({
      ...prev,
      [field]: value,
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
        decayCurveParameters: ['1000000000000000000'],
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
      {/* <DrawerTrigger hidden={true} asChild>
        <Button variant="outline" onClick={() => onOpenChange(true)}>
          Deploy Contract
        </Button>
      </DrawerTrigger> */}
      <DrawerContent className="h-[90vh] max-h-[90vh] overflow-hidden">
        <DrawerHeader>
          <DrawerTitle>Deploy Signals Contract</DrawerTitle>
        </DrawerHeader>
        <form onSubmit={handleSubmit} className="p-4 md:p-8 overflow-y-auto">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 md:gap-6 lg:gap-8">
            <div>
              <TextInput
                id="owner"
                label="Owner Address"
                placeholder="0x..."
                value={formData.owner || address}
                onChange={(value) => handleChange('owner', value)}
                description="The address that will own the new contract"
              />

              <TextInput
                id="underlyingToken"
                label="Governance Token Address"
                placeholder="0x..."
                value={formData.underlyingToken}
                onChange={(value) => handleChange('underlyingToken', value)}
                description="An ERC20 token address that will be used for lockups"
                required
              />

              <TextInput
                id="proposalThreshold"
                label="Proposal Threshold"
                placeholder="1000000000000000000"
                value={formData.proposalThreshold}
                onChange={(value) => handleChange('proposalThreshold', value)}
                description="Minimum token balance required to submit an initiative (in wei)"
                required
              />
            </div>

            <div>
              <TextInput
                id="acceptanceThreshold"
                label="Acceptance Threshold"
                placeholder="10000000000000000000"
                value={formData.acceptanceThreshold}
                onChange={(value) => handleChange('acceptanceThreshold', value)}
                description="Support required before an initiative can be accepted (in wei)"
                required
              />

              <TextInput
                id="maxLockIntervals"
                label="Max Lock Intervals"
                placeholder="12"
                value={formData.maxLockIntervals}
                onChange={(value) => handleChange('maxLockIntervals', value)}
                description="Maximum number of intervals funds can be locked"
                required
              />

              <TextInput
                id="proposalCap"
                label="Proposal Cap"
                placeholder="100"
                value={formData.proposalCap}
                onChange={(value) => handleChange('proposalCap', value)}
                description="Maximum number of proposals allowed"
                required
              />
            </div>

            <div className="md:col-span-2 lg:col-span-1">
              <TextInput
                id="lockInterval"
                label="Lock Interval (seconds)"
                placeholder="604800"
                value={formData.lockInterval}
                onChange={(value) => handleChange('lockInterval', value)}
                description="Duration of one lock interval in seconds (e.g., 604800 = 1 week)"
                required
              />

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
                <p className="text-xs text-gray-500">Type of decay curve for lock-up bonuses</p>
              </div>

              <TextInput
                id="decayCurveParameters"
                label="Curve Parameter"
                placeholder="1000000000000000000"
                value={formData.decayCurveParameters[0]}
                // TODO: fix this
                // @ts-ignore
                onChange={(value) => handleChange('decayCurveParameters', [value])}
                description={
                  formData.decayCurveType === '0'
                    ? 'Linear: 1.0 (1e18) means weight decays at linear rate proportional to lockup length'
                    : 'Exponential: 0.9 (9e17) means weight decays with previous period multiplied by 0.9'
                }
                required
              />
            </div>
          </div>

          <div className="flex justify-end gap-2 pt-6 md:pt-8">
            <DrawerClose asChild>
              <Button variant="outline">Cancel</Button>
            </DrawerClose>
            <Button type="submit" disabled={!isConnected || isLoading}>
              {isLoading ? 'Deploying...' : 'Deploy Contract'}
            </Button>
          </div>
        </form>
      </DrawerContent>
    </Drawer>
  )
}
