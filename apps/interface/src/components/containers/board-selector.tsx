'use client'

import { context } from '@/config/web3'
import { useBoardAutocomplete } from '@/hooks/useBoardAutocomplete'
import { cn, shortAddress } from '@/lib/utils'
import { Check, ChevronsUpDown } from 'lucide-react'
import { useEffect, useState } from 'react'
import { Button } from '../ui/button'
import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
} from '../ui/command'
import { Popover, PopoverContent, PopoverTrigger } from '../ui/popover'

interface BoardSelectorProps {
  onDeployBoard: () => void
  onBoardSelect?: (boardAddress: string) => void
}

export function BoardSelector({ onDeployBoard, onBoardSelect }: BoardSelectorProps) {
  const { boards, isLoading } = useBoardAutocomplete()
  const [open, setOpen] = useState(false)
  const [selectedBoard, setSelectedBoard] = useState('')

  // Initially set the current board address as selected
  useEffect(() => {
    if (context.contracts.SignalsProtocol.address) {
      setSelectedBoard(context.contracts.SignalsProtocol.address.toLowerCase())
    }
  }, [])

  // Format boards for the combobox
  const boardOptions =
    boards?.map((board) => ({
      value: board.contractAddress.toLowerCase(),
      label: shortAddress(board.contractAddress),
    })) || []

  // Add option to deploy a new board
  const options = [...boardOptions, { value: 'deploy', label: 'Deploy new board' }]

  const handleSelect = (value: string) => {
    if (value === 'deploy') {
      onDeployBoard()
      setOpen(false)
      return
    }

    setSelectedBoard(value)
    if (onBoardSelect) {
      onBoardSelect(value)
    }
    setOpen(false)
  }

  const selectedLabel =
    options?.find((option) => option.value === selectedBoard)?.label ||
    shortAddress(context.contracts.SignalsProtocol.address)

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <Button
          variant="outline"
          role="combobox"
          aria-expanded={open}
          className="w-[200px] justify-between"
        >
          {selectedLabel}
          <ChevronsUpDown className="h-4 w-4 shrink-0 opacity-50" />
        </Button>
      </PopoverTrigger>
      <PopoverContent className="w-[200px] p-0">
        <Command>
          <CommandInput placeholder="Search board..." className="h-9" />
          <CommandList>
            <CommandEmpty>{isLoading ? 'Loading...' : 'No board found.'}</CommandEmpty>
            <CommandGroup>
              {options.map((option) => (
                <CommandItem key={option.value} value={option.value} onSelect={handleSelect}>
                  {option.label}
                  <Check
                    className={cn(
                      'ml-auto h-4 w-4',
                      selectedBoard === option.value ? 'opacity-100' : 'opacity-0',
                    )}
                  />
                </CommandItem>
              ))}
            </CommandGroup>
          </CommandList>
        </Command>
      </PopoverContent>
    </Popover>
  )
}
