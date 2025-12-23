'use client'

import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { UserLocks } from '@/components/user-locks'

interface UserLocksDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
}

export function UserLocksDialog({ open, onOpenChange }: UserLocksDialogProps) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-2xl max-h-[80vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>Your Locks</DialogTitle>
          <DialogDescription>View and redeem your locked tokens for this board</DialogDescription>
        </DialogHeader>
        <UserLocks autoFetch={open} />
      </DialogContent>
    </Dialog>
  )
}
