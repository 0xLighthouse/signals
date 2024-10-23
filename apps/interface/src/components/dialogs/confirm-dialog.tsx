import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { useState } from 'react'

interface ConfirmDialogProps {
  isOpen?: boolean
  onOpenChange?: (open: boolean) => void
  title: string
  description: string
  confirmLabel?: string
  cancelLabel?: string
  onConfirm?: () => void
  onCancel?: () => void
  trigger?: React.ReactNode
}

export function ConfirmDialog({
  isOpen = false,
  onOpenChange = () => {},
  title,
  description,
  confirmLabel,
  cancelLabel,
  onConfirm,
  onCancel,
  trigger,
}: ConfirmDialogProps) {
  const [open, setOpen] = useState(isOpen)

  const handleOpenChange = (open: boolean) => {
    setOpen(open)
    onOpenChange(open)
  }

  return (
    <>
      <Dialog open={open} onOpenChange={handleOpenChange}>
        {trigger && <DialogTrigger asChild>{trigger}</DialogTrigger>}
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>{title}</DialogTitle>
            <DialogDescription>{description}</DialogDescription>
          </DialogHeader>
          <DialogFooter className="sm:justify-start">
            <DialogClose asChild>
              <Button
                type="button"
                variant="secondary"
                onClick={() => {
                  onCancel?.()
                  handleOpenChange(false)
                }}
              >
                {cancelLabel || 'Cancel'}
              </Button>
            </DialogClose>
            <Button
              type="button"
              onClick={() => {
                onConfirm?.()
                handleOpenChange(false)
              }}
            >
              {confirmLabel || 'Confirm'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  )
}
