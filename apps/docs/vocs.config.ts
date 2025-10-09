import { defineConfig } from 'vocs'
import { navGenerator } from './lib/navgen'
import rehypeKatex from 'rehype-katex'
import remarkMath from 'remark-math'

// Usage: pass a subdirectory (within docs/pages) to the navGenerator to generate links for all files in that directory
const nav = new navGenerator(__dirname)

export default defineConfig({
  aiCta: false,
  title: 'Signals Docs',
  description: 'Signals - Community-driven initiative governance with token-weighted voting',
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
    {
      text: 'Features',
      collapsed: false,
      items: nav.navItems('/features'),
    },
    {
      text: 'Reference',
      collapsed: false,
      items: nav.navItems('/reference'),
    },
    {
      text: 'Components',
      collapsed: false,
      items: nav.navItems('/components'),
    },
  ],
})
