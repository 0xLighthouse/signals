import { defineConfig } from 'vocs'
import { navGenerator } from './lib/navgen'
import rehypeKatex from 'rehype-katex'
import remarkMath from 'remark-math'

// Usage: pass a subdirectory (within docs/pages) to the navGenerator to generate links for all files in that directory
const nav = new navGenerator(__dirname)

export default defineConfig({
  aiCta: false,
  title: 'Harbor Docs',
  description: 'Harbor - A Uniswap V4 bond trading protocol',
  logoUrl: '/logo.png',
  iconUrl: '/favicon.ico',
  rootDir: '.',
  markdown: {
    rehypePlugins: [rehypeKatex],
    remarkPlugins: [remarkMath],
  },
  sidebar: [
    {
      text: 'Introduction',
      link: '/',
    },
    // {
    //   text: 'Quickstart',
    //   link: '/quick-start',
    // },
    {
      text: 'Components',
      collapsed: false,
      items: nav.navItems('/components'),
    },
    {
      text: 'Architecture',
      collapsed: false,
      items: nav.navItems('/architecture'),
    },
  ],
})
