'use client'

import * as React from 'react'
import { Check, ChevronsUpDown } from 'lucide-react'
import { NetworkIcon } from '@web3icons/react'
import { useRouter } from 'next/navigation'

import { cn } from '@/lib/utils'
import { Button } from '@/components/ui/button'
import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandItem,
} from '@/components/ui/command'
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from '@/components/ui/popover'

import { SUPPORTED_NETWORKS } from '@/config/supported-networks'
import type { SupportedNetworks } from '@/config/network-types'
import { useNetworkStore } from '@/stores/useNetworkStore'
import { getNetworkUrl } from '@/lib/routing'

export function NetworkSwitcher() {
  const [open, setOpen] = React.useState(false)
  const selected = useNetworkStore((s) => s.selected)
  const setNetwork = useNetworkStore((s) => s.setNetwork)
  const router = useRouter()

  const current = SUPPORTED_NETWORKS.find((n) => n.key === selected)

  const handleSelect = (key: SupportedNetworks) => {
    if (key === selected) {
      setOpen(false)
      return
    }
    setNetwork(key)
    router.push(getNetworkUrl(key))
    setOpen(false)
  }

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <Button
          variant="outline"
          role="combobox"
          aria-expanded={open}
          aria-label="Switch network"
          className="gap-2 px-3"
        >
          {current && (
            <NetworkIcon
              name={current.iconVariant}
              variant="branded"
              className="h-4 w-4 shrink-0"
            />
          )}
          <span className="hidden sm:inline text-sm">{current?.label ?? 'Select network'}</span>
          <ChevronsUpDown className="h-3 w-3 shrink-0 opacity-50" />
        </Button>
      </PopoverTrigger>
      <PopoverContent className="w-52 p-0" align="end">
        <Command>
          <CommandEmpty>No networks found.</CommandEmpty>
          <CommandGroup>
            {SUPPORTED_NETWORKS.map((network) => (
              <CommandItem
                key={network.key}
                value={network.key}
                onSelect={() => handleSelect(network.key as SupportedNetworks)}
                className="gap-2"
              >
                <NetworkIcon
                  name={network.iconVariant}
                  variant="branded"
                  className="h-4 w-4 shrink-0"
                />
                <span>{network.label}</span>
                <Check
                  className={cn(
                    'ml-auto h-4 w-4',
                    selected === network.key ? 'opacity-100' : 'opacity-0',
                  )}
                />
              </CommandItem>
            ))}
          </CommandGroup>
        </Command>
      </PopoverContent>
    </Popover>
  )
}
