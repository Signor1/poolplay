'use client'
import About from "@/components/guest/About";
import ListOfFAQs from "@/components/guest/FAQs";
import Features from "@/components/guest/Features";
import HeroSection from "@/components/guest/HeroSection";
import HowItWorks from "@/components/guest/HowItWorks";
import PreviousWinners from "@/components/guest/PreviousWinners";


export default function Home() {
  return (
    <main className="w-full">
      <HeroSection />
      <About />
      <Features />
      <HowItWorks />
      <PreviousWinners />
      <ListOfFAQs />
    </main>
  );
}
