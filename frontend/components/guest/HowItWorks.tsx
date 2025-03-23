import Image from 'next/image';
import React from 'react'
import { Element } from 'react-scroll'
import swapOnUniswap from "@/public/swapOnUniswap.webp"
import betOnPools from "@/public/betOnPools.png"
import winners from "@/public/winners.jpg"
import { Timeline } from '../ui/timeline';

const HowItWorks = () => {

    const data = [
        {
            title: "Step 1",
            content: (
                <div>
                    <p className="text-neutral-200 font-comfortaa text-base md:text-xl font-bold mb-8">
                        Swap on Uniswap V4 with PoolPlay to join the lottery
                    </p>
                    <p className="text-neutral-200 text-sm md:text-base font-comfortaa font-normal mb-8">
                        Make a trade on Uniswap V4 using PoolPlay, and your transaction automatically enters you into a lottery for a chance to win rewards. The more you swap, the better your chances!
                    </p>
                    <div className="grid">
                        <Image
                            src={swapOnUniswap}
                            alt="swapOnUniswap"
                            width={500}
                            height={500}
                            className="rounded-lg object-cover h-20 md:h-44 lg:h-60 w-full shadow-[0_0_24px_rgba(34,_42,_53,_0.06),_0_1px_1px_rgba(0,_0,_0,_0.05),_0_0_0_1px_rgba(34,_42,_53,_0.04),_0_0_4px_rgba(34,_42,_53,_0.08),_0_16px_68px_rgba(47,_48,_55,_0.05),_0_1px_0_rgba(255,_255,_255,_0.1)_inset]"
                        />
                    </div>
                </div>
            ),
        },
        {
            title: "Step 2",
            content: (
                <div>
                    <p className="text-neutral-200 text-base md:text-xl font-comfortaa font-bold mb-8">
                        Bet on pool metrics in prediction markets
                    </p>
                    <p className="text-neutral-200 text-sm md:text-base font-comfortaa font-normal mb-8">
                        Predict key metrics like liquidity, volume, or price movements of Uniswap V4 pools. Place your bets in the prediction market and compete against others for potential payouts.
                    </p>
                    <div className="grid">
                        <Image
                            src={betOnPools}
                            alt="betOnPools"
                            width={500}
                            height={500}
                            className="rounded-lg object-cover h-20 md:h-44 lg:h-60 w-full shadow-[0_0_24px_rgba(34,_42,_53,_0.06),_0_1px_1px_rgba(0,_0,_0,_0.05),_0_0_0_1px_rgba(34,_42,_53,_0.04),_0_0_4px_rgba(34,_42,_53,_0.08),_0_16px_68px_rgba(47,_48,_55,_0.05),_0_1px_0_rgba(255,_255,_255,_0.1)_inset]"
                        />
                    </div>
                </div>
            ),
        },
        {
            title: "Step 3",
            content: (
                <div>
                    <p className="text-neutral-200 text-base md:text-xl font-comfortaa font-bold mb-8">
                        Winners are randomly picked (lottery) or settled (predictions)
                    </p>
                    <p className="text-neutral-200 text-sm md:text-base font-comfortaa font-normal mb-8">
                        Lottery winners are selected through a fair, on-chain random draw, while prediction market winners are determined based on real-time pool data. If your bet is correct, you earn rewards!
                    </p>
                    <div className="grid">
                        <Image
                            src={winners}
                            alt="winners"
                            width={500}
                            height={500}
                            className="rounded-lg object-cover h-20 md:h-44 lg:h-60 w-full shadow-[0_0_24px_rgba(34,_42,_53,_0.06),_0_1px_1px_rgba(0,_0,_0,_0.05),_0_0_0_1px_rgba(34,_42,_53,_0.04),_0_0_4px_rgba(34,_42,_53,_0.08),_0_16px_68px_rgba(47,_48,_55,_0.05),_0_1px_0_rgba(255,_255,_255,_0.1)_inset]"
                        />
                    </div>
                </div>
            ),
        },
    ];

    return (
        <Element name='howitworks'>
            <Timeline data={data} />
        </Element>
    )
}

export default HowItWorks