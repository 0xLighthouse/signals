import { Wallet } from '@phosphor-icons/react'
import { Card, CardContent, CardFooter, CardHeader, CardTitle } from '../ui/card'
import { GradientConnectButton } from './gradient-connect-button'

export const ConnectCTAPanel = () => {
  return (
    <Card className="w-full bg-gradient-to-r from-gray-50 to-gray-150 text-gray-800 dark:from-slate-800 dark:to-slate-900 dark:text-slate-100 dark:shadow-lg border border-gray-200 dark:border-slate-700">
      <CardHeader className="space-y-1">
        <CardTitle className="text-2xl font-bold flex items-center justify-center">
          <Wallet className="mr-2 h-6 w-6" aria-hidden="true" />
          Connect Your Wallet
        </CardTitle>
      </CardHeader>
      <CardContent>
        <p className="mb-4 text-gray-700 dark:text-slate-300">
          Unlock the full potential of our platform by connecting your wallet. Submit ideas, vote,
          and participate in the community!
        </p>
        <ul className="space-y-2 text-gray-700 dark:text-slate-300">
          <li className="flex items-center">
            <svg
              className="w-4 h-4 mr-2 fill-current text-green-400"
              viewBox="0 0 20 20"
              aria-hidden="true"
            >
              <path d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" />
            </svg>
            Submit your innovative ideas
          </li>
          <li className="flex items-center">
            <svg
              className="w-4 h-4 mr-2 fill-current text-green-400"
              viewBox="0 0 20 20"
              aria-hidden="true"
            >
              <path d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" />
            </svg>
            Vote on community proposals
          </li>
          <li className="flex items-center">
            <svg
              className="w-4 h-4 mr-2 fill-current text-green-400"
              viewBox="0 0 20 20"
              aria-hidden="true"
            >
              <path d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" />
            </svg>
            Engage with the blockchain community
          </li>
        </ul>
      </CardContent>
      <CardFooter>
        <GradientConnectButton />
      </CardFooter>
    </Card>
  )
}
