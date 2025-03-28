import type { Metadata } from "next";
import "@/styles/globals.css";
import { headers } from 'next/headers' // added
import ContextProvider from '@/context'
import NavBar from "@/components/shared/NavBar";
import { Toaster } from "sonner";
import ScrollToTopBtn from "@/components/shared/ScrollToTopBtn";
import BubbleCursor from "@/components/shared/BubbleCursor";
import Footer from "@/components/shared/Footer";

export const metadata: Metadata = {
  title: "PoolPlay",
  description: "Generated by create next app",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {

  const headersObj = headers();
  const cookies = headersObj.get('cookie')

  return (
    <html lang="en" suppressHydrationWarning>
      <body
        className="w-full min-h-screen antialiased bg-black"
      >
        <ContextProvider cookies={cookies}>
          <NavBar />
          <main className="w-full">
            {children}
          </main>
          <ScrollToTopBtn />
          <Toaster richColors position="top-right" />
          <Footer />
        </ContextProvider>
        <BubbleCursor />
      </body>
    </html>
  );
}
