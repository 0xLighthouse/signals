'use client'

import { cn, shortAddress } from '@/lib/utils'
import { Check, ChevronsUpDown } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
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
import { useBoard } from '@/contexts/BoardContext'
import { useNetwork } from '@/hooks/useNetwork'

interface BoardSelectorProps {
  onDeployBoard: () => void
  onBoardSelect?: (boardAddress: string) => void
}

export function BoardSelector({ onDeployBoard, onBoardSelect }: BoardSelectorProps) {
  const { boards, isBoardsLoading, selectedBoard, setActiveBoard } = useBoard()
  const [open, setOpen] = useState(false)
  const { config } = useNetwork()

  // Options derived from context boards + deploy shortcut
  const boardOptions = useMemo(
    () =>
      boards.map((b) => ({
        value: b.contractAddress.toLowerCase(),
        label: shortAddress(b.contractAddress),
      })),
    [boards],
  )

  const options = useMemo(
    () => [...boardOptions, { value: 'deploy', label: 'Deploy new board' }],
    [boardOptions],
  )

  const handleSelect = async (value: string) => {
    if (value === 'deploy') {
      onDeployBoard()
      setOpen(false)
      return
    }

    // Switch board via context and bubble up
    await setActiveBoard(value as `0x${string}`)
    if (onBoardSelect) {
      onBoardSelect(value)
    }
    setOpen(false)
  }

  const selectedLabel =
    options.find((option) => option.value === selectedBoard)?.label ||
    (config.contracts.SignalsProtocol?.address
      ? shortAddress(config.contracts.SignalsProtocol.address)
      : 'Select board')

  // Close popover on outside state changes to avoid stale UI
  useEffect(() => {
    if (!open) return
    // when boards change, keep popover consistent
  }, [boards, open])

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
            <CommandEmpty>{isBoardsLoading ? 'Loading...' : 'No board found.'}</CommandEmpty>
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
