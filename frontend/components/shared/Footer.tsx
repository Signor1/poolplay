'use client'
import { useState, useEffect } from 'react'
import Logo from './Logo'
import Link from 'next/link'
import { Linkedin, Twitter } from 'lucide-react'
import { navLinks } from '@/utils/NavLinks'
import { Link as Spy } from "react-scroll";

const Footer = () => {

    const [year, setYear] = useState('')

    useEffect(() => {
        const year = new Date().getFullYear()
        setYear(year.toString())
    }, [])

    return (
        <footer className='w-full bg-black flex flex-col lg:px-20 md:px-12 px-4 py-12 md:py-10'>
            <section className='w-full flex md:flex-row flex-col md:justify-between justify-center items-center gap-6 md:gap-0 border-b border-neutral-800 pb-4'>
                <Logo href='/' logoSize='md:w-[60px] w-[60px]'>
                    <span className='text-primary font-bubblegum md:text-3xl text-3xl'>PoolPlay</span>
                </Logo>

                <div className='flex md:flex-row flex-col items-center lg:gap-6 md:gap-4 gap-4'>
                    {
                        navLinks.map((link, index) => (
                            <Spy
                                key={index}
                                to={link.to}
                                smooth={true}
                                spy={true}
                                duration={700}
                                className={`font-[400] cursor-pointer font-comfortaa text-base text-neutral-500 transition hover:text-primary/80`}
                            >
                                {link.name}
                            </Spy>

                        ))
                    }
                </div>

                <div className='flex items-center gap-4'>
                    <Link href="" target='_blank' className='text-neutral-500 transition hover:text-primary'>
                        <Twitter className='w-6 h-6' />
                    </Link>
                    <Link href="/" target='_blank' className='text-neutral-500 transition hover:text-primary'>
                        <Linkedin className='w-6 h-6' />
                    </Link>
                </div>
            </section>
            <section className='w-full flex md:flex-row flex-col md:justify-between justify-center items-center gap-4 md:gap-0 pt-4'>
                <p className='text-sm md:text-base font-[400] font-comfortaa text-neutral-500'>Built with 💖 for Uniswap V4</p>
                <p className='font-[400] font-comfortaa md:text-base text-sm text-neutral-500'>© {year} PoolPlay. All rights reserved.</p>
            </section>
        </footer>
    )
}

export default Footer