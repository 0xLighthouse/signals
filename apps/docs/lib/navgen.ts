import fs from 'node:fs'
import path from 'node:path'
import fm from 'front-matter'

interface Metadata {
  title: string
  weight: number
}

interface MDXDoc {
  basename: string
  metadata: Metadata
}

export class navGenerator {
  constructor(private docsdir: string) {
    this.docsdir = `${docsdir}/pages`
  }

  // pass in a full file path to return the metadata
  parseMetadata(filePath: string) {
    const data = fs.readFileSync(filePath, 'utf-8')
    const content = fm(data).attributes as Record<string, any>

    return {
      title: content.title || path.basename(filePath, path.extname(filePath)),
      weight: content.weight || 0,
    }
  }

  // pass in full directory path to read .mdx and .md files
  readMdxFiles(directory: string): MDXDoc[] {
    const files = fs.readdirSync(directory)
    return files
      .filter((file) => ['.mdx', '.md'].includes(path.extname(file))) // Filter .mdx and .md files
      .map((file) => {
        const ext = path.extname(file)
        return {
          basename: path.basename(file, ext),
          metadata: this.parseMetadata(path.join(directory, file)),
        }
      })
  }

  // pass in a subdirectory (under docs/pages) to return the nav items
  navItems(subdir: string): { text: string; link: string }[] {
    const items = this.readMdxFiles(`${this.docsdir}/${subdir}`)
    return items
      .map((item) => {
        return {
          text: item.metadata.title,
          link: `${subdir}/${item.basename}`,
          weight: Number(item.metadata.weight),
        }
      })
      .sort((a, b) => a.weight - b.weight) //
  }
}
