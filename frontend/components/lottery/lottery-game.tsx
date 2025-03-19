"use client"

import { useState } from "react"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Shuffle, RotateCcw, Check } from "lucide-react"
import { useToast } from "@/hooks/use-toast"
import NumberGrid from "./number-grid"
import SelectedNumbers from "./selected-numbers"

const MAX_SELECTIONS = 6
const NUMBER_RANGE = 60

export default function LotteryGame() {
  const [selectedNumbers, setSelectedNumbers] = useState<number[]>([])
  const [winningNumbers, setWinningNumbers] = useState<number[]>([])
  const [gameStatus, setGameStatus] = useState<"selecting" | "submitted">("selecting")
  const { toast } = useToast()

  const handleNumberSelect = (number: number) => {
    if (selectedNumbers.includes(number)) {
      setSelectedNumbers(selectedNumbers.filter((n) => n !== number))
    } else if (selectedNumbers.length < MAX_SELECTIONS) {
      setSelectedNumbers([...selectedNumbers, number])
    } else {
      toast({
        title: "Maximum selections reached",
        description: `You can only select ${MAX_SELECTIONS} numbers`,
        variant: "destructive",
      })
    }
  }

  const clearSelections = () => {
    setSelectedNumbers([])
  }

  const generateRandomNumbers = () => {
    const numbers = new Set<number>()
    while (numbers.size < MAX_SELECTIONS) {
      numbers.add(Math.floor(Math.random() * NUMBER_RANGE) + 1)
    }
    setSelectedNumbers(Array.from(numbers))
  }

  const submitTicket = () => {
    if (selectedNumbers.length < MAX_SELECTIONS) {
      toast({
        title: "Incomplete selection",
        description: `Please select all ${MAX_SELECTIONS} numbers before submitting`,
        variant: "destructive",
      })
      return
    }

    // Generate random winning numbers
    const winningSet = new Set<number>()
    while (winningSet.size < MAX_SELECTIONS) {
      winningSet.add(Math.floor(Math.random() * NUMBER_RANGE) + 1)
    }
    const randomWinningNumbers = Array.from(winningSet)
    setWinningNumbers(randomWinningNumbers)
    setGameStatus("submitted")

    toast({
      title: "Ticket submitted!",
      description: `Your numbers: ${selectedNumbers.sort((a, b) => a - b).join(", ")}`,
      variant: "default",
    })
  }

  const playAgain = () => {
    setSelectedNumbers([])
    setWinningNumbers([])
    setGameStatus("selecting")
  }

  return (
    <Card className="shadow-lg border-secondary bg-black">
      <CardHeader className="border-b border-secondary">
        <CardTitle className="text-xl text-center text-primary">Select Your Lucky Numbers</CardTitle>
      </CardHeader>
      <CardContent className="space-y-6 pt-6">
        <SelectedNumbers selectedNumbers={selectedNumbers} maxSelections={MAX_SELECTIONS} />

        <NumberGrid selectedNumbers={selectedNumbers} onNumberSelect={handleNumberSelect} numberRange={NUMBER_RANGE} />
        {gameStatus === "submitted" && (
          <div className="mt-8 space-y-4">
            <div className="border-t border-secondary pt-4">
              <h3 className="text-lg font-semibold text-center mb-3 text-primary">Winning Numbers</h3>
              <div className="flex justify-center gap-2 flex-wrap">
                {winningNumbers
                  .sort((a, b) => a - b)
                  .map((number) => (
                    <div
                      key={number}
                      className={`h-12 w-12 rounded-full flex items-center justify-center text-lg font-bold 
                      ${
                        selectedNumbers.includes(number)
                          ? "bg-green-600 text-white"
                          : "bg-primary text-primary-foreground"
                      }`}
                    >
                      {number}
                    </div>
                  ))}
              </div>
            </div>

            <div className="bg-secondary p-4 rounded-lg">
              <h3 className="font-semibold text-center mb-2 text-white">Results</h3>
              {(() => {
                const matches = selectedNumbers.filter((num) => winningNumbers.includes(num))
                return (
                  <div className="text-center">
                    <p className="text-lg font-bold text-white">
                      {matches.length} {matches.length === 1 ? "Match" : "Matches"}!
                    </p>
                    {matches.length > 0 ? (
                      <p className="mt-1 text-gray-200">Matching numbers: {matches.sort((a, b) => a - b).join(", ")}</p>
                    ) : (
                      <p className="mt-1 text-gray-200">Better luck next time!</p>
                    )}
                  </div>
                )
              })()}
            </div>
          </div>
        )}
      </CardContent>
      <CardFooter className="flex flex-col sm:flex-row gap-3 justify-between border-t border-secondary pt-6">
        {gameStatus === "selecting" ? (
          <>
            <div className="flex gap-2 w-full sm:w-auto">
              <Button
                variant="outline"
                onClick={clearSelections}
                className="flex-1 sm:flex-none border-secondary text-white bg-secondary/50"
              >
                <RotateCcw className="mr-2 h-4 w-4" />
                Clear
              </Button>
              <Button
                variant="outline"
                onClick={generateRandomNumbers}
                className="flex-1 sm:flex-none border-secondary text-white bg-secondary/50"
              >
                <Shuffle className="mr-2 h-4 w-4" />
                Random
              </Button>
            </div>
            <Button
              onClick={submitTicket}
              className="w-full sm:w-auto bg-primary hover:bg-primary/80 text-white"
              disabled={selectedNumbers.length < MAX_SELECTIONS}
            >
              <Check className="mr-2 h-4 w-4" />
              Submit Ticket
            </Button>
          </>
        ) : (
          <Button onClick={playAgain} className="w-full bg-primary hover:bg-primary/80 text-white">
            Play Again
          </Button>
        )}
      </CardFooter>
    </Card>
  )
}

