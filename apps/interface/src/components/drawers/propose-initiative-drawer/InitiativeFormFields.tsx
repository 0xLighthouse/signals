import { Trash2 } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'

export type AttachmentDraft = {
  uri: string
  mimeType: string
  description: string
}

const MAX_ATTACHMENTS = 5

type InitiativeFormFieldsProps = {
  title: string
  description: string
  attachments: AttachmentDraft[]
  onTitleChange: (value: string) => void
  onDescriptionChange: (value: string) => void
  onAddAttachment: () => void
  onAttachmentChange: (index: number, field: keyof AttachmentDraft, value: string) => void
  onRemoveAttachment: (index: number) => void
}

export function InitiativeFormFields({
  title,
  description,
  attachments,
  onTitleChange,
  onDescriptionChange,
  onAddAttachment,
  onAttachmentChange,
  onRemoveAttachment,
}: InitiativeFormFieldsProps) {
  return (
    <>
      <div className="my-2">
        <Label htmlFor="title">Title</Label>
        <Input
          id="title"
          placeholder='For example, "On-chain forums"'
          value={title}
          onChange={(e) => onTitleChange(e.target.value)}
        />
      </div>
      <div className="my-2">
        <Label htmlFor="description">Description</Label>
        <Textarea
          id="description"
          placeholder="Include details of your initiative. Remember to search for existing ideas first."
          required
          value={description}
          onChange={(e) => onDescriptionChange(e.target.value)}
          style={{ resize: 'none', height: '200px' }}
        />
      </div>
      <div className="my-4">
        <Label>Attachments</Label>
        <p className="text-sm text-muted-foreground mb-2">
          Optional supporting links or files. Provide a URI along with an optional MIME type and
          description.
        </p>
        {attachments.map((attachment, index) => (
          <div key={`attachment-${index}`} className="mb-4 rounded-md border p-4">
            <div className="flex flex-col gap-2 md:flex-row md:items-start md:gap-4">
              <div className="flex-1">
                <Label htmlFor={`attachment-uri-${index}`}>URI</Label>
                <Input
                  id={`attachment-uri-${index}`}
                  placeholder="https:// or ipfs://"
                  value={attachment.uri}
                  onChange={(e) => onAttachmentChange(index, 'uri', e.target.value)}
                />
              </div>
              <Button
                type="button"
                variant="ghost"
                size="icon"
                className="mt-2 self-start text-muted-foreground hover:text-foreground"
                onClick={() => onRemoveAttachment(index)}
                aria-label="Remove attachment"
              >
                <Trash2 size={16} />
              </Button>
            </div>
            <div className="mt-2 grid gap-2 md:grid-cols-2">
              <div>
                <Label htmlFor={`attachment-mime-${index}`}>MIME type</Label>
                <Input
                  id={`attachment-mime-${index}`}
                  placeholder="application/pdf"
                  value={attachment.mimeType}
                  onChange={(e) => onAttachmentChange(index, 'mimeType', e.target.value)}
                />
              </div>
              <div>
                <Label htmlFor={`attachment-description-${index}`}>Description</Label>
                <Input
                  id={`attachment-description-${index}`}
                  placeholder="Short description"
                  value={attachment.description}
                  onChange={(e) => onAttachmentChange(index, 'description', e.target.value)}
                />
              </div>
            </div>
          </div>
        ))}
        <Button
          type="button"
          variant="outline"
          onClick={onAddAttachment}
          disabled={attachments.length >= MAX_ATTACHMENTS}
        >
          Add attachment
        </Button>
      </div>
    </>
  )
}

export { MAX_ATTACHMENTS }
