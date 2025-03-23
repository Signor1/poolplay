import React from 'react'
import { Element } from 'react-scroll'
import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from "@/components/ui/accordion";

const ListOfFAQs = () => {
    return (
        <Element name='faqs'>
            <section className="w-full bg-neutral-950 py-32 px-4">
                <main className="max-w-4xl mx-auto">
                    <div className="w-full mb-10">
                        <h2 className="text-xl md:text-5xl mb-4 text-primary font-bold font-bubblegum max-w-4xl">
                            FAQS
                        </h2>
                        <p className="text-neutral-400 text-sm md:text-lg font-comfortaa max-w-sm">
                            Everything you need to know about PoolPlay and how it works.
                        </p>
                    </div>

                    <Accordion type="single" collapsible className="w-full space-y-2" defaultValue="1">
                        {items.map((item) => (
                            <AccordionItem value={item.id} key={item.id} className='border-color1/15 border rounded-md px-4 shadow shadow-color1/20'>
                                <AccordionTrigger className="text-neutral-300 font-bubblegum font-medium text-base md:text-xl">{item.title}</AccordionTrigger>
                                <AccordionContent className="pb-4 text-neutral-400 font-comfortaa text-base">
                                    {item.content}
                                </AccordionContent>
                            </AccordionItem>
                        ))}
                    </Accordion>
                </main>

            </section>
        </Element>
    )
}

export default ListOfFAQs


const items = [
    {
        id: "1",
        title: "How do I participate in the lottery?",
        content: "Swap on a PoolPlay-enabled pool; a fee enters you automatically.",
    },
    {
        id: "2",
        title: "How are prediction markets settled?",
        content: "Based on pool data like TVL at settlement time.",
    },
    {
        id: "3",
        title: "What fees are associated with using PoolPlay?",
        content: "PoolPlay charges a small fee per swap or prediction entry, which funds the lottery and prediction markets.",
    },
    {
        id: "4",
        title: "How are winners selected in the lottery?",
        content: "Winners are chosen randomly from all eligible participants based on a verifiable on-chain mechanism.",
    },
    {
        id: "5",
        title: "Can I track my PoolPlay rewards?",
        content: "Yes, you can check your rewards and eligibility status directly on the PoolPlay dashboard.",
    },
];
