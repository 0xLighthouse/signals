import { PuffLoader } from 'react-spinners'
import { UITheme } from '@/config/theme'
import { useTheme } from '@/contexts/ThemeContext'

type LoadingSpinnerProps = {
  size?: number
  speedMultiplier?: number
}

export const LoadingSpinner = ({ size = 38, speedMultiplier = 2.6 }: LoadingSpinnerProps) => {
  const { theme } = useTheme()

  return (
    <div className="flex justify-center items-center">
      <PuffLoader
        color={theme === UITheme.DARK ? '#fff' : '#000'}
        size={size}
        speedMultiplier={speedMultiplier}
      />
    </div>
  )
}
