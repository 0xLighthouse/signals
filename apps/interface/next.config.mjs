/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    staleTimes: {
      dynamic: process.env.NEXT_PUBLIC_SIGNALS_ENV === 'dev' ? 0 : 30,
      static: process.env.NEXT_PUBLIC_SIGNALS_ENV === 'dev' ? 0 : 180,
    },
  },
}

export default nextConfig
