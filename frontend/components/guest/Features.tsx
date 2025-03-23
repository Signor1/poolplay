'use client'

import { Element } from "react-scroll"
import { GlowingEffect } from "../ui/glowing-effect";
import Image from "next/image";
import dice from "@/public/dice2.png"
import bet from "@/public/prediction.png"
import { SparklesText } from "../magicui/sparkles-text";


const Features = () => {
    return (
        <Element name="features">
            <section className="w-full py-32 relative">

                <main className="w-full flex flex-col items-center justify-center">
                    <h2 className="bg-clip-text text-transparent text-center bg-gradient-to-b from-border to-primary text-2xl md:text-5xl  font-bubblegum py-2 md:py-10 relative z-20 font-bold">
                        PoolPlay Features
                    </h2>
                    <ul className="w-full max-w-3xl grid grid-cols-1 gap-6 md:grid-cols-2 lg:gap-10">
                        <GridItem
                            icon={<Image src={dice} alt="Dice" className="w-full" width={400} height={400} priority quality={100} />}
                            title="Lottery Pools"
                            description="Swap to enter a lottery, win big as you swap!"
                        />

                        <GridItem
                            icon={<Image src={bet} alt="Prediction" className="w-full" width={400} height={400} priority quality={100} />}
                            title="Prediction Markets"
                            description="Bet on pool stats like TVL, settle with rewards."
                        />
                    </ul>
                </main>
            </section>
        </Element>
    )
}

export default Features

interface GridItemProps {
    icon: React.ReactNode;
    title: string;
    description: React.ReactNode;
}

const GridItem = ({ icon, title, description }: GridItemProps) => {
    return (
        <li className={`min-h-[14rem] list-none`}>
            <div className="relative h-full rounded-2.5xl border p-2 md:rounded-3xl md:p-3">
                <GlowingEffect
                    spread={40}
                    glow={true}
                    disabled={false}
                    proximity={64}
                    inactiveZone={0.01}
                />
                <div className="relative flex h-full flex-col justify-between gap-6 overflow-hidden rounded-xl border-0.75 p-6 shadow-[0px_0px_27px_0px_#2D2D2D] md:p-6">
                    <div className="relative flex flex-1 flex-col justify-between">
                        <SparklesText>
                            {icon}
                        </SparklesText>
                        <div className="space-y-3">
                            <h3 className="pt-0.5 md:text-3xl text-2xl font-semibold font-bubblegum text-neutral-200">
                                {title}
                            </h3>
                            <h2 className="font-comfortaa text-base  text-neutral-300">
                                {description}
                            </h2>
                        </div>
                    </div>
                </div>
            </div>
        </li>
    );
};
