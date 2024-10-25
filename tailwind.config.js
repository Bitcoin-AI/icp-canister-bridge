/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./src/**/*.{html,js}"],
  theme: {
    extend: {
      colors: {
        destructive: {
          DEFAULT: "#dc2626", // Tailwind's red-600
          // You can add more shades if needed
          // 50: '#fef2f2',
          // 100: '#fee2e2',
          // ...
          // 900: '#7f1d1d',
        },
        muted: {
          DEFAULT: "#f3f4f6", // Example muted color
        },
        background: {
          DEFAULT: "#ffffff", // Example background color
        },
        foreground: {
          DEFAULT: "#ADD8E6", // Example foreground color
        },
        info: {
          DEFAULT: "#1E90FF", // Example foreground color
        },
        // Add other custom colors as needed
      },
    },
  },
  plugins: [],
}