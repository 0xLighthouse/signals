import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { InitiativeAttachments } from './InitiativeAttachments'

export type AttachmentDraft = {
  uri: string
  mimeType: string
  description: string
}

export const MAX_ATTACHMENTS = 5

type InitiativeFormFieldsProps = {
  title: string
  description: string
  attachments: AttachmentDraft[]
  onTitleChange: (value: string) => void
  onDescriptionChange: (value: string) => void
  onAddAttachment: (attachment: AttachmentDraft) => void
  onRemoveAttachment: (index: number) => void
}

export function InitiativeFormFields({
  title,
  description,
  attachments,
  onTitleChange,
  onDescriptionChange,
  onAddAttachment,
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
      <InitiativeAttachments
        attachments={attachments}
        onAddAttachment={onAddAttachment}
        onRemoveAttachment={onRemoveAttachment}
      />
    </>
  )
}
