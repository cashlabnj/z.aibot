import type { Config } from "tailwindcss";
const config: Config = {
  darkMode: "class",
  content: [ "./src/pages/**/*.{js,ts,jsx,tsx,mdx}", "./src/components/**/*.{js,ts,jsx,tsx,mdx}", "./src/app/**/*.{js,ts,jsx,tsx,mdx}", ],
  theme: { extend: { colors: { background: '#000000', surface: '#1C1C1E', border: '#333333', primary: '#0A84FF', success: '#30D158', danger: '#FF453A' } } },
  plugins: [],
};
export default config;
