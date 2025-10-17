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
      text: 'Use Cases',
      link: '/use-cases',
    },
    {
      text: 'Signals Boards',
      collapsed: false,
      items: nav.navItems('/signals-board'),
    },
    {
      text: 'Initiatives',
      collapsed: false,
      items: nav.navItems('/initiatives'),
    },
    {
      text: 'Rewards and Incentives',
      collapsed: false,
      items: nav.navItems('/rewards-and-incentives'),
    },
    {
      text: 'Developer Reference',
      collapsed: false,
      items: [
        {
          text: 'Board Configuration',
          collapsed: true,
          items: [
            ...nav.navItems('/reference/board-configuration'),
            {
              text: 'Post Deployment Configuration',
              collapsed: true,
              items: nav.navItems('/reference/board-configuration/post-deployment-configuration'),
            },
          ],
        },
        {
          text: 'Initiative Interactions',
          link: '/reference/initiative-interactions',
          collapsed: true,
          items: nav.navItems('/reference/initiative-functions'),
        },
      ],
    }
  ],
})
