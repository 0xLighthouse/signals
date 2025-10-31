import type React from 'react'

import { BaseIcon } from '@/components/icons/base'
import { FoundryIcon } from '@/components/icons/foundry'
import { ArbitrumIcon } from '@/components/icons/arbitrum'
import { Button } from '@/components/ui/button'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { useNetwork } from '@/hooks/useNetwork'
import { useWeb3 } from '@/contexts/Web3Provider'
import type { SupportedNetworks } from '@/config/network-types'
import { NETWORKS, ZERO_ADDRESS } from '@/config/web3'
import { toast } from 'sonner'

import { useInitiativesStore } from '@/stores/useInitiativesStore'
import { useBondsStore } from '@/stores/useBondsStore'
import { usePoolsStore } from '@/stores/usePoolsStore'
import { useRewardsStore } from '@/stores/useRewardsStore'

const OptimismIcon = (props: React.SVGProps<SVGSVGElement>) => (
  <svg
    viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg"
    role="img"
    aria-hidden="true"
    {...props}
  >
    <rect width="32" height="32" rx="16" fill="#FF0420" />
    <text x="16" y="19" fontSize="10" fontWeight="bold" textAnchor="middle" fill="white">
      OP
    </text>
  </svg>
)

const EthereumIcon = (props: React.SVGProps<SVGSVGElement>) => (
  <svg
    viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg"
    role="img"
    aria-hidden="true"
    {...props}
  >
    <rect width="32" height="32" rx="16" fill="#627EEA" />
    <path d="M16 6L22 16L16 19.5L10 16L16 6Z" fill="white" />
    <path d="M16 20L22 17L16 26L10 17L16 20Z" fill="white" opacity="0.75" />
  </svg>
)

const disabledNetworks = [
  {
    key: 'arbitrum',
    label: 'Arbitrum',
    description: 'Coming soon',
    Icon: ArbitrumIcon,
  },
  {
    key: 'optimism',
    label: 'Optimism',
    description: 'Coming soon',
    Icon: OptimismIcon,
  },
  {
    key: 'ethereum',
    label: 'Ethereum',
    description: 'Coming soon',
    Icon: EthereumIcon,
  },
]

const resetStoresForNetworkChange = () => {
  useInitiativesStore.getState().reset()
  useBondsStore.getState().reset()
  usePoolsStore.getState().reset()
  useRewardsStore.getState().reset()
}

export function NetworkSwitcherDialog({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { selected, setNetwork } = useNetwork()
  const { walletClient } = useWeb3()

  const handleSelectBase = async () => {
    const networkKey: SupportedNetworks = 'base'
    const networkConfig = NETWORKS[networkKey]
    const factoryAddress = networkConfig.contracts.SignalsFactory.address

    const isNetworkConfigured =
      networkConfig.rpcUrl && factoryAddress && factoryAddress !== ZERO_ADDRESS

    if (!isNetworkConfigured) {
      toast(
        `${networkKey} network configuration is unavailable. Please set the required environment variables.`,
      )
      return
    }

    if (selected === networkKey) {
      onOpenChange(false)
      return
    }

    setNetwork(networkKey)
    resetStoresForNetworkChange()

    try {
      await walletClient?.switchChain?.({ id: networkConfig.chain.id })
    } catch (error) {
      console.warn('Wallet chain switch failed', error)
      toast(`Please switch your wallet to ${networkConfig.chain.name} in your wallet`)
    }

    onOpenChange(false)
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Select network</DialogTitle>
          <DialogDescription>
            Choose which network to explore in the Signals interface.
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-6">
          <div className="space-y-2">
            <button
              type="button"
              onClick={handleSelectBase}
              className="w-full flex items-center justify-between rounded-lg border border-neutral-800 bg-neutral-900 px-4 py-3 transition hover:border-neutral-700 hover:bg-neutral-800"
            >
              <div className="flex items-center gap-3">
                <BaseIcon className="h-6 w-6" />
                <div className="text-left">
                  <div className="font-medium text-sm">Base</div>
                  <div className="text-xs text-muted-foreground">Switch to Base mainnet</div>
                </div>
              </div>
              <span className="text-xs uppercase tracking-wide text-blue-400">
                {selected === 'base' ? 'Selected' : 'Switch'}
              </span>
            </button>
          </div>

          <div className="space-y-2">
            {disabledNetworks.map(({ key, label, description, Icon }) => (
              <div
                key={key}
                className="w-full flex items-center justify-between rounded-lg border border-neutral-800 px-4 py-3 opacity-60"
              >
                <div className="flex items-center gap-3">
                  {/* <Icon className="h-6 w-6 opacity-80" /> */}
                  <div className="text-left">
                    <div className="font-medium text-sm">{label}</div>
                    <div className="text-xs text-muted-foreground">{description}</div>
                  </div>
                </div>
                <span className="text-xs uppercase tracking-wide text-muted-foreground">
                  Coming soon
                </span>
              </div>
            ))}
          </div>

          <div className="rounded-lg border border-neutral-800 bg-neutral-900 px-4 py-3 flex items-start gap-3">
            <FoundryIcon className="h-8 w-8 shrink-0" />
            <div className="space-y-2">
              <div className="text-sm font-medium">Join the community</div>
              <div className="text-xs text-muted-foreground">
                Stay tuned for upcoming network launches and incentives.
              </div>
              <Button variant="outline" className="h-8 text-xs" asChild>
                <a href="https://t.me/+RwIDvvzM4fQzZmM0" target="_blank" rel="noreferrer">
                  Join us on Telegram
                </a>
              </Button>
            </div>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  )
}
