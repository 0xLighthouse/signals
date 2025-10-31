import * as React from 'react'

export const FoundryIcon: React.FC<React.SVGProps<SVGSVGElement>> = (props) => (
  <svg
    viewBox="0 0 32 32"
    xmlns="http://www.w3.org/2000/svg"
    role="img"
    aria-hidden="true"
    {...props}
  >
    <rect width="32" height="32" rx="16" fill="#FF7A00" />
    <path
      d="M10 21c0-2.761 2.239-5 5-5h2c2.761 0 5 2.239 5 5h2c0-3.866-3.134-7-7-7h-2c-3.866 0-7 3.134-7 7h2Z"
      fill="white"
    />
    <path d="M14 11h4l1 5h-6l1-5Z" fill="white" />
  </svg>
)
