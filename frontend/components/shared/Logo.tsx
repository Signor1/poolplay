import Image from 'next/image'
import Link from 'next/link'
import React from "react"
import poolplayLogo from "@/public/dice.png"


const Logo = ({ logoSize, href, children }: { logoSize: string, href: string, children: React.ReactNode }) => {
    return (
        <Link href={href} className="flex flex-row items-center gap-2">
            <Image src={poolplayLogo} alt="Logo" className={logoSize} width={400} height={400} priority quality={100} />
            {children}
        </Link>
    )
}

export default Logo