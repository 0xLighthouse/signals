'use client'

import * as React from 'react'
import { ChevronsUpDown } from 'lucide-react'

import { Button } from '@/components/ui/button'
import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
} from '@/components/ui/command'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import { UsdcIcon } from './icons/usdc'

const tokens = [
  {
    value: 'usdc',
    label: 'USDC',
    icon: <UsdcIcon />,
  },
]

interface Props {
  onTokenSelect: (token: string) => void
}

export function TokenSelector({ onTokenSelect }: Props) {
  const [open, setOpen] = React.useState(false)
  const [value, setValue] = React.useState('usdc') // Set default token to 'usdc'

  const handleSelect = (currentValue: string) => {
    const newValue = currentValue === value ? '' : currentValue
    setValue(newValue)
    setOpen(false)
    if (onTokenSelect) {
      onTokenSelect(newValue) // Call the callback with the selected token
    }
  }

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <Button
          variant="outline"
          // biome-ignore lint/a11y/useSemanticElements: <explanation>
          role="combobox"
          aria-expanded={open}
          className="w-full justify-between"
        >
          <div className="flex items-center gap-2">
            {value ? tokens.find((token) => token.value === value)?.icon : undefined}
            {value ? tokens.find((token) => token.value === value)?.label : 'Select token...'}
          </div>
          <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
        </Button>
      </PopoverTrigger>
      <PopoverContent className="w-full p-0">
        <Command>
          <CommandInput placeholder="Search token..." />
          <CommandList>
            <CommandEmpty>No token found.</CommandEmpty>
            <CommandGroup>
              {tokens.map((token) => (
                <CommandItem
                  key={token.value}
                  value={token.value}
                  onSelect={handleSelect} // Use the new handleSelect function
                >
                  <div className="mr-2">{token.icon}</div>
                  {/* <Check
                    className={cn(
                      'mr-2 h-4 w-4',
                      value === token.value ? 'opacity-100' : 'opacity-0',
                    )}
                  /> */}
                  {token.label}
                </CommandItem>
              ))}
            </CommandGroup>
          </CommandList>
        </Command>
      </PopoverContent>
    </Popover>
  )
}
