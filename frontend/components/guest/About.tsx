import { Element } from "react-scroll"
import { BackgroundLines } from "../ui/background-lines"
import Image from "next/image"
import uniswapLogo from "@/public/Uniswap_Logo.png"
import poolplayLogo from "@/public/dice.png"

const About = () => {
    return (
        <Element name="about">
            <BackgroundLines className="flex items-center justify-center w-full flex-col px-4 gradient">
                <div className="flex items-center justify-center w-full flex-col absolute inset-0 h-full z-10">
                    <div className="flex flex-col items-center justify-center ">
                        <Image src={uniswapLogo} alt="logo" className="md:w-[400px] w-[200px]" width={2560} height={639} quality={100} priority />
                        <span className="md:text-5xl text-4xl text-neutral-200 font-comfortaa font-bold uppercase">&</span>
                        <div className="flex flex-row items-center gap-2">
                            <Image src={poolplayLogo} alt="Logo" className="md:w-[100px] w-[60px]" width={400} height={400} priority quality={100} />
                            <span className='text-primary font-bubblegum md:text-5xl text-3xl'>PoolPlay</span>
                        </div>
                    </div>
                    <h2 className="bg-clip-text max-w-3xl text-transparent text-center bg-gradient-to-b from-neutral-600 to-white text-2xl md:text-4xl font-comfortaa py-2 md:py-10 relative z-20 font-bold tracking-tight">
                        PoolPlay hooks into Uniswap V4 to make liquidity pools fun with lotteries and prediction markets.
                    </h2>
                </div>
            </BackgroundLines>
        </Element>
    )
}

export default About