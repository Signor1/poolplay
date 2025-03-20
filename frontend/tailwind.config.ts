import type { Config } from "tailwindcss";
import tailwindAnimate from "tailwindcss-animate";

const config: Config = {
  darkMode: ["class"],
  content: [
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        background: "hsl(0, 0%, 10.6%)", // #1a1a1a - Dark gray background
        foreground: "hsl(0, 0%, 100%)", // #FFFFFF - White text for readability
        card: {
          DEFAULT: "hsl(300, 33.3%, 17.6%)", // #2d1a2d - Dark purple for cards
          foreground: "hsl(0, 0%, 100%)", // #FFFFFF - White text on cards
        },
        popover: {
          DEFAULT: "hsl(300, 33.3%, 17.6%)", // #2d1a2d - Dark purple for popovers
          foreground: "hsl(0, 0%, 100%)", // #FFFFFF - White text on popovers
        },
        primary: {
          DEFAULT: "hsl(338.2, 92.5%, 54.1%)", // #e83e8c - Uniswap pink for buttons/highlights
          foreground: "hsl(0, 0%, 100%)", // #FFFFFF - White text on primary elements
        },
        secondary: {
          DEFAULT: "hsl(300, 25%, 22.4%)", // #3a1a3a - Dark purple for secondary elements
          foreground: "hsl(0, 0%, 100%)", // #FFFFFF - White text on secondary elements
        },
        muted: {
          DEFAULT: "hsl(0, 0%, 20%)", // #333333 - Muted gray for subtle backgrounds
          foreground: "hsl(0, 0%, 60%)", // #999999 - Light gray for muted text
        },
        accent: {
          DEFAULT: "hsl(338.2, 92.5%, 54.1%)", // #e83e8c - Uniswap pink for accents
          foreground: "hsl(0, 0%, 100%)", // #FFFFFF - White text on accents
        },
        destructive: {
          DEFAULT: "hsl(0, 84.2%, 60.2%)", // #dc2626 - Red for errors/warnings
          foreground: "hsl(0, 0%, 100%)", // #FFFFFF - White text on destructive elements
        },
        border: "hsl(300, 25%, 22.4%)", // #3a1a3a - Dark purple for borders
        input: "hsl(300, 33.3%, 17.6%)", // #2d1a2d - Dark purple for input fields
        ring: "hsl(338.2, 92.5%, 54.1%)", // #e83e8c - Uniswap pink for focus rings
        chart: {
          "1": "hsl(338.2, 92.5%, 54.1%)", // #e83e8c - Pink for charts
          "2": "hsl(160, 81%, 44%)", // #10b981 - Green for charts
          "3": "hsl(221, 83%, 53%)", // #3b82f6 - Blue for charts
          "4": "hsl(24, 94%, 50%)", // #f97316 - Orange for charts
          "5": "hsl(49, 95%, 53%)", // #facc15 - Yellow for charts
        },
      },
      borderRadius: {
        lg: "var(--radius)",
        md: "calc(var(--radius) - 2px)",
        sm: "calc(var(--radius) - 4px)",
      },
      fontFamily: {
        bubblegum: ["Bubblegum Sans", "sans-serif"],
        zeyada: ["Zeyada", "cursive"],
        comfortaa: ["Comfortaa", "sans-serif"],
      },
    },
  },
  plugins: [tailwindAnimate],
};
export default config;
