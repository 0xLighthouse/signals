import React from 'react'

interface IconButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {}

export const IconButton: React.FC<IconButtonProps> = ({ children, ...props }) => {
  return (
    <button className="p-4 rounded-full w-[36px]" {...props}>
      {children}
    </button>
  )
}
