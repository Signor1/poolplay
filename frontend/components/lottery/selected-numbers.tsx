import { cn } from "@/lib/utils"

interface SelectedNumbersProps {
  selectedNumbers: number[]
  maxSelections: number
}

export default function SelectedNumbers({ selectedNumbers, maxSelections }: SelectedNumbersProps) {
  const selectionSlots = Array.from({ length: maxSelections }, (_, i) => i)

  return (
    <div className="flex flex-col items-center space-y-3">
      <div className="flex justify-center gap-2">
        {selectionSlots.map((index) => {
          const number = selectedNumbers[index]
          return (
            <div
              key={index}
              className={cn(
                "h-12 w-12 rounded-full flex items-center justify-center text-lg font-bold border-2",
                number
                  ? "border-primary bg-primary text-primary-foreground"
                  : "border-dashed border-secondary text-gray-500",
              )}
            >
              {number || ""}
            </div>
          )
        })}
      </div>
      <p className="text-sm text-gray-400">
        {selectedNumbers.length} of {maxSelections} numbers selected
      </p>
    </div>
  )
}

