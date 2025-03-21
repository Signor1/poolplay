'use client'
import About from "@/components/guest/About";
import Features from "@/components/guest/Features";
import HeroSection from "@/components/guest/HeroSection";


export default function Home() {
  return (
    <main className="w-full">
      <HeroSection />
      <About />
      <Features />
    </main>
  );
}
