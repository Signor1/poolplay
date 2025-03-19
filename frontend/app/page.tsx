import LotteryGame from "@/components/lottery/lottery-game"

export default function Home() {
  return (
    <main className="min-h-screen p-4 md:p-8 lg:p-12 bg-black">
      <div className="max-w-4xl mx-auto">
        <h1 className="text-3xl md:text-4xl font-bold text-center mb-6 text-primary">Lucky Numbers Lottery</h1>
        <p className="text-center mb-8 text-gray-300">Select 6 numbers from 1-60 to create your lottery ticket</p>
        <LotteryGame />
      </div>
    </main>
  )
}

