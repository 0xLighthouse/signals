import { FC } from 'react'
import { Avatar, AvatarFallback, AvatarImage } from './avatar'

interface AvatarGroupProps {
  avatars?: string[] | undefined // Array of avatar image URLs
  max?: number // Maximum number of avatars to display before showing "+X"
}

export const AvatarGroup: FC<AvatarGroupProps> = ({ avatars, max = 4 }) => {
  if (!avatars) {
    return null
  }

  const displayedAvatars = avatars.slice(0, max)
  const extraCount = avatars.length - max

  return (
    <div className="flex -space-x-1">
      {displayedAvatars.map((src, index) => (
        <Avatar key={index} className="h-5 w-5">
          <AvatarImage src={src} alt={`Avatar ${index + 1}`} />
          <AvatarFallback>{src ? null : 'User'}</AvatarFallback>
        </Avatar>
      ))}
      {extraCount > 0 && (
        <Avatar className="bg-neutral-500 dark:bg-neutral-700 flex items-center justify-center h-[1.37rem] w-[1.37rem]">
          <span className="text-xs text-white">+{extraCount}</span>
        </Avatar>
      )}
    </div>
  )
}
