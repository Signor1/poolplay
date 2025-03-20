'use client'
import React from 'react'
import {
    Sheet,
    SheetContent,
    SheetClose,
    SheetTrigger,
} from "@/components/ui/sheet";
import { Menu, MoveUpRight } from 'lucide-react';
import Logo from './Logo';
import { Link as Spy } from "react-scroll";
import { navLinks } from '@/utils/NavLinks';
import { NavLinkTypes } from '@/types/NavLink';

/**
 * @function MobileNav
 * @description A mobile navigation component utilizing a sliding sheet UI pattern.
 * It displays a button with a menu icon that triggers the sheet. Inside the sheet,
 * it shows the PoolPlay logo and a list of navigation links. Each link is styled
 * with a hover effect and navigates smoothly to the corresponding section when clicked.
 * @returns {JSX.Element} The JSX element representing the mobile navigation.
 */

const MobileNav = () => {
    return (
        <Sheet>
            <SheetTrigger asChild>
                <button className="text-strimzPrimary">
                    <Menu className='w-6 h-6' />
                </button>
            </SheetTrigger>
            <SheetContent className='w-full bg-background border-none outline-none'>
                <main className="w-full flex flex-col ">
                    <div className="w-full py-6 px-6 flex justify-between items-center">
                        {/* logo */}
                        <Logo href='/' logoSize='w-[70px]'>
                            <span className='text-primary font-bubblegum text-3xl'>PoolPlay</span>
                        </Logo>
                    </div>
                    <div className="w-full mt-16 flex flex-col justify-center gap-5 items-center">
                        {
                            navLinks.map((link: typeof NavLinkTypes, i: number) => (
                                <SheetClose asChild key={i}>
                                    <Spy
                                        to={link.to}
                                        smooth={true}
                                        spy={true}
                                        duration={500}
                                        className={`capitalize font-comfortaa text-primary font-[500] text-2xl cursor-pointer hover:underline flex items-center gap-2`}
                                    >
                                        {link.name}
                                        <MoveUpRight className="w-6 h-6" />
                                    </Spy>
                                </SheetClose>
                            ))
                        }
                    </div>
                </main>
            </SheetContent>
        </Sheet>
    )
}

export default MobileNav