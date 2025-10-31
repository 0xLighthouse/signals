import * as React from 'react'

export const BaseIcon: React.FC<React.SVGProps<SVGSVGElement>> = (props) => (
  <svg
    viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg"
    role="img"
    aria-hidden="true"
    {...props}
  >
    <circle cx="16" cy="16" r="16" fill="#0052FF" />
    <circle cx="16" cy="16" r="6.5" fill="white" />
    <circle cx="16" cy="16" r="3.5" fill="#0052FF" />
  </svg>
)
