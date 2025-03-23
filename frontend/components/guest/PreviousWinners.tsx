"use client";
import React, { useRef } from 'react'
import {
    Card,
    CardContent,
    CardFooter,
    CardHeader,
    CardTitle,
} from "@/components/ui/card"
import Image from 'next/image'
import winnerFrame from "@/public/winnerFrame.png"
import boywinner from "@/public/AV3.png"
import girlwinner from "@/public/AV66.png"
import { Confetti, type ConfettiRef } from '../magicui/confetti';

const PreviousWinners = () => {

    const confettiRef = useRef<ConfettiRef>(null);

    const addressFormatter = (address: string) => {
        return `${address.slice(0, 6)}...${address.slice(-6)}`
    }


    return (
        <section className="w-full py-32 px-7 relative">

            <main className="w-full flex flex-col gap-16 items-center justify-center">
                <div className="flex flex-col justify-center items-center">
                    <h2 className="bg-clip-text text-transparent text-center bg-gradient-to-t from-border to-primary text-3xl md:text-5xl  font-bubblegum font-bold">
                        Previous Winners
                    </h2>
                    <p className="font-comfortaa md:text-xl text-base text-neutral-200 text-center">Celebrating Those Who Played and Won!</p>
                </div>
                <ul className="w-full max-w-3xl grid grid-cols-1 gap-6 md:grid-cols-2 lg:gap-10">
                    <Card className="w-full bg-black relative overflow-hidden">
                        <CardHeader className="flex flex-col">
                            <CardTitle className="font-bubblegum text-center font-light text-neutral-300">Previous Lottery Pool Winner</CardTitle>
                        </CardHeader>
                        <CardContent>
                            <div className="w-full relative">
                                <Image src={winnerFrame} alt="frame" className="w-full" width={1440} height={1440} />
                                <div className="absolute top-4 left-1/2 -translate-x-1/2 w-[160px] h-[160px] bg-black border border-neutral-500 rounded-full overflow-hidden">
                                    <Image width={160} height={160} src={boywinner} alt='avatar' quality={100} priority />
                                </div>
                            </div>

                        </CardContent>
                        <CardFooter className="flex flex-col items-center">
                            <h3 className="font-bubblegum text-center font-light text-neutral-300 md:text-xl text-lg">{addressFormatter("0xA3B1C5D9E8F72134b8A67D9123456789abcdef12")}</h3>
                            <p className="text-neutral-400 text-sm font-comfortaa text-center">Won 5 ETH on Pool #1</p>
                        </CardFooter>
                    </Card>

                    <Card className="w-full bg-black relative overflow-hidden">
                        <CardHeader className="flex flex-col">
                            <CardTitle className="font-bubblegum text-center font-light text-neutral-300">Previous Prediction Market Winner</CardTitle>
                        </CardHeader>
                        <CardContent>
                            <div className="w-full relative">
                                <Image src={winnerFrame} alt="frame" className="w-full" width={1440} height={1440} />
                                <div className="absolute top-4 left-1/2 -translate-x-1/2 w-[160px] h-[160px] bg-black border border-neutral-500 rounded-full overflow-hidden">
                                    <Image width={160} height={160} src={girlwinner} alt='avatar' quality={100} priority />
                                </div>
                            </div>

                        </CardContent>
                        <CardFooter className="flex flex-col items-center">
                            <h3 className="font-bubblegum text-center font-light text-neutral-300 md:text-xl text-lg">{addressFormatter("0xF7E2D3C9A1B64578cDEF23456789ABcdEf901234")}</h3>
                            <p className="text-neutral-400 text-sm font-comfortaa text-center">ID #45 won 50 USDC betting TVL &gt; 100k</p>
                        </CardFooter>


                    </Card>
                </ul>
            </main>

            <Confetti
                ref={confettiRef}
                className="absolute left-0 top-0 z-0 size-full"
            />
        </section>
    )
}

export default PreviousWinners