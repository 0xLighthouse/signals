import { useState } from 'react'
import type { LucideIcon } from 'lucide-react'
import {
  FileText,
  Image,
  FileCode,
  FileSpreadsheet,
  Film,
  Music,
  Archive,
  File,
  Paperclip,
  Trash2,
} from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog'
import type { AttachmentDraft } from './InitiativeFormFields'
import { MAX_ATTACHMENTS } from './InitiativeFormFields'

const MIME_TYPES: { value: string; label: string; icon: LucideIcon }[] = [
  { value: 'application/pdf', label: 'PDF', icon: FileText },
  { value: 'image/png', label: 'PNG Image', icon: Image },
  { value: 'image/jpeg', label: 'JPEG Image', icon: Image },
  { value: 'image/svg+xml', label: 'SVG Image', icon: Image },
  { value: 'image/gif', label: 'GIF Image', icon: Image },
  { value: 'image/webp', label: 'WebP Image', icon: Image },
  { value: 'text/plain', label: 'Plain Text', icon: FileText },
  { value: 'text/html', label: 'HTML', icon: FileCode },
  { value: 'text/markdown', label: 'Markdown', icon: FileText },
  { value: 'text/csv', label: 'CSV', icon: FileSpreadsheet },
  { value: 'application/json', label: 'JSON', icon: FileCode },
  { value: 'application/xml', label: 'XML', icon: FileCode },
  { value: 'video/mp4', label: 'MP4 Video', icon: Film },
  { value: 'audio/mpeg', label: 'MP3 Audio', icon: Music },
  { value: 'application/zip', label: 'ZIP Archive', icon: Archive },
]

function getMimeIcon(mimeType: string): LucideIcon {
  const entry = MIME_TYPES.find((t) => t.value === mimeType)
  if (entry) return entry.icon
  if (mimeType.startsWith('image/')) return Image
  if (mimeType.startsWith('video/')) return Film
  if (mimeType.startsWith('audio/')) return Music
  if (mimeType.startsWith('text/')) return FileText
  return File
}

type InitiativeAttachmentsProps = {
  attachments: AttachmentDraft[]
  onAddAttachment: (attachment: AttachmentDraft) => void
  onRemoveAttachment: (index: number) => void
}

export function InitiativeAttachments({
  attachments,
  onAddAttachment,
  onRemoveAttachment,
}: InitiativeAttachmentsProps) {
  const [open, setOpen] = useState(false)
  const [uri, setUri] = useState('')
  const [mimeType, setMimeType] = useState('')
  const [description, setDescription] = useState('')

  const resetFields = () => {
    setUri('')
    setMimeType('')
    setDescription('')
  }

  const handleAdd = () => {
    onAddAttachment({ uri, mimeType, description })
    resetFields()
    setOpen(false)
  }

  return (
    <div className="my-4">
      {attachments.length > 0 && (
        <div className="mb-3 space-y-2">
          {attachments.map((attachment, index) => (
            <div
              key={`attachment-${index}`}
              className="flex items-center gap-2 rounded-md border border-stone-200 dark:border-stone-700 px-3 py-2"
            >
              {(() => {
                const Icon = attachment.mimeType ? getMimeIcon(attachment.mimeType) : Paperclip
                return <Icon size={14} className="shrink-0 text-muted-foreground" />
              })()}
              <span className="flex-1 truncate text-body-sm">
                {attachment.uri}
                {attachment.description ? ` — ${attachment.description}` : ''}
              </span>
              <Button
                type="button"
                variant="ghost"
                size="icon"
                className="h-6 w-6 shrink-0 text-muted-foreground hover:text-foreground"
                onClick={() => onRemoveAttachment(index)}
                aria-label="Remove attachment"
              >
                <Trash2 size={14} />
              </Button>
            </div>
          ))}
        </div>
      )}

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogTrigger asChild>
          <Button
            type="button"
            variant="ghost"
            size="sm"
            className="text-muted-foreground"
            disabled={attachments.length >= MAX_ATTACHMENTS}
          >
            <Paperclip size={14} />
            Add attachment
          </Button>
        </DialogTrigger>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Add attachment</DialogTitle>
            <DialogDescription>
              Provide a URI along with an optional MIME type and description.
            </DialogDescription>
          </DialogHeader>
          <div className="flex flex-col gap-4">
            <div>
              <Label htmlFor="attachment-uri">URI</Label>
              <Input
                id="attachment-uri"
                placeholder="https:// or ipfs://"
                value={uri}
                onChange={(e) => setUri(e.target.value)}
              />
            </div>
            <div>
              <Label htmlFor="attachment-mime">MIME type</Label>
              <Select value={mimeType} onValueChange={setMimeType}>
                <SelectTrigger id="attachment-mime">
                  <SelectValue placeholder="Select a type" />
                </SelectTrigger>
                <SelectContent className="z-[100]">
                  {MIME_TYPES.map((type) => (
                    <SelectItem key={type.value} value={type.value}>
                      <span className="flex items-center gap-2">
                        <type.icon size={14} className="text-muted-foreground" />
                        {type.label}
                      </span>
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div>
              <Label htmlFor="attachment-desc">Description</Label>
              <Textarea
                id="attachment-desc"
                placeholder="Describe this attachment"
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                style={{ resize: 'none', height: '80px' }}
              />
            </div>
          </div>
          <DialogFooter>
            <Button onClick={handleAdd} disabled={!uri.trim()}>
              Add
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
