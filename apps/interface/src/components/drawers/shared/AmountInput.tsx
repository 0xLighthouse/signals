import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'

type AmountInputProps = {
  amount: number | string
  symbol?: string
  minAmount?: number | null
  showMinimum?: boolean
  showError?: boolean
  errorMessage?: string
  helperText?: string
  onAmountChange: (value: number) => void
}

export function AmountInput({
  amount,
  symbol,
  minAmount,
  showMinimum = false,
  showError = false,
  errorMessage,
  helperText,
  onAmountChange,
}: AmountInputProps) {
  return (
    <div className="flex flex-col gap-2">
      <div className="flex items-center">
        <Label className="w-1/5 flex items-center" htmlFor="amount">
          Amount
        </Label>
        <div className="w-4/5">
          <Input
            id="amount"
            type="number"
            value={amount ?? ''}
            onChange={(e) => onAmountChange(e.target.value ? Number(e.target.value) : 0)}
            min={minAmount ?? 0}
          />
        </div>
      </div>
      {showError && errorMessage && (
        <div className="flex">
          <div className="w-1/5"></div>
          <div className="w-4/5">
            <Label className="text-red-500">{errorMessage}</Label>
          </div>
        </div>
      )}
      {showMinimum && minAmount != null && minAmount > 0 && (
        <div className="flex">
          <div className="w-1/5"></div>
          <div className="w-4/5">
            <Label className="text-sm text-muted-foreground">
              Minimum: {minAmount.toLocaleString()} {symbol}
            </Label>
          </div>
        </div>
      )}
      {helperText && (
        <div className="flex">
          <div className="w-1/5"></div>
          <div className="w-4/5">
            <Label className="text-sm text-muted-foreground">{helperText}</Label>
          </div>
        </div>
      )}
    </div>
  )
}
