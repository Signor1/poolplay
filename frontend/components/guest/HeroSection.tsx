import Image from "next/image"
import herobg from "@/public/bg.png"
import { SparklesText } from "../magicui/sparkles-text"
import { InteractiveHoverButton } from "../magicui/interactive-hover-button"

const HeroSection = () => {
    return (
        <section className="w-full lg:h-[100dvh] md:h-[80dvh] h-[90dvh] relative overflow-x-hidden bg-black">
            <main className="w-full h-full">
                <Image src={herobg} alt="bgImage" className="w-full h-full object-cover object-bottom" width={3000} height={2000} quality={100} priority />
            </main>

            <main className="w-full h-full absolute inset-x-0 top-0 flex flex-col items-center justify-center">
                <div className="max-w-2xl md:-mt-24 -mt-20 flex flex-col items-center">
                    <h1 className="font-bubblegum font-semibold text-neutral-300 text-6xl md:text-7xl text-center">Gamify Your Liquidity with{" "}
                        <SparklesText>
                            <span>PoolPlay!</span>
                        </SparklesText>
                    </h1>
                    <h3 className="text-neutral-400 max-w-xl mt-2 md:text-2xl text-xl font-comfortaa text-center">Swap to win lotteries, bet on pool metrics—all on Uniswap V4</h3>

                    <InteractiveHoverButton className="text-base mt-6 font-comfortaa">Launch App</InteractiveHoverButton>
                </div>
            </main>
        </section>
    )
}

export default HeroSection