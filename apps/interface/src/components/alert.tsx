'use client'

import { BellRinging } from "@phosphor-icons/react"
import {
  Alert,
  AlertDescription,
  AlertTitle,
} from "@/components/ui/alert"

export function AlertDemo() {
  return (
    <Alert className="m-4">
      <BellRinging className="h-6 w-6" />
      <AlertTitle>Heads up!</AlertTitle>
      <AlertDescription>
        Please note this is a demo and the functionality is evolving daily.
      </AlertDescription>
    </Alert>
  )
}
