import React from 'react';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from '@/components/ui/tooltip';
import { Info } from 'lucide-react';

interface FormInputProps {
  id: string;
  label: string;
  placeholder?: string;
  value?: string;
  defaultValue?: string;
  onChange?: (value: string) => void;
  description?: string;
  tooltip?: string;
  required?: boolean;
  className?: string;
}

export function TextInput({
  id,
  label,
  placeholder,
  value,
  defaultValue,
  onChange,
  description,
  tooltip,
  required = false,
  className = '',
}: FormInputProps) {
  return (
    <div className="space-y-2">
      <div className="flex items-center gap-2">
        <Label htmlFor={id} className="text-sm font-medium">
          {label}
        </Label>
        {tooltip && (
          <TooltipProvider>
            <Tooltip>
              <TooltipTrigger asChild>
                <Info className="h-4 w-4 text-zinc-500" />
              </TooltipTrigger>
              <TooltipContent className="bg-zinc-900 text-zinc-200 border-zinc-800">
                <p>{tooltip}</p>
              </TooltipContent>
            </Tooltip>
          </TooltipProvider>
        )}
      </div>
      <Input
        id={id}
        placeholder={placeholder}
        value={value}
        defaultValue={defaultValue}
        onChange={(e) => onChange?.(e.target.value)}
        required={required}
        className={`font-mono ${className}`}
      />
      {description && <p className="text-xs text-zinc-500">{description}</p>}
    </div>
  );
}
