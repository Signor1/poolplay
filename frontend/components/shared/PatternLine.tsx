import { cn } from '@/lib/utils'
import React from 'react'

const PatternLine = ({ className, style }: { className?: string, style: "pattern1" | "pattern2" }) => {
    return (
        <div className={cn(`w-full ${style}`, className)} />
    )
}

export default PatternLine