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
  			background: 'hsl(0, 0%, 10.6%)',
  			foreground: 'hsl(0, 0%, 100%)',
  			card: {
  				DEFAULT: 'hsl(300, 33.3%, 17.6%)',
  				foreground: 'hsl(0, 0%, 100%)'
  			},
  			popover: {
  				DEFAULT: 'hsl(300, 33.3%, 17.6%)',
  				foreground: 'hsl(0, 0%, 100%)'
  			},
  			primary: {
  				DEFAULT: 'hsl(338.2, 92.5%, 54.1%)',
  				foreground: 'hsl(0, 0%, 100%)'
  			},
  			secondary: {
  				DEFAULT: 'hsl(300, 25%, 22.4%)',
  				foreground: 'hsl(0, 0%, 100%)'
  			},
  			muted: {
  				DEFAULT: 'hsl(0, 0%, 20%)',
  				foreground: 'hsl(0, 0%, 60%)'
  			},
  			accent: {
  				DEFAULT: 'hsl(338.2, 92.5%, 54.1%)',
  				foreground: 'hsl(0, 0%, 100%)'
  			},
  			destructive: {
  				DEFAULT: 'hsl(0, 84.2%, 60.2%)',
  				foreground: 'hsl(0, 0%, 100%)'
  			},
  			border: 'hsl(300, 25%, 22.4%)',
  			input: 'hsl(300, 33.3%, 17.6%)',
  			ring: 'hsl(338.2, 92.5%, 54.1%)',
  			chart: {
  				'1': 'hsl(338.2, 92.5%, 54.1%)',
  				'2': 'hsl(160, 81%, 44%)',
  				'3': 'hsl(221, 83%, 53%)',
  				'4': 'hsl(24, 94%, 50%)',
  				'5': 'hsl(49, 95%, 53%)'
  			}
  		},
  		borderRadius: {
  			lg: 'var(--radius)',
  			md: 'calc(var(--radius) - 2px)',
  			sm: 'calc(var(--radius) - 4px)'
  		},
  		fontFamily: {
  			bubblegum: [
  				'Bubblegum Sans',
  				'sans-serif'
  			],
  			zeyada: [
  				'Zeyada',
  				'cursive'
  			],
  			comfortaa: [
  				'Comfortaa',
  				'sans-serif'
  			]
  		},
  		keyframes: {
  			'accordion-down': {
  				from: {
  					height: '0'
  				},
  				to: {
  					height: 'var(--radix-accordion-content-height)'
  				}
  			},
  			'accordion-up': {
  				from: {
  					height: 'var(--radix-accordion-content-height)'
  				},
  				to: {
  					height: '0'
  				}
  			}
  		},
  		animation: {
  			'accordion-down': 'accordion-down 0.2s ease-out',
  			'accordion-up': 'accordion-up 0.2s ease-out'
  		}
  	}
  },
  plugins: [tailwindAnimate],
};
export default config;
