"use client"

import { cn } from "@/lib/utils"

interface NumberGridProps {
  selectedNumbers: number[]
  onNumberSelect: (number: number) => void
  numberRange: number
}

export default function NumberGrid({ selectedNumbers, onNumberSelect, numberRange }: NumberGridProps) {
  return (
    <div className="grid grid-cols-6 sm:grid-cols-10 gap-2">
      {Array.from({ length: numberRange }, (_, i) => i + 1).map((number) => {
        const isSelected = selectedNumbers.includes(number)
        return (
          <button
            key={number}
            onClick={() => onNumberSelect(number)}
            className={cn(
              "h-10 w-10 rounded-full flex items-center justify-center font-medium text-sm transition-all",
              "hover:scale-105 active:scale-95",
              isSelected
                ? "bg-primary text-primary-foreground shadow-md"
                : "bg-secondary text-secondary-foreground hover:bg-secondary/80",
            )}
          >
            {number}
          </button>
        )
      })}
    </div>
  )
}

