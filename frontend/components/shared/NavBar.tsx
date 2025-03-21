
'use client'
import { useScroll, motion, useSpring } from 'framer-motion';
import React from 'react'
import Logo from './Logo';
import { Link as Spy } from "react-scroll";
import { navLinks } from '@/utils/NavLinks';
import { NavLinkTypes } from '@/types/NavLink';
import MobileNav from './MobileNav';
import { InteractiveHoverButton } from '../magicui/interactive-hover-button';

/**
 * @function NavBar
 * @description The top navigation bar with PoolPlay logo on the left, navigation links in the middle and launch app button on the right.
 * @returns {React.ReactElement} The JSX Element
 * @example
 * <NavBar />
 */
const NavBar = () => {
    const { scrollYProgress } = useScroll();

    const scaleX = useSpring(scrollYProgress, {
        stiffness: 100,
        damping: 30,
        restDelta: 0.001,
    });

    return (
        <>
            <motion.div
                className="fixed top-0 left-0 right-0 bg-primary origin-[0%] h-[6px] z-[42]"
                style={{ scaleX }}
            />
            <header className='w-full flex justify-between items-center md:px-12 px-4 md:mt-[24px] mt-[18px]'>

                <Logo href='/' logoSize='md:w-[60px] w-[50px]'>
                    <span className='text-primary font-bubblegum md:text-3xl text-2xl'>PoolPlay</span>
                </Logo>

                <nav className=' hidden md:flex justify-center items-center  border border-border rounded-[20px] font-comfortaa overflow-hidden shadow-md shadow-border/50'>

                    {
                        navLinks.map((link: typeof NavLinkTypes, i: number) => (
                            <Spy
                                key={i}
                                to={link.to}
                                smooth={true}
                                spy={true}
                                duration={700}
                                className={`capitalize font-comfortaa text-neutral-300 font-normal text-base cursor-pointer transition-all duration-500 hover:bg-primary px-4 py-3 first:pl-8 last:pr-8`}
                            >
                                {link.name}
                            </Spy>
                        ))
                    }
                </nav>

                <div className='flex items-center gap-[24px]'>
                    <InteractiveHoverButton className="text-sm font-comfortaa md:px-6 px-4">Launch App</InteractiveHoverButton>

                    <div className="md:hidden flex items-center">
                        <MobileNav />
                    </div>
                </div>
            </header>
        </>
    )
}

export default NavBar
